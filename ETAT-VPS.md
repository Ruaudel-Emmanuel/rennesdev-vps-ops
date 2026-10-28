# 📋 État du VPS rennesdev.fr — État courant
> Rotation automatique — les sessions archivées sont dans `ETAT-VPS-ARCHIVE.md`.

## 📌 Résumé condensé de l'historique

**Infrastructure**
- VPS OVH — Ubuntu 26.04.1 LTS, 4 vCPU, 7,6 Go RAM, 72 Go disque
- IPv4 : 162.19.246.465 (proxy Cloudflare Orange, https, www → 443, Full Strict)
- IPv6 : 2001:41d0:701:1100::208c
- Tailscale : `vps-5532a57a` (100.75.226.13) ↔ PC super-pc-vert (100.118.76.30)
- DNS : Cloudflare, Caddy 80/443 (ACME Let's Encrypt auto)
- Sécurité : UFW 22/80/443, fail2ban (sshd + recidive), SSH clé uniquement

**Services conteneurisés** (réseau Docker `apps`) :
n8n v2.44.6, Twenty CRM (v2.50.1), Browserless, FileBrowser, Grafana, Prometheus, Uptime Kuma.
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

---

## ⚙️ État Actuel (28/10/2026)

- ✅ **Tunnel Cloudflare configuré** pour `surveillance.rennesdev.fr` → Grafana (port 3002)
  - Tunnel ID : `66ec38ad-b2eb-4fed-ba0d-8324f832c3f1`
  - Statut : HEALTHY
  - DNS CNAME corrigé : `surveillance.rennesdev.fr` → `66ec38ad-b2eb-4fed-ba0d-8324f832c3f1.cfargotunnel.com`
  - Route ingress configurée : `surveillance.rennesdev.fr` → `http://localhost:3002`
  - Reverse Proxy Nginx : `localhost:3002` → `100.75.226.13:3002` (Grafana)
  - Accès : [https://surveillance.rennesdev.fr](https://surveillance.rennesdev.fr) (Grafana, admin/GrafanaAdmin2026!)
- ✅ **Ollama + Open WebUI supprimés** — non adaptés aux capacités du VPS (très lent, erreurs)
- ✅ **Migration n8n vers Mistral Cloud** — 2 workflows actifs migrés (`devstral-2512`)
  - AI Personal Assistant : Ollama → Mistral Cloud
  - Agent Github (2 nœuds) : Ollama → Mistral Cloud
- ✅ **7 workflows n8n publiés** : Stripe, Tally x2, Push GitHub, Alertes VPS, Agent Github, AI Personal Assistant (webhooks fonctionnels)
- ✅ **Pi configuré sur Mistral** — provider `mistral`, modèle `devstral-2512`
- ✅ **Skill `gestion-modeles-locaux` supprimé** — plus pertinent sans Ollama
- ✅ **Disque : 48%** (34 Go utilisés, 38 Go libres) — gain de +35 Go (était 86% / 11 Go)
- ✅ **10 conteneurs actifs** (était 9) — ajout de Grafana et Prometheus
- ✅ **Timer `vps-ollama-unload` supprimé** — plus nécessaire
- ✅ **Scripts ops nettoyés** — watchdog, metrics, backup, staging, etat-rotate
- ✅ **Repo `vps-reinstall` mis à jour** — suppression Ollama/Open WebUI, ajout Mistral + configuration actuelle (branche `config-28102026`)

---

## 🐳 Services Docker (10 conteneurs)

| Conteneur | Image | Statut | Ports |
|---|---|---|---|
| n8n_workflow | n8nio/n8n:2.44.6 | ✅ | `0.0.0.0:5678->5678/tcp` |
| n8n_db | postgres:17-alpine | ✅ | `5432/tcp` |
| browserless | ghcr.io/browserless/chromium:latest | ✅ | `127.0.0.1:3100->3000/tcp` |
| filebrowser | filebrowser/filebrowser:v2 | ✅ | `127.0.0.1:8085->80/tcp` |
| twenty_server | twentycrm/twenty:latest | ✅ | `0.0.0.0:8090->3000/tcp` |
| twenty_db | postgres:16 | ✅ | `5432/tcp` |
| twenty_redis | redis:7-alpine | ✅ | `6379/tcp` |
| grafana | grafana/grafana:latest | ✅ | `100.75.226.13:3002->3000/tcp` |
| prometheus | prom/prometheus:latest | ✅ | `100.75.226.13:9090->9090/tcp` |
| uptime-kuma | louislam/uptime-kuma:latest | ✅ | `100.75.226.13:3001->3001/tcp` |

---

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

---

## 🌐 Services Système (hors Docker)

| Service | Statut | Description |
|---|---|---|
| cloudflared | ✅ Active (running) | Tunnel Cloudflare pour `surveillance.rennesdev.fr` |
| nginx | ✅ Active (running) | Reverse proxy pour Grafana (`localhost:3002`) |
| caddy | ✅ Active (running) | Serveur web (port 80) |
| fail2ban | ✅ Active (running) | Protection contre les attaques par force brute |
| docker | ✅ Active (running) | Moteur de conteneurs Docker |

---

## 📊 Ressources (28/10/2026)

| Ressource | Total | Utilisé | Disponible | % Utilisé |
|---|---|---|---|---|
| RAM | 7.6 GiB | 2.9 GiB | 4.7 GiB | ~38% |
| Swap | 1.0 GiB | 68 MiB | 955 MiB | ~7% |
| Disque (/dev/sda1) | 72 GiB | 34 GiB | 38 GiB | 48% |

---

## 🔴 Logs & Erreurs
> Aucune anomalie en cours.

---

## 📅 Dernières Mises à Jour
- **28/10/2026** :
  - Configuration du tunnel Cloudflare pour `surveillance.rennesdev.fr` → Grafana.
  - Mise en place du reverse proxy Nginx pour Grafana.
  - Correction du DNS CNAME pour pointer vers le bon tunnel.
  - Ajout de la route ingress dans le tableau de bord Cloudflare.
  - Création de la branche `config-28102026` dans `vps-reinstall` avec la configuration actuelle.
- **25/10/2026** :
  - Suppression d'Ollama et Open WebUI.
  - Migration de n8n vers Mistral Cloud.
  - Nettoyage des scripts et timers obsolètes.
