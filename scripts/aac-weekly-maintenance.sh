#!/bin/bash
# aac-weekly-maintenance.sh — Maintenance AAC hebdomadaire (lundi 05h00)
# 1) Exporte les workflows n8n dans leurs repos respectifs
# 2) Nettoie les PRs deps obsolètes (ferme les vieilles, merge les récentes)
# 3) Met à jour le journal aac-audit-journal
# 4) Envoie un récap sur Telegram
set -eu

export HOME=/root
LOG=/var/log/aac-weekly-maintenance.log
DATE=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "$(date -Iseconds) $*" | tee -a "$LOG"; }
tg() { /usr/local/bin/vps-tg.sh "$1" 2>/dev/null || true; }

log "=== AAC — Maintenance hebdomadaire [$DATE] ==="
tg "🧹 AAC — Maintenance hebdomadaire lancée ($TIMESTAMP)"

# --- 1. Récupérer le PAT GitHub depuis n8n DB ---
log "Extraction du PAT depuis n8n DB..."
PAT=$(docker exec n8n_db psql -U n8n -d n8n -t -A -c "
SELECT n->'parameters'->'assignments'->'assignments'->0->>'value'
FROM workflow_entity w, json_array_elements(w.nodes::json) n
WHERE w.name = 'Push GitHub'
AND n->>'name' = 'Config (PAT GitHub)';
" 2>/dev/null | head -1)

if [ -z "$PAT" ]; then
    log "ERREUR: impossible d'extraire le PAT depuis n8n DB"
    tg "❌ AAC maintenance échouée : PAT introuvable dans n8n DB"
    exit 1
fi
log "PAT extrait (${#PAT} caractères)"

# --- 2. Exporter les workflows n8n ---
WORKFLOWS_TO_EXPORT="GitHub Auditor"
EXPORT_DIR="/tmp/aac-workflow-export"
mkdir -p "$EXPORT_DIR"
EXPORT_OK=0

log "Export des workflows n8n..."

docker exec n8n_db psql -U n8n -d n8n -t -A -F '|' -c "
SELECT id, name FROM workflow_entity WHERE active = true;
" 2>/dev/null | while IFS='|' read -r ID NAME; do
    NAME_TRIMMED=$(echo "$NAME" | xargs)
    log "  Workflow actif : $NAME_TRIMMED"
done

# Export spécifique : GitHub Auditor
AUDITOR_ID=$(docker exec n8n_db psql -U n8n -d n8n -t -A -c "
SELECT id FROM workflow_entity WHERE name = 'GitHub Auditor';
" 2>/dev/null | head -1)

if [ -n "$AUDITOR_ID" ]; then
    log "Export de GitHub Auditor (id=$AUDITOR_ID)..."

    python3 -c "
import subprocess, json

def run_json(sql):
    r = subprocess.run(['docker', 'exec', 'n8n_db', 'psql', '-U', 'n8n', '-d', 'n8n', '-t', '-A', '-c', sql],
        capture_output=True, text=True)
    out = r.stdout.strip()
    return json.loads(out) if out else None

r1 = subprocess.run(['docker', 'exec', 'n8n_db', 'psql', '-U', 'n8n', '-d', 'n8n', '-t', '-A', '-F', '|', '-c',
    'SELECT id, name, active, \"versionId\", \"createdAt\"::text as ca, \"updatedAt\"::text as ua '
    'FROM workflow_entity WHERE id = \''$AUDITOR_ID'\';'], capture_output=True, text=True)
fields = r1.stdout.strip().split('|')

w = {
    'id': fields[0], 'name': fields[1], 'active': fields[2] == 't',
    'versionId': fields[3], 'createdAt': fields[4], 'updatedAt': fields[5],
    'nodes': run_json('SELECT nodes::jsonb FROM workflow_entity WHERE id = \''$AUDITOR_ID'\';'),
    'connections': run_json('SELECT connections::jsonb FROM workflow_entity WHERE id = \''$AUDITOR_ID'\';'),
    'settings': run_json('SELECT settings::jsonb FROM workflow_entity WHERE id = \''$AUDITOR_ID'\';'),
    'staticData': run_json('SELECT \"staticData\"::jsonb FROM workflow_entity WHERE id = \''$AUDITOR_ID'\';'),
    'meta': run_json('SELECT meta::jsonb FROM workflow_entity WHERE id = \''$AUDITOR_ID'\';')
}
with open('$EXPORT_DIR/github-auditor.json', 'w') as f:
    json.dump(w, f, indent=2, ensure_ascii=False)
print('OK')
" 2>/dev/null

    if [ -f "$EXPORT_DIR/github-auditor.json" ]; then
        SIZE=$(wc -c < "$EXPORT_DIR/github-auditor.json")
        log "  ✅ Exporté : ${SIZE} bytes"

        # Copier dans le repo local
        mkdir -p /home/ubuntu/projects/GitHub-Auditor/workflow
        cp "$EXPORT_DIR/github-auditor.json" /home/ubuntu/projects/GitHub-Auditor/workflow/github-auditor.json
        log "  ✅ Copié dans GitHub-Auditor/workflow/"

        # Pusher via le webhook
        PUSH_RESULT=$(curl -s -X POST "https://n8n.rennesdev.fr/webhook/github-push" \
            -H 'Content-Type: application/json' \
            -H "X-Auth-Token: $PAT" \
            -d '{
                "repo": "GitHub-Auditor",
                "path": "GitHub-Auditor",
                "message": "chore(workflow): export hebdo du workflow n8n ('$DATE')",
                "branch": "main",
                "private": false
            }' 2>/dev/null)

        if echo "$PUSH_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('exitCode') == 0 else 1)" 2>/dev/null; then
            log "  ✅ Pushé vers GitHub-Auditor"
            EXPORT_OK=1
        else
            log "  ⚠️ Push GitHub-Auditor : $PUSH_RESULT"
        fi
    else
        log "  ⚠️ Export échoué"
    fi
else
    log "  ⚠️ Workflow GitHub Auditor introuvable"
fi

# --- 3. Nettoyage des PRs deps ---
log "Nettoyage des PRs deps..."
CLEANUP_REPORT=""
PR_CLOSED=0
PR_MERGED=0

# Repos à vérifier
for REPO in "Fiscale-vps" "surveillance-tarifaire"; do
    log "  Analyse de $REPO..."

    # Lister les PRs deps ouvertes (les plus anciennes d'abord)
    PRS=$(curl -s -H "Authorization: Bearer $PAT" \
        "https://api.github.com/search/issues?q=repo:Ruaudel-Emmanuel/$REPO+state:open+is:pr+deps&sort=created&order=asc&per_page=10" 2>/dev/null)

    echo "$PRS" | python3 -c "
import json, sys
from datetime import datetime

data = json.load(sys.stdin)
items = data.get('items', [])

if not items:
    print('NO_PRS')
    sys.exit(0)

now = datetime.now()
# Grouper : garder la plus récente, fermer les autres
newest = items[-1]
old_ones = items[:-1]

for pr in old_ones:
    num = pr['number']
    days = (now - datetime.strptime(pr['created_at'][:10], '%Y-%m-%d')).days
    print(f'CLOSE|{num}|age={days}j')

# Vérifier si la plus récente peut être mergée
import subprocess
num = newest['number']
r = subprocess.run(['curl', '-s', '-H', f'Authorization: Bearer $PAT',
    f'https://api.github.com/repos/Ruaudel-Emmanuel/$REPO/pulls/{num}'],
    capture_output=True, text=True)
pr_detail = json.loads(r.stdout)
mergeable = pr_detail.get('mergeable')
mergeable_state = pr_detail.get('mergeable_state')

if mergeable == True and mergeable_state == 'clean':
    print(f'MERGE|{num}|')
else:
    days = (now - datetime.strptime(newest['created_at'][:10], '%Y-%m-%d')).days
    if days > 14:
        print(f'NOTE|{num}|non-mergeable ({mergeable_state}), {days}j ouverte')
    else:
        print(f'SKIP|{num}|{mergeable_state}/{days}j')
" 2>/dev/null | while IFS='|' read -r ACTION NUM DETAIL; do
    case "$ACTION" in
        CLOSE)
            curl -s -X PATCH -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" \
                "https://api.github.com/repos/Ruaudel-Emmanuel/$REPO/pulls/$NUM" \
                -d '{"state":"closed"}' >/dev/null 2>&1
            log "  ❌ Fermée PR #$NUM ($DETAIL)"
            PR_CLOSED=$((PR_CLOSED + 1))
            ;;
        MERGE)
            curl -s -X PUT -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" \
                "https://api.github.com/repos/Ruaudel-Emmanuel/$REPO/pulls/$NUM/merge" \
                -d '{"commit_title":"chore(deps): merge hebdo auto","merge_method":"squash"}' >/dev/null 2>&1
            log "  ✅ Mergée PR #$NUM"
            PR_MERGED=$((PR_MERGED + 1))
            ;;
        SKIP)
            log "  ⏸  PR #$NUM conservée ($DETAIL)"
            ;;
        NOTE)
            log "  ℹ️  PR #$NUM : $DETAIL"
            ;;
    esac
