#!/bin/bash
# vps-issue.sh — ouvre/clôt des issues GitHub depuis les scripts d'alerte du VPS
# Usage :
#   vps-issue.sh open "<titre>" "<corps>" [repo] [labels]
#   vps-issue.sh close "<titre-exact>" [commentaire] [repo]
#   vps-issue.sh close-prefix "<préfixe-titre>" [commentaire] [repo]
# Défauts : repo = rennesdev-vps-ops, labels = "incident"
# Secret : PAT extrait de la base n8n en variable shell (jamais affiché ni persisté).
# jq obligatoire pour construire les payloads sans risque d'échappement.
set -u
ACTION=${1:-}
TITRE=${2:-}
CORPS=${3:-}
REPO=${4:-rennesdev-vps-ops}
LABELS=${5:-incident}
[ -n "$ACTION" ] && [ -n "$TITRE" ] || { echo "usage: vps-issue.sh open|close|close-prefix <titre|préfixe> [corps|commentaire] [repo] [labels]" >&2; exit 2; }

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
[ -n "${TOKEN:-}" ] || { echo "vps-issue: PAT introuvable dans la base n8n" >&2; exit 3; }
LOGIN=$(curl -s --max-time 20 -H "Authorization: Bearer $TOKEN" -H "User-Agent: vps-issue" \
        https://api.github.com/user | grep -m1 '"login"' | cut -d'"' -f4)
[ -n "$LOGIN" ] || { echo "vps-issue: PAT invalide" >&2; exit 3; }
API="https://api.github.com/repos/$LOGIN/$REPO"
GH() { curl -s --max-time 30 -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" -H "User-Agent: vps-issue" "$@"; }

# numéros + titres des issues ouvertes, format "num\ttitre" (+ 1 retry si échec transitoire)
open_issues() {
    GH "$API/issues?state=open&per_page=100" | jq -r '.[] | select(.title != null) | "\(.number)\t\(.title)"' 2>/dev/null
}
OPEN_ISSUES=$(open_issues)
[ -n "$OPEN_ISSUES" ] || OPEN_ISSUES=$(open_issues)

case "$ACTION" in
  open)
    # s'assurer que le label existe (422 = existe déjà, ignoré)
    GH -X POST "$API/labels" -d "{\"name\":\"$LABELS\",\"color\":\"B60205\"}" >/dev/null 2>&1
    EXISTE=$(echo "$OPEN_ISSUES" | awk -F'\t' -v t="$TITRE" '$2 == t {print $1; exit}')
    if [ -n "$EXISTE" ]; then
        echo "vps-issue: issue #$EXISTE déjà ouverte — $TITRE"
        exit 0
    fi
    PAYLOAD=$(jq -n --arg t "$TITRE" --arg b "$CORPS" --arg l "$LABELS" \
        '{title:$t, body:$b, labels:[$l]}')
    NUM=$(GH -X POST "$API/issues" -d "$PAYLOAD" | jq -r '.number // empty')
    if [ -n "$NUM" ]; then
        echo "vps-issue: issue #$NUM ouverte — $TITRE"
        exit 0
    fi
    echo "vps-issue: échec ouverture issue — $TITRE" >&2
    exit 4
    ;;
  close)
    NUM=$(echo "$OPEN_ISSUES" | awk -F'\t' -v t="$TITRE" '$2 == t {print $1; exit}')
    [ -n "$NUM" ] || { echo "vps-issue: aucune issue ouverte « $TITRE »"; exit 0; }
    [ -n "$CORPS" ] && GH -X POST "$API/issues/$NUM/comments" \
        -d "$(jq -n --arg b "$CORPS" '{body:$b}')" >/dev/null
    GH -X PATCH "$API/issues/$NUM" -d '{"state":"closed"}' >/dev/null
    echo "vps-issue: issue #$NUM clôturée — $TITRE"
    ;;
  close-prefix)
    NUMS=$(echo "$OPEN_ISSUES" | awk -F'\t' -v t="$TITRE" 'index($2, t) == 1 {print $1}')
    [ -n "$NUMS" ] || { echo "vps-issue: aucune issue ouverte préfixée « $TITRE »"; exit 0; }
    for n in $NUMS; do
        [ -n "$CORPS" ] && GH -X POST "$API/issues/$n/comments" \
            -d "$(jq -n --arg b "$CORPS" '{body:$b}')" >/dev/null
        GH -X PATCH "$API/issues/$n" -d '{"state":"closed"}' >/dev/null
        echo "vps-issue: issue #$n clôturée"
    done
    ;;
  *) echo "action inconnue: $ACTION" >&2; exit 2 ;;
esac
