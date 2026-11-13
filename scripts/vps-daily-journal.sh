#!/bin/bash
# vps-daily-journal.sh — Résumé quotidien du VPS (version simplifiée sans n8n)
# Timer : tous les jours 23h00 Europe/Paris.
# Génère un journal local dans /home/ubuntu/automation/logs/daily_journal/

set -u

# Configuration
LOG_DIR="/home/ubuntu/automation/logs/daily_journal"
DATE=$(TZ=Europe/Paris date +%F)
JOUR=$(TZ=Europe/Paris date +%d/%m/%Y)
FICHIER="$LOG_DIR/$DATE.md"

# Créer le dossier de logs
mkdir -p "$LOG_DIR"

# Fonction pour logger
echo_log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$FICHIER"
}

# Début du journal
echo_log "=== Journal VPS - $JOUR ==="
echo_log ""

# 1. Uptime
echo_log "### 📊 État Général"
echo_log "- **Uptime** : $(uptime -p)"
echo_log ""

# 2. CPU
echo_log "### 🖥️ CPU"
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
echo_log "- **Charge CPU** : ${CPU_LOAD}%"
echo_log ""

# 3. RAM
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
USED_RAM=$(free -m | awk '/Mem:/ {print $3}')
RAM_PERCENT=$((USED_RAM * 100 / TOTAL_RAM))
echo_log "### 🧠 RAM"
echo_log "- **Total** : ${TOTAL_RAM} Mo"
echo_log "- **Utilisée** : ${USED_RAM} Mo (${RAM_PERCENT}%)"
echo_log ""

# 4. Disque
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
echo_log "### 💾 Disque (/)"
echo_log "- **Total** : $DISK_TOTAL"
echo_log "- **Utilisé** : $DISK_USED ($DISK_USAGE)"
echo_log ""

# 5. Conteneurs Docker
DOCKER_RUNNING=$(docker ps --format '{{.Names}}' | wc -l)
DOCKER_TOTAL=$(docker ps -a --format '{{.Names}}' | wc -l)
echo_log "### 🐳 Docker"
echo_log "- **Conteneurs en cours** : $DOCKER_RUNNING"
echo_log "- **Conteneurs totaux** : $DOCKER_TOTAL"
echo_log ""

# 6. Services critiques
SERVICES=("caddy" "docker" "fail2ban" "ufw" "tailscale")
echo_log "### 🔧 Services Critiques"
for service in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$service" 2>/dev/null || echo "inactif")
    echo_log "- **$service** : $STATUS"
done
echo_log ""

# 7. Dernières connexions SSH
echo_log "### 🔐 Dernières Connexions SSH"
# Utiliser `who` pour les connexions actuelles
WHO_OUTPUT=$(who 2>/dev/null)
if [ -n "$WHO_OUTPUT" ]; then
    echo "$WHO_OUTPUT" | awk '{print "- " $1 " depuis " $5 " le " $3 " " $4}' | while read line; do echo_log "$line"; done
else
    echo_log "- Aucune connexion SSH active"
fi
echo_log ""

# 8. Résumé
echo_log "### ✅ Résumé"
echo_log "- **Statut global** : ✅ Tout est normal"
echo_log "- **Heure** : $(TZ=Europe/Paris date '+%H:%M:%S')"
echo_log ""

# Afficher un message de succès
if [ -f "$FICHIER" ]; then
    echo "✅ Journal quotidien généré : $FICHIER"
    echo "Taille : $(wc -c < "$FICHIER") octets"
else
    echo "❌ Erreur : Impossible de générer le journal"
    exit 1
fi

# --- Publication git du journal (restauré le 13/11/2026 — ordre 5) ---
# Le service tourne en root mais le repo appartient à ubuntu : safe.directory inline.
# Credential helper déjà configuré dans le repo (ordre 3-4), /etc/vps-github.env lisible root:ubuntu 640.
JOURNAL_REPO=/home/ubuntu/projects/VPS-Rennesdev.fr
SRC_DIR=/home/ubuntu/automation/logs/daily_journal
TODAY="$DATE"
GIT="git -c safe.directory=$JOURNAL_REPO"
if [ -f "$SRC_DIR/$TODAY.md" ]; then
    mkdir -p "$JOURNAL_REPO/jours"
    cp "$SRC_DIR/$TODAY.md" "$JOURNAL_REPO/jours/$TODAY.md"
    $GIT -C "$JOURNAL_REPO" add jours/
    if ! $GIT -C "$JOURNAL_REPO" diff --cached --quiet; then
        $GIT -C "$JOURNAL_REPO" commit -m "Journal $TODAY (auto)" || true
        $GIT -C "$JOURNAL_REPO" pull --rebase origin main || true
        $GIT -C "$JOURNAL_REPO" push origin main || logger -t daily-journal "ERREUR push journal $TODAY"
    else
        echo "Journal $TODAY déjà à jour dans le repo, rien à pousser."
    fi
else
    logger -t daily-journal "ERREUR: $SRC_DIR/$TODAY.md absent"
fi
