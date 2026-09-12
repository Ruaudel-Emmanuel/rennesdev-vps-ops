#!/bin/bash
# vps-tg.sh — envoi d'un message Telegram (config: /etc/vps-watchdog-telegram.env)
# Usage: vps-tg.sh "message"
set -u
. /etc/vps-watchdog-telegram.env
curl -s -o /dev/null --max-time 20 -X POST \
    "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode chat_id="${TG_CHAT_ID}" \
    --data-urlencode text="$1"
