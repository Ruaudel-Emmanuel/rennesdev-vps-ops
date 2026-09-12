#!/bin/bash
# vps-backup-on-demand.sh — Sauvegarde Kopia à la demande (clic Telegram /backup).
# 1) Vérifie le serveur Kopia sur le PC (et le démarre à distance via SSH si possible)
# 2) Lance vps-backup.service (staging + snapshots) et attend la fin
# 3) Rapporte le résultat sur Telegram
set -u
export HOME=/root
PC_IP=100.118.76.30
PC_USER=Emmanuel
SSH_KEY=/root/.ssh/id_ed25519_pc
LOG=/var/log/vps-backup-on-demand.log

tg() { /usr/local/bin/vps-tg.sh "$1"; }
log() { echo "$(date -Iseconds) $*" >> "$LOG"; }

# Anti-double-lancement
if [ -f /run/vps-backup-on-demand.lock ]; then
    tg "⏳ Sauvegarde déjà en cours — demande ignorée."
    exit 0
fi
touch /run/vps-backup-on-demand.lock
trap 'rm -f /run/vps-backup-on-demand.lock' EXIT

tg "⏳ Sauvegarde VPS lancée manuellement — je m'occupe de tout."
log "=== lancement manuel ==="

# --- 1. Serveur Kopia sur le PC ---
pc_ok() { timeout 3 bash -c "echo > /dev/tcp/$PC_IP/51515" 2>/dev/null; }

if ! pc_ok; then
    log "PC:51515 fermé — tentative de démarrage distant via SSH"
    if [ -f "$SSH_KEY" ]; then
        ssh -i "$SSH_KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
            "$PC_USER@$PC_IP" "schtasks /run /tn KopiaServer" >> "$LOG" 2>&1 \
            && log "SSH: tâche KopiaServer déclenchée" \
            || log "SSH: échec (détail dans $LOG)"
        # attente du port jusqu'à 60 s
        for i in $(seq 1 12); do
            pc_ok && break
            sleep 5
        done
    fi
fi

if ! pc_ok; then
    tg "❌ Sauvegarde ANNULÉE : serveur Kopia injoignable sur le PC ($PC_IP:51515).
👉 Vérifier : PC allumé ? tâche planifiée « KopiaServer » créée ? OpenSSH Server installé ?"
    log "échec: PC injoignable"
    exit 1
fi
log "PC:51515 ouvert"

# --- 2. Dépôt connecté ? ---
if ! kopia repository status &>/dev/null; then
    tg "❌ Sauvegarde ANNULÉE : dépôt Kopia non connecté (fingerprint du certificat PC changé ?).
👉 Refaire côté VPS : sudo kopia repository connect server ... (voir ETAT-VPS.md)"
    log "échec: dépôt non connecté"
    exit 1
fi

# --- 3. Sauvegarde (service systemd, on attend la fin) ---
if ! systemctl start --wait vps-backup.service; then
    tg "❌ Sauvegarde en ÉCHEC — vps-backup.service a échoué.
👉 Détail : sudo journalctl -u vps-backup.service -n 50"
    log "échec: vps-backup.service"
    exit 1
fi

# --- 4. Résumé ---
LAST=$(kopia snapshot list --all 2>/dev/null | tail -1)
tg "✅ Sauvegarde VPS TERMINÉE avec succès.
Dernier snapshot : $LAST"
log "succès — $LAST"
