#!/bin/sh
# github-push.sh — appelé par le workflow n8n « Push GitHub » (nœud Execute Command)
# Le token GitHub est fourni par le workflow (nœud Config), JAMAIS stocké sur disque.
# Arguments en base64 (immunisé contre injection shell) :
#   $1 REPO   $2 PATH(relatif /projects)   $3 MESSAGE   $4 BRANCH   $5 TOKEN   $6 PRIVATE
set -eu

d() { printf '%s' "$1" | base64 -d; }
REPO=$(d "$1"); DIRNAME=$(d "$2"); MSG=$(d "$3"); BRANCH=$(d "$4"); TOKEN=$(d "$5"); PRIVATE=$(d "$6")

[ -n "$REPO" ] || { echo "ERREUR: champ 'repo' requis"; exit 11; }
[ -n "$TOKEN" ] || { echo "ERREUR: token absent"; exit 10; }
[ -n "$BRANCH" ] || BRANCH=main
[ -n "$PRIVATE" ] || PRIVATE=false
[ -n "$DIRNAME" ] || DIRNAME="$REPO"
DIR="/projects/$DIRNAME"

API="https://api.github.com"
HDR_AUTH="Authorization: Bearer $TOKEN"
HDR_UA="User-Agent: vps-n8n"

# --- 1. Identité du token ---
LOGIN=$(wget -qO- --header="$HDR_AUTH" --header="$HDR_UA" "$API/user" \
        | sed -n 's/.*"login": *"\([^"]*\)".*/\1/p' | head -1 || true)
[ -n "$LOGIN" ] || { echo "ERREUR: token GitHub invalide ou expiré"; exit 12; }
echo "Token OK — compte GitHub : $LOGIN"

# --- 2. Repo existant ? Sinon création ---
CODE=$(wget -S -O /dev/null --header="$HDR_AUTH" --header="$HDR_UA" "$API/repos/$LOGIN/$REPO" 2>&1 \
       | awk '/HTTP\//{c=$2} END{print c}')
if [ "$CODE" != "200" ]; then
  echo "Repo $LOGIN/$REPO absent → création (private=$PRIVATE)"
  wget -qO- --header="$HDR_AUTH" --header="$HDR_UA" \
       --header="Content-Type: application/json" \
       --post-data="{\"name\":\"$REPO\",\"private\":$PRIVATE,\"auto_init\":false}" \
       "$API/user/repos" >/dev/null \
    || { echo "ERREUR: création du repo impossible"; exit 13; }
fi

# --- 3. Clone si besoin ---
if [ ! -d "$DIR/.git" ]; then
  rm -rf "$DIR"
  git clone --quiet "https://github.com/$LOGIN/$REPO.git" "$DIR"
  echo "Repo cloné dans $DIR"
fi

cd "$DIR"
git config user.name "Emmanuel (VPS)"
git config user.email "$LOGIN@users.noreply.github.com"

# --- 4. Commit ---
git add -A
if git diff --cached --quiet; then
  echo "Aucun changement à committer — push de synchronisation."
else
  [ -n "$MSG" ] || MSG="Mise à jour depuis le VPS ($(date '+%F %T'))"
  git commit --quiet -m "$MSG"
  echo "Commit créé : $MSG"
fi

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$LOGIN/$REPO.git"

# --- 5. Push (token transient, jamais persisté dans .git/config) ---
PUSH_URL="https://x-access-token:${TOKEN}@github.com/${LOGIN}/${REPO}.git"
if OUT=$(GIT_TERMINAL_PROMPT=0 git push --quiet "$PUSH_URL" "HEAD:refs/heads/$BRANCH" 2>&1); then
  echo "✅ Poussé vers $LOGIN/$REPO (branche $BRANCH)"
else
  echo "ERREUR push :"
  printf '%s\n' "$OUT" | sed 's/x-access-token:[^@ ]*@/x-access-token:***@/g'
  exit 14
fi
