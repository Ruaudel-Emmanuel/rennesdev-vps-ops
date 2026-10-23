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
n8n v2.44.6, Ollama (qwen2.5:7b, qwen2.5:3b, llama3.2:3b),
Open WebUI, Twenty CRM (v2.50.1), Browserless, FileBrowser.
PG 17 pour n8n, PG 16 pour Twenty.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30.
Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, vps-daily-journal 📝 23h00,
vps-auto-update 🤖 04h00, vps-backup 💾 dim 19:30, vps-backup-reminder 🔔 dim 12:00,
github-weekly 📈 ven 19:00, vps-metrics-report 📊 lun 08:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram),
`~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Repos GitHub actifs** : rennesdev-vps-ops, GitHub-Auditor, vps-reinstall (🔒).

**Scripts clés** : `vps-backup-pause.sh`, `vps-auto-update.sh`, `vps-tgbot.py`.

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel (23/10/2026)

- ✅ **Open WebUI** déployé (port 8088, accès Tailscale uniquement, lié à Ollama)
- ✅ **Twenty CRM** déployé (port 8090, accès Tailscale uniquement, PG 16 + Redis)
- ✅ Ménage : netdata, uptime_kuma, umami, nav_rennesdev, spectre retirés
- ✅ Disque : 83% (13 Go libres)
- ✅ Backup Kopia : réparé, snapshot OK
- ✅ APT : à jour

## 🐳 Services Docker (9 conteneurs)

| Conteneur | Image | Statut |
|---|---|---|
| n8n_workflow | n8nio/n8n:2.44.6 | ✅ |
| n8n_db | postgres:17-alpine | ✅ |
| ollama | ollama/ollama:latest | ✅ |
| browserless | ghcr.io/browserless/chromium:latest | ✅ |
| filebrowser | filebrowser/filebrowser:v2 | ✅ |
| open_webui | ghcr.io/open-webui/open-webui:main | ✅ |
| twenty_server | twentycrm/twenty:latest | ✅ |
| twenty_db | postgres:16 | ✅ |
| twenty_redis | redis:7-alpine | ✅ |

## 🔴 Logs & Erreurs
> Aucune anomalie en cours.