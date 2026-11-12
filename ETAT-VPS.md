# 📋 État du VPS rennesdev.fr — État courant
> Dernière mise à jour : **2026-11-12 16:30 UTC** (session maintenance 12/11).
> Historique archivé dans `ETAT-VPS-ARCHIVE.md` (rotation auto dimanche 18h00 + seuil 10 Ko).

## 📌 Infrastructure
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7,6 Go RAM, 72 Go disque (45% utilisés, 32 Go)
- IPv4 : 162.19.246.465 (proxy Cloudflare, Full Strict) · IPv6 : 2001:41d0:701:1100::208c
- Tailscale : `vps-5532a57a` (100.75.226.13) ↔ PC super-pc-vert (100.118.76.30)
- DNS Cloudflare, Caddy 80/443 (ACME Let's Encrypt auto), UFW 22/80/443, fail2ban, SSH clé uniquement
- Backups : Kopia → PC super-pc-vert (dimanche 19h30, rappel 12h00)

## 🐳 Docker (vérifié 12/11, tous Up)
| Conteneur | Rôle |
|---|---|
| `n8n_workflow` **n8n 2.48.2** (127.0.0.1:5678) | Automatisations — 10 workflows actifs |
| `n8n_db` PostgreSQL 17 | BDD n8n (backup pg_dump avant MAJ) |
| `twenty_server` + `twenty_db` (PG) + `twenty_redis` | CRM Twenty |
| `grafana` + `prometheus` | Monitoring métriques |
| `uptime-kuma` | Monitoring uptime externe |
| `filebrowser`, `browserless`, `vps-api-gateway` | Outils divers |

**IA/LLM** : plus de LLM local — **Ollama supprimé le 25/10/2026** → **Mistral Cloud API** (`MISTRAL_API_KEY`, exposé à n8n via compose). n8n 2.48.2 (MAJ 2.45.5→2.48.2 le 12/11, backup `~/n8n-db-avant-MAJ-2026-11-12.sql.gz`, trap volumes `external: true` + `N8N_ENCRYPTION_KEY`).

## 🤖 Automatisations GitHub (session 12/11)
- **GitHub Auditor** (workflow n8n, quotidien 06h00 Paris) : audit IA Mistral des ~21 repos actifs → rapport Telegram + commit `audit-AAAA-MM-JJ.md` dans `Ruaudel-Emmanuel/GitHub-Auditor`. Testé ✅ (rapport 12/11 commité).
- **stale-bot** (`actions/stale` épinglé SHA `4391f3da…` = v11) déployé sur **24 dépôts** — cron natif GitHub 04h30 Paris : stale 60j → close 74j (issues), 90j/120j (PR). Testé ✅ (run success). Lecteur-PDF via PR #9 (main protégé).
- Repos dédiés privés : `link-checker`, `github-actions-cleanup`, `secret-scan`, `actions-audit`, `stale-bot` (règle 1 projet = 1 repo).

## ⏰ Timers actifs (Europe/Paris, vérifiés 12/11)
| Timer | Rôle | Prochaine exécution |
|---|---|---|
| vps-watchdog | Check HTTPS/services toutes les 15 min → Telegram | 12/11 16:55 |
| vps-auto-update | MàJ auto quotidienne | 13/11 04h00 |
| **GitHub Auditor (n8n)** | Rapport IA quotidien | **13/11 06h00** |
| **stale-bot (cron GitHub)** | Fermeture issues/PR stale, 24 repos | **13/11 04h30** |
| github-weekly | Rapport hebdo GitHub | 13/11 19h00 |
| vps-daily-journal | Journal quotidien → repo privé | 12/11 23h00 |
| **secret-scan** | gitleaks historique complet (23 repos, 0 finding) | **17/11 03h00** |
| **link-checker** | Liens morts README + portfolios | **14/11 05h00** |
| **github-cleanup** | Supprime artifacts/caches Actions > 30j | **15/11 04h00** |
| vps-metrics-report | Rapport métriques hebdo | 16/11 08h00 |
| vps-etat-rotate | Archive ETAT-VPS.md | 15/11 18h00 |
| **actions-audit** | Audit Actions non épinglées en SHA (25 dépôts, 27 workflows) | **01/12 06h00** |
| vps-backup-sunday-reminder | Rappel backup Kopia | 15/11 12h00 |

Rapports Telegram après chaque run ; logs `/var/log/{link-checker,github-cleanup,secret-scan,actions-audit}-last.*`.

## 🚨 Incidents récents
- **10/11 13:17 UTC** : alerte watchdog « HTTPS n8n → code 000 » = perte **transitoire** de connectivité sortante VPS→Cloudflare (~15 s), pas une panne n8n (RAM 27%, Caddy OK, trafic continu). Symptômes collatéraux : timeouts vps-tgbot + chronyd NTS-KE. Aucune action requise.
- **12/11** : MAJ n8n 2.45.5 → 2.48.2 réussie (0 erreur, 9 workflows actifs, webhooks stripe/tally → 200).

## ⚠️ Points de vigilance
1. **PR Lecteur-PDF à merger** : #9 (stale-bot) + #10 (épinglage SHA ×4) — main protégé par ruleset.
2. **Lien mort** détecté par link-checker : `rennesdev/portofolio.html` ligne 537 → `github.com/Ruaudel-Emmanuel/construction-site-tracker` (404, repo renommé `Suivi-d-Interventions-avec-Photos`) — à corriger côté site.
3. **Actions non épinglées restantes** : 4 dans `Lecteur-PDF/ci.yml` (corrigées dans PR #10, en attente de merge).
4. Disque à 45% — surveiller avec les backups Kopia.

## 🔧 Fichiers clés
`~/docker-compose.yml` (volumes `n8n_data`/`n8n_pg_data` external, env GITHUB_PAT/MISTRAL_API_KEY/N8N_ENCRYPTION_KEY) · `~/.env` (secrets, ne jamais afficher) · `~/projects/rennesdev-vps-ops/systemd/` (units) · skills : `~/.agents/skills/{n8n-ops,github-ops,vps-sante}/SKILL.md` · `ORDRES.md` (ordres Telegram) · Telegram chat 8634051625.