done
done

log "  Total : $PR_CLOSED fermée(s), $PR_MERGED mergée(s)"

# --- 4. Mise à jour du journal AAC ---
log "Mise à jour du journal aac-audit-journal..."

JOURNAL_DIR="/home/ubuntu/projects/aac-audit-journal"
mkdir -p "$JOURNAL_DIR/rapports" "$JOURNAL_DIR/actions"

# Générer le rapport de la semaine
cat > "$JOURNAL_DIR/rapports/$DATE-rapport-hebdo.md" << EOF
# Rapport Hebdo AAC — $DATE

## Résumé de la maintenance automatisée

| Action | Statut |
|---|---|
| Export workflow GitHub-Auditor | $([ "$EXPORT_OK" = 1 ] && echo "✅" || echo "⚠️") |
| PRs fermées (obsolètes) | $PR_CLOSED |
| PRs mergées | $PR_MERGED |

## Projets audités

_Généré automatiquement par le timer \`aac-weekly-maintenance.timer\`._
EOF

# Pusher vers aac-audit-journal
PUSH_RESULT=$(curl -s -X POST "https://n8n.rennesdev.fr/webhook/github-push" \
    -H 'Content-Type: application/json' \
    -H "X-Auth-Token: $PAT" \
    -d '{
        "repo": "aac-audit-journal",
        "path": "aac-audit-journal",
        "message": "aac: rapport hebdo '$DATE' [auto]",
        "branch": "main",
        "private": false
    }' 2>/dev/null)

if echo "$PUSH_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('exitCode') == 0 else 1)" 2>/dev/null; then
    log "  ✅ Journal AAC mis à jour"
else
    log "  ⚠️ Push journal : $PUSH_RESULT"
fi

# --- 5. Résumé Telegram ---
SUMMARY="✅ AAC — Maintenance hebdo terminée
📦 Workflows exportés : $([ "$EXPORT_OK" = 1 ] && echo "1 (GitHub Auditor)" || echo "0 (⚠️)")
🔀 PRs : $PR_CLOSED fermée(s) · $PR_MERGED mergée(s)
📋 Journal : aac-audit-journal ($DATE)"

tg "$SUMMARY"
log "✅ Maintenance terminée"
log "=== Fin [$DATE] ==="