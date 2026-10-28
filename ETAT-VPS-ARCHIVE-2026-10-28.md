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

**Services conteneurisés** (réseau Docker `apps`) :
n8n v2.44.6, Twenty CRM (v2.50.1), Browserless, FileBrowser.
PG 17 pour n8n, PG 16 pour Twenty.

**IA / LLM** — API **Mistral Cloud** (`devstral-2512`) via credential n8n `mistralCloudApi`.
Ollama + Open WebUI supprimés le 25/10/2026 (non adaptés aux capacités du VPS).

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30.
Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, vps-daily-journal 📝 23h00,
vps-auto-update 🤖 04h00, vps-backup 💾 dim 19:30, vps-backup-reminder 🔔 dim 12:00,
github-weekly 📈 ven 19:00, vps-metrics-report 📊 lun 08:00, vps-etat-rotate 🔄 quotidien.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram),
`~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Repos GitHub actifs** : rennesdev-vps-ops, GitHub-Auditor, vps-reinstall (🔒).

**Scripts clés** : `vps-backup-pause.sh`, `vps-auto-update.sh`, `vps-tgbot.py`.

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel (25/10/2026)

- ✅ **Ollama + Open WebUI supprimés** — non adaptés aux capacités du VPS (très lent, erreurs)
- ✅ **Migration n8n vers Mistral Cloud** — 2 workflows actifs migrés (`devstral-2512`)
  - AI Personal Assistant : Ollama → Mistral Cloud
  - Agent Github (2 nœuds) : Ollama → Mistral Cloud
- ✅ **4 workflows n8n publiés** : Stripe, Tally x2, Push GitHub (webhooks fonctionnels)
- ✅ **Pi configuré sur Mistral** — provider `mistral`, modèle `devstral-2512`
- ✅ **Skill `gestion-modeles-locaux` supprimé** — plus pertinent sans Ollama
- ✅ **Disque : 37%** (46 Go libres) — gain de +35 Go (était 86% / 11 Go)
- ✅ **7 conteneurs actifs** (était 9) — ollama et open_webui retirés
- ✅ **Timer `vps-ollama-unload` supprimé** — plus nécessaire
- ✅ **Scripts ops nettoyés** — watchdog, metrics, backup, staging, etat-rotate
- ✅ **Repo `vps-reinstall` mis à jour** — suppression Ollama/Open WebUI, ajout Mistral
- ✅ **Backup n8n** effectué avant migration (`/tmp/n8n-backup-20261025-095147.sql`)

## 🐳 Services Docker (7 conteneurs)

| Conteneur | Image | Statut |
|---|---|---|
| n8n_workflow | n8nio/n8n:2.44.6 | ✅ |
| n8n_db | postgres:17-alpine | ✅ |
| browserless | ghcr.io/browserless/chromium:latest | ✅ |
| filebrowser | filebrowser/filebrowser:v2 | ✅ |
| twenty_server | twentycrm/twenty:latest | ✅ |
| twenty_db | postgres:16 | ✅ |
| twenty_redis | redis:7-alpine | ✅ |

## 🤖 Workflows n8n actifs (7)

| Workflow | Type | LLM |
|---|---|---|
| AI Personal Assistant | Chat webhook | Mistral Cloud (devstral-2512) |
| Agent Github | Cron 06h00 + webhook | Mistral Cloud (devstral-2512) |
| Alertes VPS (watchdog) | Webhook /vps-alert | — |
| Stripe — alerte paiement | Webhook /stripe-paiement | — |
| Tally — alerte message | Webhook /tally-alerte | — |
| Tally — alerte photographe | Webhook /tally-photographe | — |
| Push GitHub | Webhook /github-push | — |

## 🔴 Logs & Erreurs
> Aucune anomalie en cours.
