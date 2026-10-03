#!/bin/bash
# vps-etat-rotate.sh — Archive ETAT-VPS.md et crée une version légère
# Déclencheur : vps-etat-rotate.timer (dimanche 18:00)
#
# Principe :
# 1. Ajoute le contenu actuel de ETAT-VPS.md dans ETAT-VPS-ARCHIVE.md
# 2. Remplace ETAT-VPS.md par la version condensée (template)
# 3. Log l'opération

set -euo pipefail

FICHIER="/home/ubuntu/ETAT-VPS.md"
ARCHIVE="/home/ubuntu/ETAT-VPS-ARCHIVE.md"
DATE_TAG=$(date '+%Y-%m-%d %H:%M')
TAG="=== Rotation ${DATE_TAG} ==="

# Vérifier que le fichier source existe et n'est pas vide
if [ ! -f "$FICHIER" ] || [ ! -s "$FICHIER" ]; then
  logger -t vps-etat-rotate "ERREUR: ${FICHIER} inexistant ou vide — abandon"
  exit 1
fi

# 1. Ajouter le contenu actuel à l'archive (avec séparateur)
{
  echo ""
  echo "$TAG"
  echo ""
  cat "$FICHIER"
  echo ""
  echo "$TAG — fin"
} >> "$ARCHIVE"
logger -t vps-etat-rotate "Ajout de $(wc -c < "$FICHIER") octets dans $(basename "$ARCHIVE")"

# 2. Créer le nouveau fichier léger
cat > "$FICHIER" << 'NEWETAT'
# 📋 État du VPS rennesdev.fr — État courant
> Rotation automatique — les sessions archivées sont dans `ETAT-VPS-ARCHIVE.md`.

## 📌 Résumé condensé de l'historique

**Infrastructure**
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7,6 Go RAM, 72 Go disque
- IPv4 : 162.19.246.465 (proxy Cloudflare Orange, https, www → 443, Full Strict)
- IPv6 : 2001:41d0:701:1100::208c
- Tailscale : `vps-5532a57a` (100.75.226.13) ↔ PC super-pc-vert (100.118.76.30)
- DNS : Cloudflare, Caddy 80/443 (ACME Let's Encrypt auto)
- Sécurité : UFW 22/80/443, fail2ban (sshd + recidive), SSH clé uniquement

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.41.3, Ollama, Browserless, FileBrowser, Netdata, Uptime‑Kuma, Nav.rennesdev, SPECTRE, Umami (app+db). PG 17 pour n8n, PG 16 pour Umami.

**Ollama** — modèles : qwen2.5:7b (bot IA), qwen2.5:3b (analyses), llama3.2:3b. `OLLAMA_KEEP_ALIVE=10m`.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30 (rappel 12h00). Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, metrics 📊 lun 08:00, ollama-unload 🧠 19:15, backup 💾 dim 19:30, backup-reminder 🔔 dim 12:00, github-weekly 📈 ven 19:00, daily-journal 📝 23:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel
> (section à renseigner — libre)

## 🐳 Services Docker
> (section à renseigner — synthèse des conteneurs, versions, ports exposés)

## 🔴 Logs & Erreurs
> (section à renseigner — incidents, anomalies en cours)
NEWETAT

logger -t vps-etat-rotate "Nouveau $(basename "$FICHIER") créé : $(wc -c < "$FICHIER") octets"

echo "✅ Rotation $(basename "$FICHIER") terminée le $(date '+%Y-%m-%d %H:%M')"