# rennesdev-vps-ops

Scripts, unités systemd et workflows d'exploitation d'un VPS : surveillance, alertes Telegram, journal quotidien et rapports.

## Contenu

- `scripts/` — scripts shell/python d'exploitation :
  - `vps-watchdog.sh` — vérifie disque, RAM, conteneurs Docker, HTTPS public, état du backup Kopia ; alerte Telegram (timer toutes les 15 min)
  - `vps-tgbot.py` — bot Telegram en long polling (commandes `/backup`, `/status`, `/ordres`, `/ok`, `/help`) ; enregistre les messages non-commandes dans `ORDRES.md`
  - `vps-tg.sh` — envoi d'un message Telegram (config `/etc/vps-watchdog-telegram.env`)
  - `vps-daily-journal.sh` — résumé quotidien du VPS (timer tous les jours 23h00 Europe/Paris)
  - `vps-backup-on-demand.sh` — sauvegarde Kopia à la demande (démarre le serveur Kopia du PC via SSH, lance `vps-backup.service`, rapporte sur Telegram)
  - `vps-backup-reminder.sh` — rappel hebdomadaire dimanche 12:00 Europe/Paris : état des sauvegardes → Telegram
  - `vps-metrics-report.sh` — rapport quotidien des métriques VPS → Telegram (08h00 Europe/Paris)
  - `github-weekly-report.sh` — rapport hebdomadaire de l'activité GitHub → repo `git-ops-journal` (vendredi 19h00 Europe/Paris)
  - `vps-issue.sh` — ouvre/clôt des issues GitHub depuis les scripts d'alerte
  - `git-cred-helper.sh` — credential helper git lisant le PAT dans `/etc/vps-github.env` (jamais affiché)
- `systemd/` — 17 unités systemd (`.service`/`.timer`) : watchdog, backup, rappel backup, journal, tgbot, maintenance hebdomadaire, et timers d'audit GitHub (secret-scan, link-checker, github-cleanup, actions-audit)
- `workflows/` — exports JSON des workflows n8n (GitHub Auditor, Stripe/Tally, diffusion Discord, push-github, eclaireur, etc.) avec README par dossier quand présent
- `docs/` — documentation : accès mobile Tailscale, cadence GitHub, netdata, push GitHub sans secret, setup Kopia (PowerShell)
- `skills/` — fichiers SKILL.md (github-ops, n8n-ops, stripe-ops, tally-ops, uptime-kuma, vps-sante)
- `netdata/docker-compose.yml` — compose Netdata
- `ETAT-VPS.md` + archives — état courant du VPS et archives mensuelles
- `.github/` — templates d'issues/PR et workflow `stale.yml`

## Usage

Les scripts sont exécutés sur le VPS via les timers systemd de `systemd/` (ou en direct pour `vps-tg.sh "message"`). Aucun secret n'est présent dans ce repo : les tokens vivent dans des fichiers root-only sur le VPS (`/etc/vps-watchdog-telegram.env`, `/etc/vps-github.env`).
