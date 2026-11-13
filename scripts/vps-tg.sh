#!/bin/bash
# vps-tg.sh — envoi d'un message Telegram (config: /etc/vps-watchdog-telegram.env)
# Usage: vps-tg.sh "message"
set -u
. /etc/vps-watchdog-telegram.env
# Cap Telegram : tronque à 4000 caractères (unités UTF-16 — limite API Telegram = 4096)
tg_cap() { printf '%s' "$1" | python3 -c 'import sys; t=sys.stdin.read(); sys.stdout.write(t.encode("utf-16-le")[:8000].decode("utf-16-le","ignore"))'; }
curl -s -o /dev/null --max-time 20 -X POST \
    "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode chat_id="${TG_CHAT_ID}" \
    --data-urlencode text="$(tg_cap "$1")"
