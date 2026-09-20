# 📋 État du VPS rennesdev.fr — État courant
> Journal allégé depuis le 2026-09-14 (rotation, règle n°7) : ce fichier décrit l'état **actuel** uniquement.
> Historique complet : `ETAT-VPS-archive-2026-09.md` (et suivants, un par mois) — aussi sur GitHub.
> Rotation : le 1er de chaque mois, les entrées du mois écoulé partent dans une nouvelle archive.

---

## 🆕 Dernière session — 2026-09-20
- **✅ n8n mis à jour 2.39.6 → 2.39.8** (dump préalable `~/n8n-db-avant-MAJ-2026-09-20.sql.gz`, conteneur recréé) : `/healthz` 200, 10 workflows actifs, webhooks OK.
- **✅ Uptime-Kuma en production** : conteneur `uptime_kuma` (127.0.0.1:3001, mem_limit 512 m, volume `kuma_data`, réseau `apps`), vhost **https://uptime.rennesdev.fr** (basic auth + login Kuma), **8 moniteurs** (n8n, Umami, Nav, Fichiers, Netdata, Browserless, Ollama, port PG n8n_db — 60 s, maxretries 2), **notification Telegram liée aux 8**, 130+ heartbeats enregistrés. Skill `uptime-kuma` créé (argument commercial « Résilience/Garantie »). Record DNS créé par l'utilisateur (proxy orange).
- **✅ Browserless (Chromium headless) déployé** : conteneur `browserless` (127.0.0.1:3100 → 3000, mem_limit 1500 m, shm 512 m), token API dans `~/.env` (`BROWSERLESS_TOKEN`). Usage depuis n8n : `http://browserless:3000?token=…`. Tests réels : screenshot PNG 200, mauvais token → 401.
- **🔧 Fin de chantier interrompu (continué par l'assistant)** : cert LE d'uptime non émis (retries ACME planifiés avant la création du DNS — même piège que Nav le 19/09) → **restart Caddy, cert obtenu 15:41 UTC, HTTPS 200**. Fichier `/etc/caddy/uptime-auth.txt` incomplet (commentaires sans ligne identifiants) → **mot de passe régénéré** et écrit (root 600) ; mot de passe Kuma (bcrypt en base) réaligné sur le même, vérifié par comparaison bcrypt.
- **⚠️ Incident Caddy (rattrapé dans la foulée)** : deux appels `caddy hash-password` défaillants (refus stdin dans cet environnement ; `-p` prend le mot de passe littéral, pas un fichier) puis un `sed` trop large ont vidé les 3 hash `basic_auth` du Caddyfile — le reload en échec a maintenu la config valide en RAM ; restauration faite depuis les plaintexts root-only (`nav-auth.txt`, `netdata-auth.txt`, uptime regénéré), hash produits avec bcryptjs du conteneur Kuma (`$2a$10$`, accepté par Caddy). Vérifié : uptime 302→dashboard, nav 200, netdata 200, **401 sans auth sur les 3**. Leçon : écrire les hash via un heredoc Python ou un outillage validé, jamais un sed sur motif partiel.
- Divers : skills réorganisés (`.md` + `SKILL.md`, notamment `post-mortem`, `roi-mesure-gain`, `sequence-conversation`, `profil-utilisateur`, `integration-data`, `methodologie-conseil-ia`) ; contrôle santé du 20/09 vert (disque 60 %, RAM 2,0/7,6 Go, Kopia dépôt connecté).

## 🆕 Dernière session — 2026-09-19 (5e partie)
- **✅ Nav.rennesdev v2 : assistant IA intégré (ordre utilisateur, test v1 validé)** — développée sur branche dédiée `v2-assistant-ia` (règle 11), commits commentés. Bouton **🤖 IA** dans la barre du lecteur → panneau (Résumer / question libre) → **qwen2.5:3b en local** via `POST /ia` (Ollama, réseau `apps`). Le serveur réutilise la page déjà extraite pour l'affichage via un **cache mémoire** (TTL 15 min, 30 pages max) : l'IA voit le contenu directement, zéro copier-coller. `keep_alive: 0` → RAM déchargée après chaque réponse (vérifié : 1,7 Go au repos). Tests réels : résumé ~72 s, question ~59 s, HTTPS+basic auth OK, erreurs JSON propres.
- **✅ Tests concluants (utilisateur) → branche `v2-assistant-ia` fusionnée dans `main`** (merge, README ajusté, poussé) ; branche supprimée localement et sur GitHub après fusion. Repo `Nav.rennesdev` : `main` = v1+v2.
- Leçon outillage : le pipeline d'édition de l'assistant décode les entités HTML → toute écriture de code contenant des entités doit passer par un heredoc Python (les échappements `\u0026` dans les chaînes JS restent fiables). Bugs v2 corrigés en route : endpoint `/ia` oublié (script mort à la compilation), `</script>` d'historique manquant, panneau inséré au mauvais endroit.

## 🆕 Dernière session — 2026-09-19 (4e partie)
- **✅ Nav.rennesdev v1 en production** : record DNS créé (proxy orange), **cert Let's Encrypt émis** (après restart Caddy pour forcer le retry — les retries auto étaient planifiés trop loin) — HTTPS 200 via Cloudflare, basic auth OK (401 sans), navigation wiki testée via https://nav.rennesdev.fr. Conteneur recréé depuis le nouveau chemin `~/projects/Nav.rennesdev` (ancien `~/nav` déplacé — convention projets).
- **✅ Règle GitHub (ordre Telegram 10h56, rétroactive)** : 1 projet = 1 repo → **Nav.rennesdev sorti de rennesdev-vps-ops** et poussé dans son **propre repo privé `Nav.rennesdev`** (créé via webhook, création auto) ; `nav/` retiré du repo ops. Améliorations d'un projet = **nouvelle branche** dédiée, commits commentés. Règle enregistrée dans les préférences + skill `github-ops`.

## 🆕 Dernière session — 2026-09-19 (2e partie)
- **✅ ÉCLAIREUR testé en réel par l'utilisateur** : page inexistante → erreur 404 propre en 1,2 s ; page réelle + question ciblée (wiki IA) → réponse pertinente de qwen2.5:3b en **49 s**. Chaîne complète validée de bout en bout, aucune modification du workflow.
- **Play Console : compte confirmé « Particulier »** (profil de paiement validé le 01/07/2026) → **pas de dérogation possible** : la règle des comptes personnels récents s'applique — **test fermé avec ≥ 20 testeurs optés en continu pendant 14 jours** avant l'accès à la production (les tests internes et les 11 testeurs actuels ne comptent pas). Plan donné à l'utilisateur : (1) créer la piste « Test fermé » pour chaque app avec l'AAB déjà validé, (2) recruter 9-10 testeurs de plus (≥ 20 au total, lien d'opt-in + installation réelle + engagement pendant 14 j), (3) les mêmes testeurs sur les 2 apps → les 14 jours tournent en parallèle, (4) à J+14 le formulaire « Demander l'accès à la production » se débloque. Itérations AAB possibles pendant l'attente sans casser la piste.

## 🆕 Dernière session — 2026-09-19
- **✅ ÉCLAIREUR déployé (ordre utilisateur « lance eclaireur »)** : l'idée en réserve est passée en production — workflow n8n « ÉCLAIREUR — lecture de page web (Ollama) », webhook **POST https://n8n.rennesdev.fr/webhook/eclaireur** protégé par header `X-Eclaireur-Key` (clé générée, `/etc/eclaireur-key.txt` root 600). Chaîne : HTTP GET → extraction texte (strip HTML, entités FR, **2500 car. max**) → Ollama **qwen2.5:3b** (résumé 5 phrases max ou Q&A sur `question`) → réponse JSON. Tests réels OK : résumé wiki ~83 s, question ciblée ~52 s, erreurs (clé 401, URL invalide, page 404) < 2 s, **modèle déchargé après usage** (`keep_alive: 0`, RAM au repos inchangée). README + workflow.json exportés (clé en placeholder, grep vérifié) → poussés sur `rennesdev-vps-ops/workflows/eclaireur/`. Skill `n8n-ops` enrichi des nouveaux pièges.
- **Pièges découverts (détail dans skill n8n-ops + README ÉCLAIREUR)** : nœud Webhook **sans `webhookId`** → webhook production non enregistré (404 « not registered ») ; workflow créé en SQL sans ligne `shared_workflow` → activation en boucle `EntityNotFoundError` ; HTTP Request `responseFormat: text` renvoie le HTML dans `data` sans `statusCode` (→ `fullResponse: true`) ; **Cloudflare coupe à 100 s** (524) → le 7b (~12 tokens/s en CPU) était trop lent, bascule sur le 3b (~28 tokens/s) et réduction du texte extrait.
- ⚠️ **PAT GitHub affiché de nouveau en session 19/09** (lecture du nœud « Config » de « Push GitHub » pour calquer la structure d'un webhook — sortie non filtrée, 3e occurrence). Aucun push sur disque du token ; **rotation à la prochaine occasion** (l'utilisateur génère le token, le colle dans « Push GitHub », l'assistant le propage SQL aux autres nœuds).
- Divers : correction de la table Services (`OLLAMA_KEEP_ALIVE=10m` n'était pas répercuté) ; contrôle santé du 19/09 tout vert (7 conteneurs, RAM 20 %, disque 52 %, Kopia OK, pas d'ORDRES.md).

## 🆕 Dernière session — 2026-09-18 (5e partie)
- **PR #4 + PR #1 fusionnées sur `construction-site-tracker`** (par l'utilisateur, après désactivation ponctuelle du ruleset) : `main` contient désormais le projet Android Capacitor (signé, keystore hors repo) + la maj auto des dépendances. ⚠️ pendant la manip, le ruleset avait perdu ses règles « 1 review requise » et « suppression » → **restaurées le jour même via l'API** (ancien ruleset supprimé + recréé avec les 3 règles : non_fast_forward, deletion, pull_request 1 review — id 23667839 ; le PATCH sur l'ancien ruleset renvoyait 404 malgré Administration write → contournement delete+recrée).
- **PAT GitHub roté (terminé côté VPS)** : nouveau token fine-grained généré par l'utilisateur → collé dans n8n « Push GitHub » → propagation SQL (jamais affiché) vers « GitHub — descriptions auto » (3 occurrences) et « Agent Telegram » (1 occ.) ; `n8n_workflow` redémarré pour purger le cache RAM ; test réel OK (push webhook « git-ops-journal », note `docs/rotation-pat-2026-09-18.md`). ✅ **Ancien token révoqué par l'utilisateur le jour même — rotation close.**
- ✅ Keystores des 2 apps sauvegardés hors VPS par l'utilisateur.
- **Lecteur-PDF v1.0.1 créée (versionCode 2)** : bump de version uniquement (aucun changement fonctionnel), build signé avec le keystore dédié (apksigner + jarsigner vérifiés), commit poussé + **release GitHub v1.0.1** avec AAB+APK — destinée à la piste **Tests fermés** de la Play Console (la v1.0.0 reste sur les tests internes).
- Piège SQL noté : `->>` a la même priorité que `||` en PG 17 → toujours parenthéser `(n->>'name')` dans une concaténation.
## 🆕 Dernière session — 2026-09-18 (4e partie)
- **Contrôle santé vert + point DNS réglé** : `fichiers.rennesdev.fr` **résout désormais** (proxy orange Cloudflare, HTTPS 200) — le record A a été créé côté Cloudflare. Cert Let's Encrypt **émis le 18/09 11:35 UTC** (expire 17/12, renouvellement auto). File Browser opérationnel via le navigateur.
- **Analyse disque (39 → 37 Go après nettoyage)** : la hausse venait du store images **containerd** (16 Go, Docker l'utilise désormais) + volumes 8,9 Go (modèles ollama ~6,5 Go, bases PG) — rien d'anormal. Nettoyages faits : image n8n dangling supprimée (245 Mo), `apt clean`. Reste 51 % utilisé, RAS.
- **APT : 4 paquets netplan en attente = phasing Ubuntu** (diffusion progressive, pas une panne) — rien à forcer, ils viendront avec les mises à jour normales.

## 🆕 Dernière session — 2026-09-18
- **Rapport RAM complet (ordres Telegram)** : le « 80 % » vu ce matin = pic **prévisible** — qwen2.5:7b (4,7 Go en RAM) chargé 2× (Agent Telegram 07h00 + descriptions auto 07h45 Paris), rapport 08h00 passé pendant le keep_alive 30 min. Au repos : 1,5/7,6 GiB (~20 %), swap 785 Mo = résidu passif, RAS. Repartition : n8n 424 Mo, Netdata 326 Mo, ollama 108 Mo (déchargé), umami ~150 Mo, système ~300 Mo.
- **Analyse critique ollama** : pour (coût 0, données locales) / contre (7b = ~60 % RAM seul, inférence CPU lente, risque OOM si pic croisé). Sécurité Docker OK (127.0.0.1 uniquement, conteneur isolé). **3 options proposées, aucune appliquée** (en attente utilisateur) : (a) garder tel quel, (b) basculer l'usage quotidien sur qwen2.5:3b (pic ~45 %), (c) réduire keep_alive 30 → 10 min.
## 🆕 Dernière session — 2026-09-18 (3e partie)
- **Interface web d'accès aux fichiers créée (ordre utilisateur)** : conteneur **File Browser** (`filebrowser/filebrowser:v2`, `~/filebrowser/docker-compose.yml`, port 127.0.0.1:8085, scope `/home/ubuntu` lecture+écriture — téléchargement ET upload via le navigateur, pas de FTP exposé). Utilisateur `emmanuel` créé (mot de passe fort généré, credentials `/etc/caddy/filebrowser-auth.txt` root 600, login JWT testé en réel). Vhost Caddy **fichiers.rennesdev.fr** ajouté (import secure_headers → reverse_proxy 127.0.0.1:8085), config validée + reload OK. ⚠️ Reste utilisateur : **créer le record DNS A `fichiers.rennesdev.fr`** chez Cloudflare — proxy orange = IP masquée mais upload limité à 100 Mo (plan Cloudflare gratuit) ; nuage gris (DNS only) = gros fichiers sans limite mais IP visible. Cert Let's Encrypt émis automatiquement par Caddy dès que le DNS pointe.
## 🆕 Dernière session — 2026-09-18 (2e partie)
- **Nouvelle app « Lecteur PDF » créée pour Play Store (ordre utilisateur)** : copie de travail `~/projects/lecteur-pdf` — WebView Capacitor **8.5.2** + **PDF.js 4 embarqué** (`www/pdfjs/`, aucun CDN → 100 % hors ligne), zoom 7 niveaux, mode sombre mémorisé, **aucune permission Android** (ni réseau ni stockage — le file chooser du WebView suffit), package `fr.rennesdev.lecteurpdf`, versionCode 1 / 1.0.0. **Pièges** : Capacitor 8 exige Java 21 → `openjdk-21-jdk-headless` installé + `org.gradle.java.home` dans `gradle.properties` ; keytool sans `-keypass` = keypass = storepass (credentials corrigés en conséquence). Keystore dédié `~/keystores/lecteur-pdf-release.keystore` (RSA 4096, 30 ans) + `lecteur-pdf-credentials.txt` (600, HORS repo), `android/keystore.properties` gitigné. **Build OK** : AAB 3,4 Mo + APK 3,5 Mo signés (apksigner vérifié), AGP 8.13 / Gradle 8.14.3 (plus récents que suivi-interventions). Repo privé **`Lecteur-PDF`** créé via webhook « Push GitHub » (création auto si absent) + commit main poussé. **Release GitHub v1.0.0** créée avec AAB+APK. Guides `README.md` + `PLAY-STORE.md` (package à saisir exactement `fr.rennesdev.lecteurpdf` à la création de l'app). Reste utilisateur : Play Console (créer l'app, upload AAB en tests internes, fiche store, captures), et sauvegarder le keystore hors VPS.
- ⚠️ **PAT GitHub affiché par erreur dans la session 18/09** (extraction DB mal maîtrisée lors du rapport RAM — sortie de requête non filtrée). Aucun push sur disque, mais rotation recommandée à la prochaine occasion (l'utilisateur colle le nouveau dans « Push GitHub », l'assistant le propage aux autres nœuds).
- **Restructuration du journal (ordre utilisateur 18/09)** : ETAT-VPS.md jugé trop long → les sessions 14-17/09 déplacées dans l'archive, et le savoir par sujet isolé dans **4 skills** chargés seulement quand le sujet sort : `github-ops` (PAT, push webhook, workflows GitHub, radar cadence), `n8n-ops` (base, pièges workflow_history/connections, cron, Airtable), `stripe-ops` (webhook paiement + signature `whsec_`), `tally-ops` (webhooks formulaires + signature `tly-`). ETAT-VPS.md garde : infra, services, timers, backups, préférences, en attente.
- **Règle notée (ordre 10h14)** : se demander à chaque workflow si un agent LLM est nécessaire — mécanique = pas d'agent (deps/push/backups corrects), compréhension de texte = agent (Agent Telegram correct).
- **✅ Choix utilisateur (18/09)** : `OLLAMA_KEEP_ALIVE` réduit 30 → 10 min (`~/ollama/docker-compose.yml`, conteneur recréé, env vérifiée, API 200) — le modèle se décharge plus vite après les crons du matin. Le reste (modèle 7b, timers) gardé tel quel.
## Infrastructure
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7.6 Go RAM, 72 Go disque (~37 Go utilisés, 51 % — dont containerd 16 Go images + volumes docker 8,9 Go)
- IPv4 : 162.19.246.165 — IPv6 : 2001:41d0:701:1100::208c — hostname Tailscale : `vps-5532a57a` (100.75.226.13)
- DNS chez **Cloudflare** (proxy orange, Full strict, Always Use HTTPS)

## Services & stacks
| Élément | Détail |
|---|---|
| Frontal | **Caddy** (80/443, certs ACME auto, expirent 2026-12-10, renouvellement auto) — `/etc/caddy/Caddyfile` |
| Umami | `umami_app` (127.0.0.1:3000) + `umami_db` (PG 16) — stack `~/umami/`, creds `~/umami/.credentials.txt` |
| n8n | **v2.39.8** (maj 20/09) — `n8n_workflow` (127.0.0.1:5678) + `n8n_db` (**PostgreSQL 17**) — `~/docker-compose.yml`, mdp dans `~/.env` (`N8N_DB_PASSWORD`) |
| Ollama | `ollama` (127.0.0.1:11434), réseau Docker `apps` — modèles : `qwen2.5:7b` (bot IA), `llama3.2:3b`, `qwen2.5:3b`. `OLLAMA_KEEP_ALIVE=10m` (réduit de 30 min le 18/09, choix utilisateur) |
| Netdata | `netdata`, UI **127.0.0.1:19999** + **https://netdata.rennesdev.fr** (basic auth, credentials `/etc/caddy/netdata-auth.txt` root 600) — `~/netdata/docker-compose.yml` |
| File Browser | `filebrowser`, UI **127.0.0.1:8085** + **https://fichiers.rennesdev.fr** (auth JWT intégrée, credentials `/etc/caddy/filebrowser-auth.txt` root 600, scope `/home/ubuntu`) — `~/filebrowser/docker-compose.yml` |
| Nav.rennesdev | `nav_rennesdev` (`node:22-alpine`, zéro dep) — **https://nav.rennesdev.fr** (basic auth, credentials `/etc/caddy/nav-auth.txt` root 600) → 127.0.0.1:8086 — `~/projects/Nav.rennesdev/docker-compose.yml` (repo GitHub `Nav.rennesdev`) — navigateur léger mode lecture, v2 = assistant IA |
| Uptime-Kuma | `uptime_kuma` (`louislam/uptime-kuma:1`, mem_limit 512 m) — **https://uptime.rennesdev.fr** (basic auth + login Kuma, credentials `/etc/caddy/uptime-auth.txt` root 600) → 127.0.0.1:3001 — 8 moniteurs + notification Telegram — volume `kuma_data` |
| Browserless | `browserless` (`ghcr.io/browserless/chromium`, mem_limit 1500 m, shm 512 m) — Chromium headless piloté par API (scraping JS, PDF, screenshots) — 127.0.0.1:3100 ; usage n8n : `http://browserless:3000?token=` (`BROWSERLESS_TOKEN` dans `~/.env`) |
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
| `github-weekly` | vendredi 19:00 | rapport hebdo GitHub → repo `git-ops-journal` + Telegram |
| `vps-daily-journal` | tous les jours 23:00 | journal quotidien du VPS → repo `VPS-Rennesdev.fr` + Telegram |

## Backups (Kopia)
- Chaîne : `vps-backup.timer` → `kopia-backup.sh` (staging = dump umami + pg_dump n8n + configs, puis snapshots : `/var/lib/docker/volumes`, `/home/ubuntu`, `/etc/caddy`) → **dépôt Kopia sur le PC Windows** (`super-pc-vert`, 100.118.76.30, port 51515, TLS cert RSA fixe, fingerprint `46d81925…`).
- À la demande : `/backup` Telegram → `vps-backup-on-demand.sh` (démarre le serveur Kopia du PC via SSH si besoin, clé `/root/.ssh/id_ed25519_pc`).
- Restauration : `kopia restore` (testée sur dumps). Certificat PC valable jusqu'en 2036.

## Tailscale
- VPS `vps-5532a57a` = 100.75.226.13 ↔ PC `super-pc-vert` = 100.118.76.30 (connexion directe, ~20 ms).

## 🧠 PRÉFÉRENCES UTILISATEUR (mémoire permanente)
9. **Pas d'alerte Telegram pour les situations normales** : PC éteint = pas d'alerte Kopia (le rapport 08:00 suffit comme info). Une alerte = quelque chose à faire.
11. **Règle GitHub (ordre 19/09)** : tout nouveau projet = **son propre repo** (jamais un sous-dossier d'un repo existant) **et naît avec son README** (ordre 19/09) ; toute amélioration d'un projet = **nouvelle branche** dédiée dans le repo du projet ; toutes les améliorations = **commits commentés**.
1. **Canal d'alerte = Telegram** : bot `@Vosmanubot` (Bot-vps), chat `TG_CHAT_ID=8634051625`, config `/etc/vps-watchdog-telegram.env` (root 600). JAMAIS de token dans un fichier commité ou ce journal.
2. **Chaque nouveau workflow/création → repo GitHub avec README** : `github.com/Ruaudel-Emmanuel/rennesdev-vps-ops` (privé, local : `~/projects/rennesdev-vps-ops`). **Push sans PAT en session** : webhook n8n `POST https://n8n.rennesdev.fr/webhook/github-push` — PAT extrait de la base n8n (`n8n_db`, table `workflow_entity`, workflow « Push GitHub ») directement en variable shell du curl, jamais affiché ni sur disque. Voir `docs/push-github.md`.
3. Heures des timers : **Europe/Paris** (le serveur est en UTC).
4. L'utilisateur est sur **Windows 11** (`super-pc-vert`) — manipulations PC = pas-à-pas clairs.
5. **Aucun secret côté assistant** ; secrets → fichiers root-only sur le VPS.
6. **Au début de CHAQUE session : lire `/home/ubuntu/ORDRES.md`** (ordres via bot `@Vosmanubot`, message libre = ordre), les traiter, marquer ✅. `/ordres` liste, `/ok` vide.
7. **Maintenance du journal** : `ETAT-VPS.md` = état courant + dernière session ; le 1er de chaque mois → déplacer les entrées datées du mois écoulé dans `ETAT-VPS-archive-<AAAA-MM>.md` puis pusher les deux sur GitHub. Skill `vps-sante` (`~/.agents/skills/vps-sante/`) = procédure standard de contrôle de santé. **Par sujet → skills dédiés** (chargés seulement quand le sujet sort) : `github-ops`, `n8n-ops`, `stripe-ops`, `tally-ops` (`~/.agents/skills/`).
8. **Rapport quotidien 08:00 Paris** sur Telegram (`vps-metrics-report.timer`) — vérifier dans le contrôle santé qu'il est actif.
10. **Airtable forfait gratuit = 1 000 appels API/mois** (partagés entre les workflows) : tout workflow Airtable doit être économe — appels groupés (formule OR, batch records), cache staticData des listes, fréquence limitée, pause auto sur 429. Se référer au design des workflows « Diffusion » (16/09).

## ⏳ En attente (actions utilisateur)
> ℹ️ Pourquoi « hors VPS » : ce n'est pas que le PC est plus sûr — c'est de la redondance (le VPS = point de défaillance unique ; sans keystore, l'app est figée à jamais sur le Play Store). La copie existe déjà via le snapshot Kopia hebdo de `/home/ubuntu` vers le PC — l'enjeu est de vérifier qu'un restore fonctionne.
- **lecteur-pdf : Play Console** — créer l'app « Lecteur PDF » (⚠️ package = `fr.rennesdev.lecteurpdf`), upload AAB v1.0.0 en Tests internes, fiche store + captures, déclaration « aucune donnée ». Guide : `PLAY-STORE.md` du repo `Lecteur-PDF`.
- ✅ 2026-09-20 : record DNS A `uptime.rennesdev.fr` créé (proxy orange) — cert LE émis, HTTPS 200, 8 moniteurs + notification Telegram actifs.
- ✅ 2026-09-19 : record DNS A `nav.rennesdev.fr` créé (proxy orange) — cert LE émis, HTTPS 200, navigation testée. **Nav.rennesdev v1 terminée.**
- ✅ 2026-09-18 : record DNS A `fichiers.rennesdev.fr` créé (proxy orange, cert LE émis, HTTPS 200).
- ✅ 2026-09-18 : **2 keystores sauvegardés hors VPS** (l'utilisateur).
- ✅ 2026-09-18 : **PAT GitHub roté et déployé partout, ancien token révoqué** — rotation close.
- **Play Console (bloqué sur le test fermé, 2026-09-19)** : 2 apps créées (brouillon + tests internes), questionnaires (classification du contenu, cible et contenu) et fiches Play Store **remplis**, icônes et illustrations générées via Google AI Studio, uploads AAB en tests internes, **11 testeurs**. ⚠️ **Compte « Particulier » confirmé (profil validé 01/07/2026) → test fermé obligatoire : ≥ 20 testeurs optés en continu pendant 14 jours** avant production. Reste utilisateur : créer la piste « Test fermé » par app (AAB déjà validé), recruter 9-10 testeurs de plus (≥ 20, opt-in + installation réelle), tenir 14 jours (les 2 apps en parallèle avec les mêmes testeurs), puis « Demander l'accès à la production ».
- ✅ 2026-09-18 : **PR #2 (recréée en #4) fusionnée** — projet Android Capacitor sur `main` de `construction-site-tracker` (avec la PR deps #1).
- **construction-site-tracker : Play Console** — créer l'app, upload de l'AAB (release v1.0.0) en Tests internes, laisser « Google gère la clé de signature de l'app » (Play App Signing), complétérer fiche store + déclaration données. Guide pas-à-pas : `PLAY-STORE.md` dans le repo.
- ✅ 2026-09-18 : **keystore suivi-interventions sauvegardé hors VPS** (couvert par la ligne keystores ci-dessus).
- ✅ 2026-09-17 : points GitHub précédents tous traités (ancien token révoqué, issue fermée, PR relues, Tally photographe OK, PAT roté, dépôts confirmés) — validé par l'utilisateur.

## 🔎 Vérifications rapides utiles
```bash
bash ~/.agents/skills/vps-sante/scripts/vps-sante.sh   # contrôle complet (exit 0 = vert)
docker ps                                              # 7 conteneurs attendus (dont filebrowser)
curl -s -o /dev/null -w '%{http_code}' https://n8n.rennesdev.fr   # 200
sudo fail2ban-client status sshd
docker exec ollama ollama list
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:19999     # 200 (netdata)
systemctl list-timers github-weekly.timer --no-pager             # vendredi 19h00 Paris
systemctl list-timers vps-daily-journal.timer --no-pager         # tous les jours 23h00 Paris
```

## Notes
- 💡 **Idée SPECTRE en réserve (pas de mise en projet)** : suite naturelle d'**ÉCLAIREUR (déployé le 19/09, option a)** — navigateur headless dans un conteneur Docker (Playwright) qui rend la page (y compris le JavaScript) puis extrait le texte, pour les pages qui sont des apps JS. Plus lourd (RAM/CPU) qu'ÉCLAIREUR (HTTP GET + extraction statique). Basculer sur SPECTRE uniquement si les pages ciblées le nécessitent. (c) à terme éventuellement : agent navigateur plus complet (hors périmètre VPS actuel). Contraintes inchangées : RAM, taille de contexte, respect des sites (lecture publique seule, pas de contournement paywall/anti-bot).
- Historique détaillé (crises résolues, installations, debugging) : `ETAT-VPS-archive-2026-09.md`.
- Docs ops + workflows + scripts versionnés : `~/projects/rennesdev-vps-ops/` (= repo GitHub).
- Skill de contrôle santé : `~/.agents/skills/vps-sante/` (copié dans le repo GitHub).
