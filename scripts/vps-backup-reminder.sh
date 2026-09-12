#!/bin/bash
# vps-backup-reminder.sh — Rappel hebdo dimanche 12:00 : état des sauvegardes → Telegram
set -u
export HOME=/root
PC_IP=100.118.76.30
pc="fermé ❌ (PC éteint ou serveur Kopia arrêté)"
timeout 3 bash -c "echo > /dev/tcp/$PC_IP/51515" 2>/dev/null && pc="ouvert ✅"
if kopia repository status &>/dev/null; then
    repo="✅ connecté"
    LAST=$(kopia snapshot list --all 2>/dev/null | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | sort | tail -1)
    if [ -n "$LAST" ]; then
        AGE_D=$(( ($(date +%s) - $(date -d "$LAST UTC" +%s)) / 86400 ))
        snap="il y a ${AGE_D} j (dernier : $LAST UTC)"
    else
        snap="aucun snapshot ⚠️"
    fi
else
    repo="❌ NON CONNECTÉ"; snap="—"
fi
NXT=$(systemctl list-timers vps-backup.timer --no-pager | awk '/vps-backup.service/{print $2, $3, $4}')
/usr/local/bin/vps-tg.sh "🔔 Rappel sauvegarde VPS — dimanche 12:00

Backup planifié ce soir 19:30 : le PC doit rester allumé.
🖥️ PC (port 51515) : $pc
💾 Dépôt Kopia : $repo
📸 Dernier snapshot : $snap
⏰ Prochain passage timer : $NXT"
