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

# 1. Disque racine >= 85 %
USAGE=$(df --output=pcent / | tail -1 | tr -dc '0-9')
[ "${USAGE:-0}" -ge 85 ] && alert "Disque: ${USAGE}% utilisé (seuil 85%)"

# 2. RAM >= 90 %
MEM=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
[ "${MEM:-0}" -ge 90 ] && alert "RAM: ${MEM}% utilisée"

# 3. Conteneurs Docker attendus
for c in n8n_workflow n8n_db umami_app umami_db ollama netdata; do
    state=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)
    if [ "$state" != "running" ]; then
        alert "Conteneur $c: statut=${state:-introuvable}"
    fi
done

# 4. HTTPS public (via edge Cloudflare)
for u in umami.rennesdev.fr n8n.rennesdev.fr; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$u")
    [ "$code" != "200" ] && alert "HTTPS $u -> code $code"
done

# 5/6. Kopia : alertes UNIQUEMENT si le PC (serveur Kopia) est joignable.
# PC fermé = situation normale (nuit, week-end) -> aucune alerte Kopia.
PC_OPEN=0
timeout 5 bash -c 'echo > /dev/tcp/100.118.76.30/51515' 2>/dev/null && PC_OPEN=1
if [ "$PC_OPEN" = "1" ]; then
    if ! kopia repo status &>/dev/null; then
        alert "Dépôt Kopia NON CONNECTÉ alors que le PC est allumé (serveur Kopia arrêté ?)"
    else
        LAST_TS=$(kopia snapshot list --all 2>/dev/null | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | sort | tail -1)
        if [ -n "$LAST_TS" ]; then
            LAST_EPOCH=$(date -d "$LAST_TS UTC" +%s 2>/dev/null || echo 0)
            AGE_D=$(( (NOW - LAST_EPOCH) / 86400 ))
            [ "$AGE_D" -ge 9 ] && alert "Dernier snapshot Kopia il y a ${AGE_D} jours (PC allumé mais pas de backup)"
        else
            alert "Aucun snapshot Kopia trouvé"
        fi
    fi
fi

# 7. Dernier run du service de backup en échec ?
if [ "$(systemctl is-failed vps-backup.service 2>/dev/null)" = "failed" ]; then
    alert "vps-backup.service: dernier passage en échec ($(systemctl show -p ExecMainExitTimestamp --value vps-backup.service))"
fi

# Rien à signaler -> watchdog vert : clôturer les issues d'incidents ouvertes
if [ ${#ALERTS[@]} -eq 0 ]; then
    rm -f "$STATE_DIR"/last-alert-* 2>/dev/null
    /usr/local/bin/vps-issue.sh close-prefix "Watchdog VPS :" \
        "Anomalie résolue — watchdog vert le $(date -Iseconds). (clôture automatique)" >/dev/null 2>&1 || true
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
