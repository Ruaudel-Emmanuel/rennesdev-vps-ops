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

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.48.2, PG 17 (n8n_db), Browserless, FileBrowser, Twenty (server+db+redis), Uptime-Kuma, Grafana, Prometheus, vps-api-gateway. **Ollama supprimé le 25/10/2026** — IA via API Mistral Cloud.

**Backups** — Kopia **désactivé volontairement depuis le 01/11** ; seul `vps-backup-sunday-reminder.timer` (dim 10h00) actif. Aucune sauvegarde auto active.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, metrics 📊 lun 08:00, github-weekly 📈 ven 19:00, daily-journal 📝 23:00, etat-size 🕐 horaire, etat-rotate 🔄 dim 18:00, backup-sunday-reminder 🔔 dim 10:00, secret-scan 🔍 mar 03:00, link-checker 🔗 sam 05:00, github-cleanup 🧹 dim 04:00, actions-audit 📌 1er du mois 06:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel
> (section à renseigner — libre)

## 🐳 Services Docker
> (section à renseigner — synthèse des conteneurs, versions, ports exposés)

## 🔴 Logs & Erreurs
> (section à renseigner — incidents, anomalies en cours)
