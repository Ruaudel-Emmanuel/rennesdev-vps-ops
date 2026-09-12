#!/bin/bash
# Préparation du staging pour snapshot Kopia (VPS rennesdev.fr)
# Crée des dumps cohérents : PostgreSQL (umami) + SQLite (n8n) + fichiers de config
set -euo pipefail

STAGING=/var/backups/kopia-staging
mkdir -p "$STAGING/configs"

echo "[$(date '+%F %T')] Staging démarré"

# --- Dump PostgreSQL umami (via socket local du conteneur, sans mot de passe) ---
docker exec umami_db pg_dump -U umami -d umami --format=custom \
  -f /tmp/umami-backup.dump
docker cp umami_db:/tmp/umami-backup.dump "$STAGING/umami.dump"
docker exec umami_db rm -f /tmp/umami-backup.dump
echo "[$(date '+%F %T')] Dump PostgreSQL OK ($(du -h "$STAGING/umami.dump" | cut -f1))"

# --- Sauvegarde cohérente de la base SQLite n8n (en ligne, via .backup) ---
sqlite3 /var/lib/docker/volumes/ubuntu_n8n_data/_data/database.sqlite \
  ".backup '$STAGING/n8n-database.sqlite'"
# La clé de chiffrement des credentials vit dans le fichier 'config'
cp /var/lib/docker/volumes/ubuntu_n8n_data/_data/config "$STAGING/n8n-config" 2>/dev/null || true
echo "[$(date '+%F %T')] Backup SQLite n8n OK ($(du -h "$STAGING/n8n-database.sqlite" | cut -f1))"

# --- Fichiers de configuration serveur ---
cp /home/ubuntu/docker-compose.yml "$STAGING/configs/" 2>/dev/null || true
cp /home/ubuntu/.env "$STAGING/configs/dot-env" 2>/dev/null || true
cp /home/ubuntu/umami/docker-compose.yml "$STAGING/configs/umami-docker-compose.yml" 2>/dev/null || true
cp /home/ubuntu/ollama/docker-compose.yml "$STAGING/configs/ollama-docker-compose.yml" 2>/dev/null || true
cp /etc/caddy/Caddyfile "$STAGING/configs/Caddyfile" 2>/dev/null || true
chmod 600 "$STAGING"/configs/* 2>/dev/null || true
echo "[$(date '+%F %T')] Configs copiées"

# Nettoyage des vieux WAL/shm du staging précédent
rm -f "$STAGING"/n8n-database.sqlite-wal "$STAGING"/n8n-database.sqlite-shm
echo "[$(date '+%F %T')] Staging terminé"
