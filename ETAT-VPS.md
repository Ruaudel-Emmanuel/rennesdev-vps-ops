# 📋 État du VPS rennesdev.fr — État courant
> Dernière mise à jour : **2026-11-14 21:35 UTC** (vérification ORDRE 9 après session interrompue + contrôle santé complet, voir section dédiée).
> Historique archivé dans `ETAT-VPS-ARCHIVE.md` (rotation auto dimanche 18h00 + seuil 10 Ko).

## 📌 Infrastructure
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7,6 Go RAM, 72 Go disque (45% utilisés, 32 Go)
- IPv4 : 162.19.246.465 (proxy Cloudflare, Full Strict) · IPv6 : 2001:41d0:701:1100::208c
- Tailscale : `vps-5532a57a` (100.75.226.13) ↔ PC super-pc-vert (100.118.76.30)
- DNS Cloudflare, Caddy 80/443 (ACME Let's Encrypt auto), UFW 22/80/443, fail2ban, SSH clé uniquement
- Backups : ~~Kopia → PC super-pc-vert~~ **DÉSACTIVÉ depuis le 01/11** (réinstallation en pause, scripts + timers supprimés — voir archive 2026-11-01). Seul reste `vps-backup-sunday-reminder.timer` (rappel). À réactiver.

## 🐳 Docker (vérifié 14/11 21:29 UTC, tous Up — 11 conteneurs, 7 contrôlés par vps-sante ✅)
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
- **GitHub Auditor** (workflow n8n, cron `0 6 * * *`) : audit IA Mistral des ~26 repos actifs → **résumé Telegram (sendMessage <4000 car.) + rapport complet en document (sendDocument `audit-AAAA-MM-JJ.md`)** + commit dans `Ruaudel-Emmanuel/GitHub-Auditor`. **Corrigé + re-testé le 14/11** (run 141 ✅ : message_id 626 + document 627) — voir section 14/11.
- ⚠️ Le cron `0 6 * * *` est interprété en **America/New_York** (pas de `timezone` sur le workflow) → run à **11:00 UTC (12:00 Paris)**, pas 06h00 Paris.
- **stale-bot** (`actions/stale` épinglé SHA `4391f3da…` = v11) déployé sur **24 dépôts** — cron natif GitHub 04h30 Paris : stale 60j → close 74j (issues), 90j/120j (PR). Testé ✅ (run success). Lecteur-PDF via PR #9 (main protégé).
- Repos dédiés privés : `link-checker`, `github-actions-cleanup`, `secret-scan`, `actions-audit`, `stale-bot` (règle 1 projet = 1 repo).

## 🔧 Session 14/11/2026 — ORDRE 9 vérifié après session interrompue (résumé)
- ORDRES.md ne contenait qu'un ordre (n°9, marqué ✅) mais la vérification réelle a montré **M4 incomplet** : le résumé Telegram partait (msg 622) mais le **sendDocument échouait** (« no document in the request » aux runs 134/136/139).
- **3 correctifs appliqués** au workflow `e7ac113e…` (snapshot actif `a3b5ba51…`) : (1) nœud Telegram `binaryData=true` + `binaryPropertyName=document` + `prepareBinaryData()` dans le Code node (task runner) ; (2) `parse_mode=""` sur les 2 nœuds Telegram (défaut HTML cassait les entités du markdown IA) ; (3) cron de test restauré à `0 6 * * *`.
- **Test final run 141 (14/11 21:00 UTC) : success** — 2× `ok:true`, message_id **626** (résumé) + **627** (📄 document `audit-2026-11-14.md`, file_id reçu), 0 erreur.
- **M3 re-fait** : commit `71782ed` « fix: sendDocument fonctionnel… » poussé sur `Ruaudel-Emmanuel/GitHub-Auditor` (workflow.json, 11 nœuds, JSON valide, 0 secret).
- **Rapport Telegram envoyé** (message_id 628). Run 135 (18:24) en erreur = artefact `TaskRequestTimeoutError` (task runner down post-restart), pas un bug.
- Contrôle santé 14/11 21:29 UTC : conteneurs ✅, HTTPS ✅ (n8n edge+origine 200), RAM 35% ✅, disque 45% ✅, fail2ban ✅, 15 paquets APT en attente (⚠️ normal, auto-update quotidien). **Faux positif connu** : `vps-backup(.timer)`/`vps-backup-reminder(.timer)` inactifs = Kopia désactivé volontairement le 01/11.

## 🔧 Session 13/11/2026 — ordres Telegram 1 à 7 (résumé)
- **Watchdog** (`/home/ubuntu/automation/scripts/watchdog.sh`, déplacé là le 01/11) : section HTTPS = `n8n.rennesdev.fr:200` seul (**umami retiré** : NXDOMAIN + conteneur supprimé) ; **auto-clôture `close-prefix "Watchdog VPS :"` restaurée** au passage vert ; cap Telegram 4000 car. ; watchdog 🟢 vert.
- **PAT GitHub** : nouvelle source **`/etc/vps-github.env`** (root:ubuntu **640**, test API = **HTTP 200 valide**). Le workflow « Push GitHub » n'existe plus dans la base n8n (rebuild 29-30/10) → `vps-issue.sh` redéployé (700 root) avec cette source → chaîne issues OK. Credential helper `/home/ubuntu/automation/scripts/git-cred-helper.sh` (700) configuré sur les repos ops + journal.
- **Règle Telegram 4000 car.** (UTF-16, limite API 4096) appliquée partout : 6 nœuds Telegram n8n (`slice(0,4000)`, draft + snapshots actifs, n8n restart OK), scripts bash (`tg_cap`), scripts python (cap `utf-16-le[:8000]`) ; test bout-en-bout ✅ (5000 car → 400 refusé ; cap → exactement 4000 reçues). Règle documentée dans `skills/n8n-ops/SKILL.md`.
- **Journal quotidien réparé** : unité systemd (tiret→underscore dans `ExecStart`), bloc git restauré dans `daily_journal.sh` (commit + `push origin main` auto) → cycle testé ✅ (`b3cd647 Journal 2026-11-13 (auto)` poussé). **Repo `VPS-Rennesdev.fr` désarchivé** : 18 commits d'attente + rattrapage 01/11+13/11 poussés.
- **Repo `rennesdev-vps-ops` aligné sur la prod** et poussé (`a109467` sync scripts, `9e17134` auto-clôture, `7cff9a7` cap Telegram).

## ⏰ Timers actifs (Europe/Paris, vérifiés 14/11 21:29 UTC)
| Timer | Rôle | Prochaine exécution |
|---|---|---|
| vps-watchdog | Check HTTPS/services toutes les 15 min → Telegram | 14/11 21:44 |
| vps-auto-update | MàJ auto quotidienne | 15/11 03:01 |
| **GitHub Auditor (n8n)** | Résumé + rapport complet (document) quotidiens | **15/11 11:00 UTC** (cron en America/New_York) |
| **stale-bot (cron GitHub)** | Fermeture issues/PR stale, 24 repos | 15/11 04:30 |
| github-weekly | Rapport hebdo GitHub | ven 20/11 19h00 |
| vps-daily-journal | Journal quotidien → repo (push auto restauré) | 14/11 22:00 |
| **secret-scan** | gitleaks historique complet (23 repos, 0 finding) | **17/11 03h00** |
| **link-checker** | Liens morts README + portfolios | 21/11 05h00 |
| **github-cleanup** | Supprime artifacts/caches Actions | **15/11 03h00** |
| vps-metrics-report | Rapport métriques hebdo | 16/11 08h00 |
| vps-etat-rotate | Archive ETAT-VPS.md | 15/11 17h00 |
| **actions-audit** | Audit Actions non épinglées en SHA | **01/12 06h00** |
| vps-backup-sunday-reminder | Rappel backup Kopia (**backup désactivé**) | 15/11 10h00 |

Rapports Telegram après chaque run ; logs `/var/log/{link-checker,github-cleanup,secret-scan,actions-audit}-last.*`.

## 🚨 Incidents récents
- **14/11** : session assistant interrompue brutalement avec ORDRE 9 marqué ✅ — à la reprise, M4 était incomplet (sendDocument en échec « no document in the request » puis « can't parse entities »). 3 correctifs appliqués (binaryData/binaryPropertyName + prepareBinaryData + parse_mode off), re-test run 141 ✅ (2 livraisons Telegram OK), workflow re-versionné (`71782ed`), rapport Telegram 628. Leçon : une marque ✅ ne dispense pas de la vérification (run n8n + commits + livraisons réelles).
- **13/11** : watchdog rouge après resync (faux positifs : umami NXDOMAIN testé 200, n8n réel 200 vs attendu 401) → corrigé (liste = `n8n.rennesdev.fr:200` seul, run vert ✅). `vps-daily-journal.service` en **203/EXEC** depuis le 08/11 (ExecStart tiret au lieu d'underscore) → corrigé, journal généré + poussé ✅. Push repo journal bloqué : repo **archivé read-only** (403) → désarchivé, 18 commits + rattrapage poussés ✅. Chaîne issues muette (vps-issue.sh absent + PAT plus en base n8n) → restaurée via `/etc/vps-github.env` (PAT 200) ✅.
- **10/11 13:17 UTC** : alerte watchdog « HTTPS n8n → code 000 » = perte **transitoire** de connectivité sortante VPS→Cloudflare (~15 s), pas une panne n8n (RAM 27%, Caddy OK, trafic continu). Symptômes collatéraux : timeouts vps-tgbot + chronyd NTS-KE. Aucune action requise.
- **12/11** : MAJ n8n 2.45.5 → 2.48.2 réussie (0 erreur, 9 workflows actifs, webhooks stripe/tally → 200).

## ⚠️ Points de vigilance
1. **PR Lecteur-PDF #10 à merger** (épinglage SHA ×4) — main protégé par ruleset. PR #9 (stale-bot) mergée ✅ le 14/11.
2. **Lien mort** détecté par link-checker : `rennesdev/portofolio.html` ligne 537 → `github.com/Ruaudel-Emmanuel/construction-site-tracker` (404, repo renommé `Suivi-d-Interventions-avec-Photos`) — à corriger côté site.
3. **Actions non épinglées restantes** : 4 dans `Lecteur-PDF/ci.yml` (corrigées dans PR #10, en attente de merge).
4. **umami.rennesdev.fr supprimé** (NXDOMAIN, plus de conteneur) — ne plus le surveiller/référencer (watchdog retiré le 13/11).
5. Workflow n8n « Push GitHub » absent de la base (rebuild 29-30/10) : le PAT shell passe par `/etc/vps-github.env`, pas par la DB.
6. **Backups Kopia désactivés depuis le 01/11** (réinstallation en pause) — aucune sauvegarde auto active actuellement ; à réactiver en priorité.
7. **Cron GitHub Auditor en America/New_York** (11:00 UTC au lieu de 06h00 Paris) — à corriger (ajouter `timezone: Europe/Paris` dans settings du workflow).
8. Disque à 45% — surveiller.

## 🔧 Fichiers clés
`~/docker-compose.yml` (volumes `n8n_data`/`n8n_pg_data` external, env GITHUB_PAT/MISTRAL_API_KEY/N8N_ENCRYPTION_KEY) · `~/.env` (secrets, ne jamais afficher) · `~/projects/rennesdev-vps-ops/systemd/` (units) · skills : `~/.agents/skills/{n8n-ops,github-ops,vps-sante}/SKILL.md` · `ORDRES.md` (ordres Telegram) · Telegram chat 8634051625.
