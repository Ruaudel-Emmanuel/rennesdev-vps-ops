# 🖥️ rennesdev-vps-ops

Scripts et unités systemd d'exploitation du VPS **rennesdev.fr** (OVH, Ubuntu 26.04) :
surveillance, alertes **Telegram**, sauvegardes **Kopia** vers un PC Windows 11 (via Tailscale), et sauvegarde à la demande par simple commande Telegram.

> ⚠️ **Aucun secret dans ce repo.** Tous les tokens (bot Telegram, webhook) vivent dans des fichiers root-only sur le VPS : `/etc/vps-watchdog-telegram.env`, `/etc/vps-watchdog.token`.

## Architecture

```
                         Tailscale (chiffré, direct)
  VPS rennesdev.fr ◄──────────────────────────────► PC Windows 11
  - Docker: n8n, umami, ollama                      - Kopia (repo + serveur :51515)
  - Caddy (frontal 80/443)                          - tâche planifiée "KopiaServer"
  - Kopia client (snapshots → PC)                   - OpenSSH Server (démarrage à distance)
  - watchdog (15 min) ──► Telegram @Vosmanubot
  - bot Telegram (polling) ◄── /backup /status
  - timers: backup dim 19:30, rappel dim 12:00 (Europe/Paris)
```

## Composants

| Fichier | Rôle |
|---|---|
| `scripts/vps-watchdog.sh` | Surveillance (disque, RAM, conteneurs, HTTPS, Kopia) → alerte Telegram. Anti-spam 6h. Timer : toutes les 15 min |
| `scripts/vps-tgbot.py` | Bot Telegram long-polling : `/backup`, `/status`, `/help` |
| `scripts/vps-backup-on-demand.sh` | Sauvegarde à la demande : démarre le serveur Kopia du PC à distance (SSH + tâche planifiée), lance `vps-backup.service`, rapporte sur Telegram |
| `scripts/vps-backup-reminder.sh` | Rappel hebdo dimanche 12:00 (Europe/Paris) : état backup → Telegram |
| `scripts/vps-tg.sh` | Helper d'envoi Telegram (source : `/etc/vps-watchdog-telegram.env`) |
| `scripts/kopia-staging.sh` | Staging : dump PostgreSQL umami + SQLite n8n + configs |
| `scripts/kopia-backup.sh` | Staging + snapshots Kopia (volumes Docker, /home/ubuntu, /etc/caddy) |
| `systemd/*.timer` | Planifications : watchdog 15 min · backup dim 19:30 · rappel dim 12:00 |

## Commandes Telegram (bot @Vosmanubot)

- **`/backup`** — lance tout : serveur Kopia du PC (à distance) + sauvegarde complète + rapport.
- **`/status`** — état instantané : disque, RAM, conteneurs, Kopia, dernier snapshot, prochain backup.
- **`/help`** — aide.

Le bot ne répond qu'au `TG_CHAT_ID` configuré (les autres chats sont ignorés).

## Installation VPS (résumé)

```bash
# 1. Secrets (root only)
sudo install -m 600 /dev/null /etc/vps-watchdog-telegram.env
#    → TG_BOT_TOKEN=... / TG_CHAT_ID=...

# 2. Scripts
sudo install -m 700 scripts/*.sh /usr/local/bin/
sudo install -m 700 scripts/vps-tgbot.py /usr/local/bin/

# 3. Units systemd
sudo install systemd/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now vps-watchdog.timer vps-backup.timer \
    vps-backup-reminder.timer vps-tgbot.service
```

## Setup PC Windows (one-time, admin PowerShell)

```powershell
# 1. OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd ; Set-Service sshd -StartupType Automatic

# 2. Clé publique du VPS (auth SSH sans mot de passe)
Add-Content -Path "$env:ProgramData\ssh\administrators_authorized_keys" `
    -Value 'ssh-ed25519 AAAA... kopia-vps'
icacls "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r `
    /grant "SYSTEM:F" /grant "BUILTIN\Administrators:F"

# 3. Tâche planifiée "KopiaServer" (démarrage session + certificat figé)
schtasks /Create /TN "KopiaServer" /RU $env:USERNAME `
  /TR "'C:\Users\Emmanuel\AppData\Local\Programs\KopiaUI\resources\server\kopia.exe' server start --address=0.0.0.0:51515" `
  /SC ONLOGON /RL HIGHEST /F
```

Depuis le VPS : `sudo ssh <user>@100.118.76.30 "schtasks /run /tn KopiaServer"` → le serveur Kopia démarre, sans session ouverte.

## Sécurité

- SSH VPS : clé uniquement (`PasswordAuthentication no`), fail2ban sshd + recidive
- UFW : 22/80/443 uniquement
- Bot Telegram : chat_id whitelisté, aucune commande arbitraire exécutée
- Secrets : jamais dans les scripts ni le repo (fichiers root 600)
