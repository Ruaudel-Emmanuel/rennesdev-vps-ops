#!/bin/bash
# github-weekly-report.sh — rapport hebdomadaire de l'activité GitHub → repo git-ops-journal
# Timer: vendredi 19h00 Europe/Paris. Aucun secret en dur : le PAT est extrait de la base
# n8n (workflow « Push GitHub ») directement en variable shell, jamais affichée ni persistée.
# Anonymat : le fichier généré ne contient ni login, ni domaine, ni secrets.
set -u
TG=/usr/local/bin/vps-tg.sh
STATE_DIR=/var/lib/github-weekly
STATE_FILE=$STATE_DIR/repos-state.json
REPO_DIR=/home/ubuntu/projects/git-ops-journal
SEMAINES_DIR=$REPO_DIR/semaines
DB=n8n_db

mkdir -p "$STATE_DIR"
cd "$REPO_DIR" || { $TG "⚠️ Rapport GitHub : dossier $REPO_DIR introuvable" ; exit 1; }

# --- 1. PAT depuis la base n8n (variable shell uniquement) ---
TOKEN=$(docker exec $DB psql -U n8n -d n8n -t -A -c \
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
[ -n "${TOKEN:-}" ] || { $TG "⚠️ Rapport GitHub : PAT introuvable dans la base n8n" ; exit 1; }

GH() { curl -s --max-time 30 -H "Authorization: Bearer $TOKEN" \
            -H "Accept: application/vnd.github+json" -H "User-Agent: vps-weekly" "$@"; }

# --- 1b. Login du compte (les PAT fine-grained n'acceptent pas /user/events) ---
LOGIN=$(GH https://api.github.com/user | grep -m1 '"login"' | cut -d'"' -f4)
[ -n "$LOGIN" ] || { $TG "⚠️ Rapport GitHub : PAT invalide (login impossible)" ; exit 1; }

# --- 2. Période : 7 derniers jours ---
DEBUT=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
SWW=$(date +%Y)-S$(date +%V)
FICHIER=$REPO_DIR/semaines/${SWW}.md
J1=$(TZ=Europe/Paris date -d '6 days ago' +%d/%m)
J2=$(TZ=Europe/Paris date +%d/%m)

# --- 3. Collecte des événements (2 pages suffisent largement) ---
python3 - "$TOKEN" "$DEBUT" "$LOGIN" > /tmp/github-weekly-raw.json << 'PYEOF'
import json, sys, urllib.request
token, debut, login = sys.argv[1], sys.argv[2], sys.argv[3]
events = []
for page in (1, 2):
    req = urllib.request.Request(
        f"https://api.github.com/users/{login}/events?per_page=100&page={page}",
        headers={"Authorization": f"Bearer {token}", "User-Agent": "vps-weekly"})
    with urllib.request.urlopen(req, timeout=30) as r:
        events += json.load(r)
recent = [e for e in events if e.get("created_at", "") >= debut]
repos_req = urllib.request.Request(
    "https://api.github.com/user/repos?per_page=100&sort=pushed&affiliation=owner",
    headers={"Authorization": f"Bearer {token}", "User-Agent": "vps-weekly"})
with urllib.request.urlopen(repos_req, timeout=30) as r:
    repos = json.load(r)
json.dump({"events": recent, "repos": repos}, sys.stdout)
PYEOF
[ -s /tmp/github-weekly-raw.json ] || { $TG "⚠️ Rapport GitHub : collecte API échouée" ; exit 1; }

# --- 4. État des dépôts : différentiel vs semaine passée ---
python3 -c "
import json,sys
d=json.load(open('/tmp/github-weekly-raw.json'))
json.dump({r['name']:{'archived':r['archived'],'pushed_at':r['pushed_at']} for r in d['repos']}, open('$STATE_FILE.new','w'), indent=1)
" && mv "$STATE_FILE.new" "$STATE_FILE"

# --- 5. Génération du rapport markdown (anonymisé) ---
python3 - "$FICHIER" "$J1" "$J2" "$SWW" "$TOKEN" << 'PYEOF'
import json, sys, collections, urllib.request
fichier, j1, j2, sww, token = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
d = json.load(open('/tmp/github-weekly-raw.json'))
events, repos = d['events'], d['repos']

commits = collections.defaultdict(list)   # repo -> [messages]
prs = {'opened': [], 'merged': [], 'closed': []}
branches = {'created': [], 'deleted': []}
issues = {'opened': 0, 'closed': 0}
tags = []
for e in events:
    repo = e.get('repo', {}).get('name', '?').split('/')[-1]
    t, payload = e.get('type'), e.get('payload', {})
    if t == 'PushEvent':
        for c in payload.get('commits', []):
            commits[repo].append(c.get('message', '').splitlines()[0][:70])
    elif t == 'PullRequestEvent':
        pr = payload.get('pull_request', {})
        act, title = pr.get('merged'), pr.get('title')
        if not title and pr.get('url'):
            try:
                req = urllib.request.Request(pr['url'], headers={
                    "Authorization": f"Bearer {token}", "User-Agent": "vps-weekly"})
                with urllib.request.urlopen(req, timeout=20) as r:
                    title = json.load(r).get('title', '?')
            except Exception:
                title = '?'
        title = title or '?'
        if payload.get('action') == 'opened':
            prs['opened'].append(f"{repo} — {title}")
        elif act:
            prs['merged'].append(f"{repo} — {title}")
        elif payload.get('action') == 'closed':
            prs['closed'].append(f"{repo} — {title}")
    elif t == 'CreateEvent' and payload.get('ref_type') == 'branch':
        branches['created'].append(f"{repo} `{payload.get('ref','?')}`")
    elif t == 'DeleteEvent' and payload.get('ref_type') == 'branch':
        branches['deleted'].append(f"{repo} `{payload.get('ref','?')}`")
    elif t == 'IssuesEvent':
        if payload.get('action') == 'opened': issues['opened'] += 1
        elif payload.get('action') == 'closed': issues['closed'] += 1
    elif t == 'ReleaseEvent':
        tags.append(f"{repo} — {payload.get('release',{}).get('tag_name','?')}")

try:
    prev = json.load(open('/var/lib/github-weekly/repos-state.json'))
except Exception:
    prev = {}
cur = {r['name']: {'archived': r['archived']} for r in repos}
nouveaux = sorted(set(cur) - set(prev))
archives = sorted(n for n in set(cur) & set(prev) if cur[n]['archived'] and not prev[n]['archived'])
actifs = sorted(n for n, v in cur.items() if not v['archived'])

# Repos actifs silencieux (aucun push depuis >= 21 jours) -> suggestions d'issues roadmap
import datetime
silencieux = []
for r in repos:
    if r['archived']:
        continue
    try:
        jours = (datetime.datetime.now(datetime.timezone.utc)
                 - datetime.datetime.fromisoformat(r['pushed_at'].replace('Z', '+00:00'))).days
    except Exception:
        continue
    if jours >= 21:
        silencieux.append((r['name'], jours))
silencieux.sort(key=lambda x: -x[1])

L = [f"# Semaine {sww} (du {j1} au {j2})", ""]
L.append(f"Résumé : **{sum(len(v) for v in commits.values())} commit(s)**, "
         f"**{len(prs['opened'])} PR ouverte(s)**, **{len(prs['merged'])} fusionnée(s)**, "
         f"**{len(branches['created'])} branche(s)** créée(s). "
         f"{len(actifs)} dépôt(s) actif(s) sur {len(cur)}.") ; L.append("")

L.append("## Commits")
if commits:
    for r in sorted(commits):
        L.append(f"- **{r}** ({len(commits[r])}) : " + " ; ".join(dict.fromkeys(commits[r]) )[:180])
else:
    L.append("- (aucun)")
L.append("")
L.append("## Pull requests")
for k, lab in (('opened', 'Ouvertes'), ('merged', 'Fusionnées'), ('closed', 'Fermées sans fusion')):
    vals = prs[k]
    L.append(f"- {lab} : " + (" ; ".join(vals) if vals else "—"))
L.append("")
L.append("## Branches")
L.append("- Créées : " + (" ; ".join(branches['created']) if branches['created'] else "—"))
L.append("- Supprimées : " + (" ; ".join(branches['deleted']) if branches['deleted'] else "—"))
L.append("")
L.append("## Issues")
L.append(f"- Ouvertes : {issues['opened']} — Fermées : {issues['closed']}")
if tags: L.append(f"- Releases/tags : {' ; '.join(tags)}")
L.append("")
L.append("## Dépôts")
L.append(f"- Nouveaux : {', '.join(nouveaux) if nouveaux else '—'}")
L.append(f"- Archivés cette semaine : {', '.join(archives) if archives else '—'}")
L.append(f"- Total actifs : {len(actifs)}")
L.append("")
L.append("## Suggestions d'issues roadmap (repos silencieux >= 21 j)")
if silencieux:
    for name, jours in silencieux:
        L.append(f"- **{name}** ({jours} j sans push) → ouvrir une issue « 📋 Roadmap » : dernier état du projet + prochaines étapes proposées")
else:
    L.append("- (aucun — tous les dépôts actifs ont bougé récemment)")
L.append("")
L.append("## Gestion")
L.append("- (rapport auto — notes de gestion à compléter si besoin)")
L.append("")
open(fichier, 'w').write("\n".join(L))
import os
os.chown(fichier, 1000, 1000)
print(fichier)
PYEOF
GENERE=$?
rm -f /tmp/github-weekly-raw.json

[ $GENERE -eq 0 ] || { $TG "⚠️ Rapport GitHub : génération markdown échouée" ; exit 1; }

# --- 6. Commit + push (token en argument uniquement, jamais persisté) ---
git -C "$REPO_DIR" add semaines/ >/dev/null 2>&1
if git -C "$REPO_DIR" diff --cached --quiet; then
  $TG "ℹ️ Rapport GitHub hebdo : rien de nouveau à committer ($SWW)"
  exit 0
fi
git -C "$REPO_DIR" -c user.name="ops-bot" -c user.email="ops@localhost" \
  commit -m "Rapport hebdo ${SWW} (auto)" >/dev/null
if git -C "$REPO_DIR" push "https://x-access-token:${TOKEN}@github.com/${LOGIN}/git-ops-journal.git" main >/dev/null 2>&1; then
  chown -R ubuntu:ubuntu "$REPO_DIR"
  $TG "📅 Rapport GitHub hebdo publié (${SWW}) : $(grep -m1 'Résumé' "$FICHIER" | sed 's/\*\*//g')"
else
  chown -R ubuntu:ubuntu "$REPO_DIR"
  $TG "⚠️ Rapport GitHub hebdo : push échoué (rapport généré localement)"
  exit 1
fi
