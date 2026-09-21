#!/bin/bash
# vps-daily-journal.sh — résumé quotidien du VPS → repo privé « VPS-Rennesdev.fr »
# Timer : tous les jours 23h00 Europe/Paris. Aucun secret en dur : le PAT est extrait
# de la base n8n (workflow « Push GitHub ») en variable shell, jamais affichée ni persistée.
# Anonymat : pas de domaine, pas d'IP publique, pas de secrets dans le fichier généré.
set -u
TG=/usr/local/bin/vps-tg.sh
STATE_DIR=/var/lib/vps-journal
DOCKER_STATE=$STATE_DIR/docker-state.txt
REPO_DIR=/home/ubuntu/projects/VPS-Rennesdev.fr   # clone canonique (convention projets, 20/09) — ancien clone vps-journal retiré
JOURS_DIR=$REPO_DIR/jours
DATE=$(TZ=Europe/Paris date +%F)
JOUR=$(TZ=Europe/Paris date +%d/%m/%Y)
FICHIER=$JOURS_DIR/$DATE.md

mkdir -p "$STATE_DIR" "$JOURS_DIR"
cd "$REPO_DIR" || { $TG "⚠️ Journal VPS : dossier $REPO_DIR introuvable" ; exit 1; }

# --- 0. Déjà généré aujourd'hui ? ---
if [ -f "$FICHIER" ]; then
    exit 0
fi

