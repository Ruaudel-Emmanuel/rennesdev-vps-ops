#!/bin/bash
# vps-metrics-report.sh — rapport quotidien des métriques VPS → Telegram
# Planifié tous les jours à 08:00 Europe/Paris (vps-metrics-report.timer)
set -u
TG=/usr/local/bin/vps-tg.sh

# --- Heure de Paris (affichage) ---
NOW=$(TZ=Europe/Paris date '+%d/%m %Hh%M')

# --- Système ---
UPTIME=$(uptime -p | sed 's/^up //')
LOAD=$(cut -d' ' -f1-3 /proc/loadavg | cut -d, -f1)
read -r RAM_USED RAM_TOT RAM_PCT <<<"$(free -m | awk 'NR==2{printf "%d %.0f %d", $3, $2/1024, $3/$2*100}')"
DISK=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')

# --- Conteneurs ---
CONT_UP=$(docker ps --format '{{.Names}}' | sort | tr '\n' ', ' | sed 's/,$//')
NB_UP=$(docker ps -q | wc -l)

# --- HTTPS (edge Cloudflare) ---
U=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 https://umami.rennesdev.fr)
N=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 https://n8n.rennesdev.fr)
HTTPS_LINE="umami:${U} n8n:${N}"

# --- Fail2ban ---
F2B=$(sudo fail2ban-client status sshd 2>/dev/null | awk -F: '/Currently banned/{gsub(/[ 	]/,"",$2); print $2}')

# --- Kopia : âge du dernier snapshot + port PC ---
LAST=$(sudo kopia snapshot list 2>/dev/null | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | sort | tail -1)
if [ -n "$LAST" ]; then
    AGE=$(( ($(date +%s) - $(date -d "$LAST" +%s)) / 3600 ))
    KOPIA_LINE="dernier snapshot il y a ${AGE}h (${LAST})"
else
    KOPIA_LINE="aucun snapshot — dépôt non connecté ?"
fi
if timeout 5 bash -c 'echo > /dev/tcp/100.118.76.30/51515' 2>/dev/null; then
    PC="PC ouvert"
else
    PC="PC fermé"
fi

# --- Netdata ---
ND=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:19999)

# --- Ollama ---
OLL=$(docker exec ollama ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ', ')
OLLAMA_LINE="${OLL:-aucun modèle chargé}"

# --- Construction du message (compact) ---
MSG="📊 VPS rennesdev.fr — ${NOW} (Paris)

⏱️ Uptime ${UPTIME} | load ${LOAD}
💾 RAM ${RAM_USED} Mo / ${RAM_TOT} Go (${RAM_PCT}%)
💿 Disque ${DISK}
📦 ${NB_UP} conteneurs : ${CONT_UP}
🌐 HTTPS ${HTTPS_LINE}
🛡️ sshd bans actifs : ${F2B:-?}
💾 Kopia ${KOPIA_LINE} | ${PC}
🤖 Ollama : ${OLLAMA_LINE}
📈 Netdata : ${ND} (local)"

# --- Envoi (le watchdog gère déjà les anomalies ; ici = info) ---
"$TG" "$MSG"
