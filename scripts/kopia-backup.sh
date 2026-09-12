#!/bin/bash
# Sauvegarde VPS -> dépôt Kopia sur le PC fixe (Windows 11)
# Appelé par systemd (vps-backup.service) ou manuellement.
set -euo pipefail

echo "[$(date '+%F %T')] === Sauvegarde Kopia démarrée ==="

# Staging (dumps cohérents)
/usr/local/bin/kopia-staging.sh

# Vérifier que le dépôt est connecté
if ! kopia repo status &>/dev/null; then
    echo "ERREUR : aucun dépôt Kopia connecté."
    echo "Connecter le dépôt du PC fixe avec :"
    echo "  kopia repo connect server --url https://<PC>:51515 \\"
    echo "    --server-cert-fingerprint <fingerprint> --user vps"
    exit 1
fi

# Snapshots :
# 1. Staging (dumps + configs)
kopia snapshot create /var/backups/kopia-staging
# 2. Volumes Docker bruts (ceinture + bretelles) — modèles ollama exclus (re-téléchargeables)
kopia snapshot create /var/lib/docker/volumes \
  --ignore-cache --skip-ipfs-announcements 2>/dev/null || kopia snapshot create /var/lib/docker/volumes
# 3. Fichiers du home (compose, notes)
kopia snapshot create /home/ubuntu
# 4. Config Caddy
kopia snapshot create /etc/caddy

echo "[$(date '+%F %T')] === Snapshots terminés ==="
kopia snapshot list --all 2>/dev/null | tail -5 || true
