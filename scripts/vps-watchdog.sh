#!/bin/bash
# vps-watchdog.sh — Surveillance VPS rennesdev.fr
# Vérifie : disque, RAM, conteneurs Docker, HTTPS public, état du backup Kopia.
# En cas d'anomalie : envoi direct via bot Telegram (config: /etc/vps-watchdog-telegram.env).
# Anti-spam : une même anomalie ne déclenche une alerte que toutes les 6h.
set -u

TG_ENV_FILE=/etc/vps-watchdog-telegram.env
STATE_DIR=/var/lib/vps-watchdog
COOLDOWN_H=6
HOSTNAME=$(hostname)
NOW=$(date +%s)

mkdir -p "$STATE_DIR"
ALERTS=()

alert() {
    ALERTS+=("$1")
}

# Cap Telegram : tronque à 4000 caractères (unités UTF-16 — limite API Telegram = 4096)
tg_cap() { printf '%s' "$1" | python3 -c 'import sys; t=sys.stdin.read(); sys.stdout.write(t.encode("utf-16-le")[:8000].decode("utf-16-le","ignore"))'; }

# 1. Disque racine >= 95 %
USAGE=$(df --output=pcent / | tail -1 | tr -dc '0-9')
[ "${USAGE:-0}" -ge 95 ] && alert "Disque: ${USAGE}% utilisé (seuil 95%)"

# 2. RAM >= 90 %
MEM=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
[ "${MEM:-0}" -ge 90 ] && alert "RAM: ${MEM}% utilisée"

# 3. Conteneurs Docker attendus (mis à jour)
for c in browserless vps-api-gateway prometheus n8n_workflow n8n_db twenty_server twenty_redis grafana uptime-kuma twenty_db filebrowser; do
    state=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)
    if [ "$state" != "running" ]; then
        alert "Conteneur $c: statut=${state:-introuvable}"
    fi
done

# 4. HTTPS public (via edge Cloudflare)
# code attendu explicite par site — umami retiré le 13/11 (domaine NXDOMAIN, conteneur supprimé)
for entry in "n8n.rennesdev.fr:200"; do
    u="${entry%%:*}"; expected="${entry##*:}"
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$u")
    [ "$code" != "$expected" ] && alert "HTTPS $u -> code $code (attendu $expected)"
done

# 5. Kopia est désactivé, donc on saute cette vérification.
# (Anciennement : vérification du dépôt Kopia si le PC était joignable)

# 7. Dernier run du service de backup en échec ?
# (vps-backup.service a été supprimé, donc on saute cette vérification)
# Si un jour un service de backup est réactivé, décommenter cette section.

# Rien à signaler -> watchdog vert : afficher un message de succès
if [ ${#ALERTS[@]} -eq 0 ]; then
    rm -f "$STATE_DIR"/last-alert-* 2>/dev/null
    echo "✅ Watchdog VPS : Tout est normal le $(date -Iseconds)."
    echo "- Disque : ${USAGE}% utilisé"
    /usr/local/bin/vps-issue.sh close-prefix "Watchdog VPS :" \
        "Anomalie résolue — watchdog vert le $(date -Iseconds). (clôture automatique)" \
        >/dev/null 2>&1 || true
    echo "- RAM : ${MEM}% utilisée"
    echo "- Conteneurs Docker : Tous en cours d'exécution"
    echo "- HTTPS : Tous les sites accessibles"
    exit 0
fi

# Anti-spam : cooldown de 6h par anomalie identique
FRESH=()
for a in "${ALERTS[@]}"; do
    key=$(echo -n "$a" | md5sum | cut -d' ' -f1)
    f="$STATE_DIR/last-alert-$key"
    if [ -f "$f" ] && [ $(( NOW - $(cat "$f") )) -lt $(( COOLDOWN_H * 3600 )) ]; then
        continue
    fi
    echo "$NOW" > "$f"
    FRESH+=("$a")
done
[ ${#FRESH[@]} -eq 0 ] && exit 0

# Chargement config Telegram
if [ ! -f "$TG_ENV_FILE" ]; then
    logger -t vps-watchdog "ERREUR: config Telegram absente ($TG_ENV_FILE) — alerte perdue: ${FRESH[*]}"
    exit 1
fi
# shellcheck disable=SC1090
. "$TG_ENV_FILE"
if [ -z "${TG_BOT_TOKEN:-}" ] || [ -z "${TG_CHAT_ID:-}" ]; then
    logger -t vps-watchdog "ERREUR: TG_BOT_TOKEN/TG_CHAT_ID vides — alerte perdue: ${FRESH[*]}"
    exit 1
fi

MSG="🚨 ALERTE VPS — $HOSTNAME
⏰ $(date -Iseconds)"
for a in "${FRESH[@]}"; do
    MSG+=$'\n❌ '"$a"
done
MSG=$(tg_cap "$MSG")

# Envoi Telegram (échec silencieux côté script : log système uniquement)
http=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST \
    "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode chat_id="${TG_CHAT_ID}" \
    --data-urlencode text="$MSG") || http="000"

if [ "$http" = "200" ]; then
    logger -t vps-watchdog "alerte envoyée via Telegram: ${FRESH[*]}"
else
    logger -t vps-watchdog "ERREUR envoi Telegram (HTTP $http) — alerte perdue: ${FRESH[*]}"
fi

# Issues GitHub pour chaque alerte fraîche (dédoublonnage par titre dans vps-issue.sh)
for a in "${FRESH[@]}"; do
    /usr/local/bin/vps-issue.sh open "Watchdog VPS : $a" \
        "Alerte du $(date -Iseconds) sur $HOSTNAME.\n\nAction : diagnostiquer, corriger, puis l'issue est clôturée automatiquement au prochain passage vert du watchdog." \
        >/dev/null 2>&1 || logger -t vps-watchdog "vps-issue: échec création issue ($a)"
done
