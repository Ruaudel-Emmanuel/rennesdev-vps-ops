# 📋 État du VPS rennesdev.fr — État courant
> Journal allégé depuis le 2026-09-14 (rotation, règle n°7) : ce fichier décrit l'état **actuel** uniquement.
> Historique complet : `ETAT-VPS-archive-2026-09.md` (et suivants, un par mois) — aussi sur GitHub.
> Rotation : le 1er de chaque mois, les entrées du mois écoulé partent dans une nouvelle archive.

---

## 🆕 Dernière session — 2026-09-14
- **Netdata installé** (supervision temps réel, choisi face à Prometheus) : conteneur `netdata`, ~200 Mo RAM, UI 127.0.0.1:19999 (accès = tunnel SSH), métriques VPS + conteneurs. Docs : `rennesdev-vps-ops/docs/netdata.md`.
- **Rapport quotidien Telegram 08:00 Paris** créé (`vps-metrics-report.timer` → `/usr/local/bin/vps-metrics-report.sh`) : uptime, RAM, disque, conteneurs, HTTPS, fail2ban, Kopia+PC, ollama, netdata. Testé OK.
- **Skill `vps-sante` créé** (`~/.agents/skills/vps-sante/`) : contrôle de santé standardisé, script exit 0/1, tout vert au test.
- **Rotation du journal** : historique → `ETAT-VPS-archive-2026-09.md`, ce fichier réécrit (5,5 Ko vs 54 Ko).
- **Méthode push GitHub validée** : PAT extrait de la base n8n en variable shell, jamais en session (doc `docs/push-github.md`).
- Tout est vert (skill vps-sante exit 0).
- **Vhost Caddy netdata.rennersdev.fr + basic auth créé (2e session)** : mot de passe fort généré (24 car., bcrypt via `caddy hash-password`), credentials dans `/etc/caddy/netdata-auth.txt` (root 600, inclus dans le snapshot /etc/caddy). Config validée + reload OK. **Bloqué sur DNS** : aucun enregistrement `netdata` dans Cloudflare (NXDOMAIN côté Let's Encrypt, cert non émis — Caddy re-essaie automatiquement). En attente utilisateur : créer l'enregistrement `netdata` A proxie orange dans Cloudflare.

---

## Infrastructure
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7.6 Go RAM, 72 Go disque (~30-31 Go utilisés, 42-44%)
- IPv4 : 162.19.246.165 — IPv6 : 2001:41d0:701:1100::208c — hostname Tailscale : `vps-5532a57a` (100.75.226.13)
- DNS chez **Cloudflare** (proxy orange, Full strict, Always Use HTTPS)

## Services & stacks
| Élément | Détail |
|---|---|
| Frontal | **Caddy** (80/443, certs ACME auto, expirent 2026-12-10, renouvellement auto) — `/etc/caddy/Caddyfile` |
| Umami | `umami_app` (127.0.0.1:3000) + `umami_db` (PG 16) — stack `~/umami/`, creds `~/umami/.credentials.txt` |
| n8n | `n8n_workflow` (127.0.0.1:5678) + `n8n_db` (**PostgreSQL 17**) — `~/docker-compose.yml`, mdp dans `~/.env` (`N8N_DB_PASSWORD`) |
| Ollama | `ollama` (127.0.0.1:11434), réseau Docker `apps` — modèles : `qwen2.5:7b` (bot IA), `llama3.2:3b`, `qwen2.5:3b`. `OLLAMA_KEEP_ALIVE=30m` |
| Netdata | `netdata`, UI **127.0.0.1:19999** (jamais exposé) — `~/netdata/docker-compose.yml` |
| Bot contrôle | `vps-tgbot.service` → `/usr/local/bin/vps-tgbot.py` (long polling) : `/backup`, `/status`, `/ordres`, `/ok`, `/help` |
| Bot IA | Workflow n8n « Agent Telegram » (bot dédié) : Telegram → Filter chat.id → Ollama qwen2.5:7b + PG Chat Memory → réponse |
| Sécurité | UFW (22/80/443), fail2ban (sshd + recidive), SSH par clé uniquement, `passwordauthentication=no` |

## Timers systemd
| Timer | Horaires (Europe/Paris) | Rôle |
|---|---|---|
| `vps-watchdog` | toutes les 15 min | anomalies → Telegram (`/usr/local/bin/vps-watchdog.sh`) |
| `vps-metrics-report` | tous les jours 08:00 | rapport métriques → Telegram (`/usr/local/bin/vps-metrics-report.sh`) |
| `vps-ollama-unload` | tous les jours 19:15 | décharge les modèles ollama avant backup |
| `vps-backup` | dimanche 19:30 | backup Kopia complet (PC allumé requis) |
| `vps-backup-reminder` | dimanche 12:00 | rappel Telegram (PC joignable ? dépôt ? âge snapshot) |

## Backups (Kopia)
- Chaîne : `vps-backup.timer` → `kopia-backup.sh` (staging = dump umami + pg_dump n8n + configs, puis snapshots : `/var/lib/docker/volumes`, `/home/ubuntu`, `/etc/caddy`) → **dépôt Kopia sur le PC Windows** (`super-pc-vert`, 100.118.76.30, port 51515, TLS cert RSA fixe, fingerprint `46d81925…`).
- À la demande : `/backup` Telegram → `vps-backup-on-demand.sh` (démarre le serveur Kopia du PC via SSH si besoin, clé `/root/.ssh/id_ed25519_pc`).
- Restauration : `kopia restore` (testée sur dumps). Certificat PC valable jusqu'en 2036.

## Tailscale
- VPS `vps-5532a57a` = 100.75.226.13 ↔ PC `super-pc-vert` = 100.118.76.30 (connexion directe, ~20 ms).

## 🧠 PRÉFÉRENCES UTILISATEUR (mémoire permanente)
1. **Canal d'alerte = Telegram** : bot `@Vosmanubot` (Bot-vps), chat `TG_CHAT_ID=8634051625`, config `/etc/vps-watchdog-telegram.env` (root 600). JAMAIS de token dans un fichier commité ou ce journal.
2. **Chaque nouveau workflow/création → repo GitHub avec README** : `github.com/Ruaudel-Emmanuel/rennesdev-vps-ops` (privé, local : `~/projects/rennesdev-vps-ops`). **Push sans PAT en session** : webhook n8n `POST https://n8n.rennesdev.fr/webhook/github-push` — PAT extrait de la base n8n (`n8n_db`, table `workflow_entity`, workflow « Push GitHub ») directement en variable shell du curl, jamais affiché ni sur disque. Voir `docs/push-github.md`.
3. Heures des timers : **Europe/Paris** (le serveur est en UTC).
4. L'utilisateur est sur **Windows 11** (`super-pc-vert`) — manipulations PC = pas-à-pas clairs.
5. **Aucun secret côté assistant** ; secrets → fichiers root-only sur le VPS.
6. **Au début de CHAQUE session : lire `/home/ubuntu/ORDRES.md`** (ordres via bot `@Vosmanubot`, message libre = ordre), les traiter, marquer ✅. `/ordres` liste, `/ok` vide.
7. **Maintenance du journal** : `ETAT-VPS.md` = état courant + dernière session ; le 1er de chaque mois → déplacer les entrées datées du mois écoulé dans `ETAT-VPS-archive-<AAAA-MM>.md` puis pusher les deux sur GitHub. Skill `vps-sante` (`~/.agents/skills/vps-sante/`) = procédure standard de contrôle de santé.
8. **Rapport quotidien 08:00 Paris** sur Telegram (`vps-metrics-report.timer`) — vérifier dans le contrôle santé qu'il est actif.

## ⏳ En attente (actions utilisateur)
- **DNS Cloudflare** : créer l'enregistrement `netdata` → A (proxy orange) pour acter https://netdata.rennesdev.fr (vhost Caddy + basic auth déjà en place ; Caddy re-tente le cert tout seul → rien à faire côté VPS une fois le DNS créé). Credentials : `/etc/caddy/netdata-auth.txt` (root 600) — **emmanuel** / mdp 24 caractères.
- (Optionnel, remplacé par le vhost) ~~tunnel SSH pour netdata~~.

## 🔎 Vérifications rapides utiles
```bash
bash ~/.agents/skills/vps-sante/scripts/vps-sante.sh   # contrôle complet (exit 0 = vert)
docker ps                                              # 6 conteneurs attendus
curl -s -o /dev/null -w '%{http_code}' https://n8n.rennesdev.fr   # 200
sudo fail2ban-client status sshd
docker exec ollama ollama list
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:19999     # 200 (netdata)
```

## Notes
- Historique détaillé (crises résolues, installations, debugging) : `ETAT-VPS-archive-2026-09.md`.
- Docs ops + workflows + scripts versionnés : `~/projects/rennesdev-vps-ops/` (= repo GitHub).
- Skill de contrôle santé : `~/.agents/skills/vps-sante/` (copié dans le repo GitHub).
