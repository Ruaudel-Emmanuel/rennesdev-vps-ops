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

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.44.6, Ollama, Browserless, FileBrowser, Netdata, Uptime‑Kuma, Nav.rennesdev, Umami (app+db). PG 17 pour n8n, PG 16 pour Umami.

**Ollama** — modèles : qwen2.5:7b (bot IA), qwen2.5:3b (analyses), llama3.2:3b. `OLLAMA_KEEP_ALIVE=10m`.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30 (rappel 12h00). Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, auto-update 🤖 04h00, metrics 📊 lun 08:00, ollama-unload 🧠 19:15, backup 💾 dim 19:30, backup-reminder 🔔 dim 12:00, github-weekly 📈 ven 19:00, daily-journal 📝 23h00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Repos GitHub** : `vps-reinstall` 🔒 (package de réinstallation), `install-vps` 🌍 (installation client anonyme), `GitHub-Auditor`, `rennesdev-vps-ops`.

**Scripts clés** : `vps-backup-pause.sh` (pause/reprise backup), `vps-auto-update.sh` (màj quotidiennes 04h00), `vps-tgbot.py` (bot Telegram /pause /resume /status /backup).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel
> Dernière session : 23/10/2026 — Tous les ordres Telegram traités ✅

**Mis à jour :**
- ✅ n8n 2.43.6 → 2.44.6
- ✅ Màj automatiques : timer 04h00 Paris + Docker recréé si nouvelle image
- ✅ Pause backup : script + commandes Telegram (/pause, /resume)
- ✅ 4 README refondus (Fiscale-vps, rennesdev, aac-audit-journal, VPS-Rennesdev.fr)
- ✅ Skill positionnement-readme enrichi
- ✅ Repos créés : vps-reinstall (privé) + install-vps (public)
- ✅ Disque : 95% → 79% (19 Go libérés)
- ✅ **Open WebUI** déployé (port 8088, accès Tailscale uniquement, lié à Ollama)
- ✅ **Twenty CRM** déployé (port 8090, accès Tailscale uniquement, PG 16 + Redis)
- ✅ Ménage : netdata, uptime_kuma, umami, nav_rennesdev, spectre retirés (→ +7 Go, disque 83%)

## 🐳 Services Docker
> **9 conteneurs** (netdata, uptime_kuma, umami, nav_rennesdev, spectre retirés)

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
| twenty_worker | twentycrm/twenty:latest | ✅ |

## 🔴 Logs & Erreurs
> Aucune anomalie en cours.

- ⚠️ **Disque 79%** (57G/72G) — sous contrôle, 19 Go libérés le 23/10