# --- 1. PAT depuis la base n8n (variable shell uniquement) ---
TOKEN=$(docker exec n8n_db psql -U n8n -d n8n -t -A -c \
  "SELECT nodes FROM workflow_entity WHERE name = 'Push GitHub'" | python3 -c "
import json,sys
try:
    nodes=json.load(sys.stdin)
except Exception:
    sys.exit(1)
tok=''
for n in nodes:
    if n.get('name')=='Config (PAT GitHub)':
        for it in n['parameters'].get('assignments',{}).get('assignments',[]):
            v=it.get('value','')
            if isinstance(v,str) and len(v)>20: tok=v
print(tok)")
[ -n "${TOKEN:-}" ] || { $TG "⚠️ Journal VPS : PAT introuvable dans la base n8n" ; exit 1; }
LOGIN=$(curl -s --max-time 20 -H "Authorization: Bearer $TOKEN" -H "User-Agent: vps-journal" \
        https://api.github.com/user | grep -m1 '"login"' | cut -d'"' -f4)
[ -n "$LOGIN" ] || { $TG "⚠️ Journal VPS : PAT invalide" ; exit 1; }

# --- 2. Collecte ---
HIER=$(TZ=Europe/Paris date -d yesterday +%F)

# 2a. APT : paquets installés / mis à jour aujourd'hui (Paris = il peut y avoir décalage UTC,
# on prend les entrées d'hier soir + aujourd'hui par prudence sur la date de log)
APT_INST=$(awk -v d="$DATE" '
    $0 ~ "Start-Date: "d {dans=1; next}
    $0 ~ "Start-Date:" {dans=0}
    dans && /^Install:/ {print; dans=0}
' /var/log/apt/history.log 2>/dev/null | sed 's/^Install: *//' | tr ',' '\n' | awk '{print $1}' | sed 's/:.*//' | grep -vE '^$|\)' | sort -u)
APT_UPG=$(awk -v d="$DATE" '
    $0 ~ "Start-Date: "d {dans=1; next}
    $0 ~ "Start-Date:" {dans=0}
    dans && /^Upgrade:/ {print; dans=0}
' /var/log/apt/history.log 2>/dev/null | sed 's/^Upgrade: *//' | tr ',' '\n' | awk '{print $1}' | sed 's/:.*//' | grep -vE '^$|\)' | sort -u)

# 2b. Docker : état du soir + diff avec la veille
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | sort > "$STATE_DIR/docker-now.txt"
NB_DOCKER=$(docker ps -q | wc -l)
if [ -f "$DOCKER_STATE" ]; then
    DOCKER_DIFF=$(diff "$DOCKER_STATE" "$STATE_DIR/docker-now.txt" | grep '^[<>]' | sed 's/\t/ | /g' || true)
else
    DOCKER_DIFF="(premier jour — pas de référence de la veille)"
fi
cp "$STATE_DIR/docker-now.txt" "$DOCKER_STATE"

# 2c. Fichiers modifiés aujourd'hui dans /usr/local/bin
BIN_MOD=$(find /usr/local/bin -maxdepth 1 -type f -newermt "$DATE 00:00" -printf '%f\n' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')

# 2d. Timers/services systemd créés ou modifiés aujourd'hui
SYSD_MOD=$(find /etc/systemd/system -maxdepth 1 \( -name '*.timer' -o -name '*.service' \) -newermt "$DATE 00:00" -printf '%f\n' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')

# 2e. SSH : connexions du jour + bans fail2ban
SSH_CONN=$(last -s today 2>/dev/null | grep -vE '^(wtmp|btmp|$)' | awk '{print $1, "depuis", $3}' | sort -u | head -8 | tr '\n' ';' | sed 's/;$/\n/')
SSH_BANS=$(sudo fail2ban-client status sshd 2>/dev/null | awk -F: '/Currently banned/{gsub(/[ \t]/,"",$2); print $2}')
RECIDIVE_BANS=$(sudo fail2ban-client status recidive 2>/dev/null | awk -F: '/Currently banned/{gsub(/[ \t]/,"",$2); print $2}')

# 2f. Commits git locaux du jour (projets du serveur)
GIT_COMMITS=""
for d in /home/ubuntu/projects/*/; do
    [ -d "$d/.git" ] || continue
    LOG=$(git -C "$d" log --since="$DATE 00:00" --until="$DATE 23:59" --oneline 2>/dev/null | head -5)
    [ -n "$LOG" ] && GIT_COMMITS="$GIT_COMMITS
- $(basename "$d") : $(echo "$LOG" | tr '\n' ' ; ')"
done
[ -z "$GIT_COMMITS" ] && GIT_COMMITS="(aucun)"

# 2g. Santé du soir
RAM=$(free -m | awk 'NR==2{printf "%d%%", $3/$2*100}')
DISK=$(df -h / | awk 'NR==2{print $5}')
UPTIME=$(uptime -p | sed 's/^up //')

# --- 3. Génération du markdown ---
{
echo "# $JOUR — Journal du VPS"
echo ""
echo "**Santé du soir** : RAM $RAM · disque $DISK · uptime $UPTIME · conteneurs actifs : $NB_DOCKER"
echo ""
echo "## Paquets APT (installés aujourd'hui)"
if [ -n "$APT_INST" ]; then echo "$APT_INST" | sed 's/^/- /'; else echo "- (aucun)"; fi
echo ""
echo "## Paquets APT (mis à jour aujourd'hui)"
if [ -n "$APT_UPG" ]; then echo "$APT_UPG" | sed 's/^/- /'; else echo "- (aucun)"; fi
echo ""
echo "## Conteneurs Docker (état du soir)"
docker ps --format '- {{.Names}} ({{.Image}}) — {{.Status}}'
echo ""
echo "### Changements vs veille"
if [ -n "$DOCKER_DIFF" ]; then echo "$DOCKER_DIFF" | sed 's/^/- /'; else echo "- aucun"; fi
echo ""
echo "## Scripts /usr/local/bin modifiés"
[ -n "$BIN_MOD" ] && echo "- $BIN_MOD" || echo "- (aucun)"
echo ""
echo "## Systemd (timers/services) créés ou modifiés"
[ -n "$SYSD_MOD" ] && echo "- $SYSD_MOD" || echo "- (aucun)"
echo ""
echo "## SSH"
echo "- Connexions du jour : ${SSH_CONN:-aucune}"
echo "- Bans fail2ban — sshd : ${SSH_BANS:-0} · recidive : ${RECIDIVE_BANS:-0}"
echo ""
echo "## Commits git locaux"
echo "$GIT_COMMITS"
echo ""
echo "## Notes"
echo "- (notes libres à compléter)"
} > "$FICHIER"
chown ubuntu:ubuntu "$FICHIER"

# --- 4. Commit + push (token en argument uniquement, jamais persisté) ---
git add jours/ >/dev/null 2>&1
if git diff --cached --quiet; then
    exit 0
fi
git -c user.name="ops-bot" -c user.email="ops@localhost" \
    commit -m "Journal $DATE (auto)" >/dev/null
if git push "https://x-access-token:${TOKEN}@github.com/${LOGIN}/VPS-Rennesdev.fr.git" main >/dev/null 2>&1; then
    chown -R ubuntu:ubuntu "$REPO_DIR"
    /usr/local/bin/vps-issue.sh close "Journal VPS : push échoué" \
        "Push du journal du $JOUR réussi — incident résolu (clôture automatique)." >/dev/null 2>&1 || true
    $TG "📔 Journal VPS $JOUR publié : $NB_DOCKER conteneurs, RAM $RAM, disque $DISK. APT: $( [ -n "$APT_INST" ] && echo "$(echo "$APT_INST" | wc -l) install(s)" || echo "rien d'installé" ), $( [ -n "$APT_UPG" ] && echo "$(echo "$APT_UPG" | wc -l) maj" || echo "pas de maj" )."
else
    chown -R ubuntu:ubuntu "$REPO_DIR"
    /usr/local/bin/vps-issue.sh open "Journal VPS : push échoué" \
        "Le push du journal du $JOUR a échoué. Résumé généré localement dans jours/$DATE.md (rattrapage à faire à la main).\n\nDiagnostic : journalctl -u vps-daily-journal — causes typiques : PAT expiré, réseau, droits du clone (dubious ownership)." \
        >/dev/null 2>&1 || true
    $TG "⚠️ Journal VPS : push échoué (résumé généré localement dans jours/$DATE.md)"
    exit 1
fi
rm -f "$STATE_DIR/docker-now.txt"
