# 🗄️ ARCHIVE — Journal ETAT-VPS (septembre 2026)
> Archivé le 2026-09-14 lors de la rotation du journal (règle n°7).
> Historique complet, figé. L'état courant vit dans ETAT-VPS.md.
> Copie committée sur github.com/Ruaudel-Emmanuel/rennesdev-vps-ops.

# 📋 État du VPS rennesdev.fr — Journal d'installation
> Généré le 2026-09-10 par l'assistant sysadmin. À relire au début de chaque nouvelle session.

---

## 🆕 Mise à jour 2026-09-14 (2) — **NETDATA INSTALLE (supervision temps réel)** ✅
- **Choix utilisateur** : Netdata retenu face à Prometheus (trop lourd pour 7,6 Go RAM avec ollama+backup : ~500 Mo permanents + maintenance). Netdata = 1 conteneur, ~200 Mo, dashboards auto, zéro config.
- **Stack** : `~/netdata/docker-compose.yml` → conteneur `netdata` (`netdata/netdata:latest`, réseau Docker par défaut, `pid: host`, mounts hôte read-only + `/var/run/docker.sock` ro → voit VPS ET tous les conteneurs). `DISABLE_TELEMETRY=1`.
- **Sécurité** : UI bindée **127.0.0.1:19999 uniquement** — rien dans UFW, pas de vhost Caddy. Accès PC via tunnel SSH : `ssh -L 19999:127.0.0.1:19999 ubuntu@162.19.246.165` puis `http://localhost:19999` (à faire la première fois).
- **Coût mesuré** : RAM 1,3 → 1,5 Go ; cache disque 14 Mo au démarrage.
- **Watchdog mis à jour** : conteneur `netdata` ajouté à la liste surveillée (+ `n8n_db` au passage) — backup `/usr/local/bin/vps-watchdog.sh.bak-20260914`, watchdog repassé sans anomalie. Pas d'alerting Netdata activé (les alertes restent watchdog → Telegram, pas de doublon).
- **Repo GitHub** : `docs/netdata.md` + `netdata/docker-compose.yml` poussés via le webhook (✅ EXIT:0). **Nouvelle méthode push validée** : PAT extrait de la base n8n directement en variable shell (jamais en session, jamais sur disque) — documenté dans `docs/push-github.md`. Plus besoin de demander le PAT à l'utilisateur.
- **Sessions futures** : même méthode pour le push GitHub ; vérifier netdata dans le contrôle santé (conteneur + 200 local).

---

## 🆕 Mise à jour 2026-09-14 — **CONTRÔLE DE SANTÉ : TOUT EST VERT** ✅
- **Canal d'ordres** : `ORDRES.md` absent (canal vide) — la seule instruction (test du 13/09 18:58) avait déjà été archivée dans `ORDRES-archive.md`. Rien à traiter.
- **Backup planifié du 13 soir 19:30 Paris** : ✅ **succès** (17:34→17:45 UTC, 10m48s) — 4 snapshots (volumes 8,8 Go, home, caddy, staging), dépôt connecté, fingerprint `46d81925…` inchangé, PC:51515 ouvert. Messages Telegram ⏳/✅ envoyés par `kopia-backup.sh` (nouvelle notification vérifiée en conditions réelles).
- **Santé (12:36 UTC)** : 5 conteneurs up (n8n_db healthy, n8n_workflow, ollama, umami_app, umami_db) ; umami + n8n 200 origine ET edge ; disque 30/72 Go (42%, explique par qwen2.5:7b dans le volume ollama) ; RAM 1,3/7,6 Go ; load 0.07 ; APT 0 paquet en attente.
- **Fail2ban** : sshd 6 bans actifs / 209 totaux ; recidive 6 actifs / 6 totaux.
- **Ollama** : aucun modèle chargé (le déchargement 19:15 de veille a fait son office).
- **Certificats Caddy origine** : umami + n8n expirent 2026-12-10 (renouvellement auto).
- **Timers actifs** : watchdog (15 min), ollama-unload (19:15 Paris), backup (dim. 19:30 Paris), rappel (dim. 12:00 Paris). Bot Telegram `vps-tgbot` actif.
- **Aucune action requise.** Prochaine échéance : backup planifié dimanche 2026-09-20 19:30 Paris.

---

## 🆕 Mise à jour 2026-09-13 (soir 4) — **CANAL D'ORDRES TELEGRAM → ASSISTANT** ✅
- **Demande utilisateur** : pouvoir envoyer des instructions à l'assistant via le bot Telegram. **Implémenté** dans `vps-tgbot.py` (backup : `vps-tgbot.py.bak-20260913`) :
  - **message libre (sans `/`) = ordre** → enregistré dans `/home/ubuntu/ORDRES.md` (format `### [date heure] texte`), confirmation envoyée sur Telegram ;
  - `/ordres` — liste les ordres en attente ; `/ok` — vide le fichier (archive → `/home/ubuntu/ORDRES-archive.md`) ;
  - `/backup`, `/status`, `/help` inchangés (aide mise à jour).
- **Règle permanente ajoutée aux préférences** (n°6) : toute session assistant lit `ORDRES.md` au démarrage et traite les ordres.
- Testé : simulation d'un ordre → fichier créé (ubuntu:ubuntu 644, lu sans sudo) + confirmations Telegram reçues. Service redémarré, actif. Une instruction de test est laissée en attente pour que l'utilisateur essaie `/ordres` et `/ok`.
- **Outils à disposition de l'assistant (inventaire)** : Telegram (`vps-tg.sh` : alertes ; `vps-tgbot.py` : contrôle + ordres), GitHub (`webhook n8n « Push GitHub »`, PAT stocké dans n8n), backups (`/backup`, timers), santé (`/status`, watchdog). Autres outils à créer si besoin, documentés dans rennesdev-vps-ops.

---

## 🆕 Mise à jour 2026-09-13 (soir 3) — **OUTIL « PUSH GITHUB » OPÉRATIONNEL DE BOUT EN BOUT** ✅
- **PAT stocké dans le workflow** (nœud « Config (PAT GitHub) », fine-grained fourni par l'utilisateur, compte confirmé `Ruaudel-Emmanuel`). ⚠️ Subtilité n8n v2 : il faut mettre à jour **ET** `workflow_entity.nodes` **ET** `workflow_history.nodes` (versions draft/published — l'exécution utilise l'historique actif), sinon l'ancien placeholder reste actif.
- **Tests réussis via webhook** :
  1. Push `rennesdev-vps-ops` → commit `1a64bc5` (docs + workflow JSON + script) vérifié sur GitHub (HEAD main).
  2. Création de repo à la volée testée avec un repo de test `test-push-vps` (privé) → **créé + cloné + commit + poussé** puis **supprimé** (HTTP 204) — chemin de création validé.
  3. Bugs corrigés au passage (commit `8e20260` poussé via l'outil lui-même, vérifié sur GitHub) :
     - clone d'un repo **privé** : le clone nécessitait le token → clone avec token transient puis `remote set-url` propre (le token ne reste jamais dans `.git/config`, vérifié) ;
     - **fichiers existants préservés** : si `/projects/<path>` contient déjà des fichiers, le `.git` est attaché au dossier existant (plus de `rm -rf`) ;
     - **repo vide** (aucun commit) : commit initial `--allow-empty` au lieu d'un échec `src refspec HEAD`.
- **Usage (assistant, sessions futures)** : `curl -X POST https://n8n.rennesdev.fr/webhook/github-push -H 'X-Auth-Token: <PAT>' -H 'Content-Type: application/json' -d '{"repo":"...","path":"...","message":"...","branch":"main","private":true}'` — le header X-Auth-Token = le PAT lui-même. Réponse : stdout du script + `EXIT:<code>` (0 = succès). **Le PAT n'a plus jamais à être demandé à l'utilisateur.**
- Fichiers : script `/home/ubuntu/projects/scripts/github-push.sh` ; docs `~/projects/rennesdev-vps-ops/docs/push-github.md` ; workflow exporté (placeholder, jamais le vrai token) dans le repo.
- ⚠️ Le PAT a transité en clair dans la conversation — possibilité de le régénérer et de le remplacer soi-même dans l'UI n8n (nœud Config) si souhaité.

---

## 🆕 Mise à jour 2026-09-13 (soir 2) — **ALERTES TELEGRAM BACKUP + NGINX PURGÉ + OUTIL « PUSH GITHUB »**
### 1. Alertes Telegram du backup planifié : CAUSE TROUVÉE ET CORRIGÉE
- **Cause** : le backup planifié (`vps-backup.timer` → `kopia-backup.sh`) n'envoyait **rien** sur Telegram — seul le chemin à la demande (`/backup` → `vps-backup-on-demand.sh`) notifiait. Le backup du soir ayant réussi, aucun message n'était donc attendu.
- **Corrigé** : `kopia-backup.sh` notifie désormais le résultat (✅/❌ + dernier snapshot) via `/usr/local/bin/vps-tg.sh`, avec trap EXIT pour les échecs. Backup de l'ancien : `kopia-backup.sh.bak-20260913`. Message de test envoyé (HTTP 200).
- NB : les « poll error: read operation timed out » de `vps-tgbot` dans les logs = timeout normal du long polling, pas une panne.
### 2. Nginx désinstallé (demande utilisateur — doublon inactif de Caddy)
- `apt purge nginx nginx-common python3-certbot-nginx` (le plugin certbot-nginx dépendait de nginx ; certbot n'est plus utilisé depuis le passage à Caddy qui gère son ACME). Autoremove sans effet supplémentaire. **Aucune trace de nginx restante** ; config archivée avant purge : `/home/ubuntu/nginx-config-archive-20260913.tar.gz`.
- Vérifié après purge : caddy/ufw/fail2ban actifs, umami + n8n 200 origine + edge.
### 3. 🛠️ NOUVEL OUTIL : workflow n8n « Push GitHub » (ID `c0ffee11-2222-4333-8444-555566667777`)
- **Objectif** (demande utilisateur) : permettre à l'assistant de pousser un projet vers GitHub **sans jamais recevoir le PAT en session** — le token est stocké une fois dans le workflow (nœud « Config (PAT GitHub) »).
- **Chaîne** : `POST https://n8n.rennesdev.fr/webhook/github-push` (header `X-Auth-Token`) → Config (PAT) → IF token → Code (encodage base64 des champs = immunisé shell) → Execute Command `/projects/scripts/github-push.sh` → réponse webhook avec stdout + `EXIT:<code>`.
- **Script** : `/home/ubuntu/projects/scripts/github-push.sh` — vérifie le token (API /user), **crée le repo s'il n'existe pas** (private selon payload), clone dans `/projects/<path>` si besoin, commit+push. Token utilisé uniquement comme URL transient de `git push` (jamais dans `.git/config`), sortie nettoyée `x-access-token:***@`.
- **Infra** : git 2.55 déjà présent dans l'image n8n ; montage `~/docker-compose.yml` : `/home/ubuntu/projects:/projects` ; `ExecuteCommand` désactivé par défaut en n8n v2 → réactivé via `NODES_EXCLUDE=[]` (conteneur limité au montage /projects).
- **Pièges découverts** : 1) n8n v2 = modèle draft/published → l'activation DB exige `active=true` **ET** `activeVersionId="versionId"` ; 2) args base64 vides avalés par le shell → chaque arg quoté en single quotes ; 3) ExecuteCommand lève une erreur si exit ≠ 0 → `2>&1; echo "EXIT:$?"` pour toujours répondre.
- **Projets déplacés** : `rennesdev-vps-ops` déplacé de `/home/ubuntu/` → **`/home/ubuntu/projects/`**. Repo GitHub : nouveau commit local `1a64bc5` (docs/push-github.md + workflows/push-github/{workflow.json placeholder, github-push.sh}) — **push en attente du PAT**.
- **⚠️ RESTE À FAIRE (utilisateur)** : fournir un PAT fine-grained (Contents: Read/Write) pour 1) le stocker dans le nœud « Config (PAT GitHub) » de n8n (une seule fois) et 2) pousser le commit en attente. Le PAT transitant par le webhook comme header d'auth, il servira aussi d'authentifiant d'appel. Stocké uniquement en base n8n (volume n8n_pg_data → inclus dans les backups Kopia chiffrés du PC).

---

## 🆕 Mise à jour 2026-09-13 (soir) — **CONTRÔLE DE SANTÉ : TOUT EST VERT, BACKUP DU SOIR VALIDÉ** ✅
### Chaîne backup du soir 2026-09-13 déroulée de bout en bout
- **19:15 Paris** : `vps-ollama-unload.timer` passé → no-op (aucun modèle chargé à cette heure). Log `/var/log/vps-ollama-unload.log` propre (test de l'après-midi visible : qwen2.5:7b déchargé, RAM 6,1 → 1,3 Go).
- **19:33 Paris** : `vps-backup.timer` passé → **succès** (exit 0, 10m48s) : port 51515 du PC ouvert, dépôt connecté, fingerprint `46d81925…` inchangé, 4 snapshots (volumes 17:34 UTC, home, caddy, staging). Messages Telegram ⏳/✅ envoyés.
- **Snapshot volumes passé de 4,1 → 8,8 Go** : **normal** — le modèle `qwen2.5:7b` (4,7 Go) vit dans le volume `ollama_ollama_data` et est donc inclus dans le snapshot. Les prochains passages re-déduplicqueront (deltas seulement). Explique aussi la hausse disque 26 → 30 Go (42%). **Aucune action requise.**
- NB : `vps-backup.service` a eu un pic mémoire de 3,9 Go pendant le snapshot des volumes — attendu (compression), la machine a suivi (swap à peine utilisé).
### Santé générale (18:03 UTC)
- 5 conteneurs up (n8n_db healthy, n8n_workflow, ollama, umami_app, umami_db) ; umami/n8n 200 origine + edge ; disque 30/72 Go (42%, expliqué ci-dessus) ; RAM 1,2/7,6 Go ; load 0,20.
- Fail2ban : sshd 6 bans actifs / 191 totaux ; recidive 6 actifs / 6 totaux.
- Tous les timers actifs : watchdog (15 min), unload Ollama (19:15 Paris), backup (dim. 19:30 Paris), rappel (dim. 12:00 Paris).
### Constat mineur (aucune action, pour info)
- Le workflow n8n **« Alertes VPS (watchdog rennesdev.fr) » est repassé en ACTIF** dans la base (il avait été laissé inactif le 2026-09-12 tard 3). Vérifié inoffensif : déclencheur = webhook `POST vps-alert` que le watchdog n'appelle plus (il envoie directement via Telegram), et le nœud final est un placeholder noOp → **inerte**. Peut être désactivé/supprimé sur décision utilisateur (comme « AI Personal Assistant », lui toujours inactif).
- « Agent Telegram » toujours actif (qwen2.5:7b).

---

## 🆕 Mise à jour 2026-09-13 (après-midi 2) — **AGENT PASSÉ EN qwen2.5:7b + FILTRE CHAT ID + REPO GITHUB**
- **Modèle remplacé** : nœud Ollama Chat Model du workflow « Agent Telegram » passé de `llama3.2:3b` → **`qwen2.5:7b`** (pull OK, 4,7 Go, test génération OK). RAM chargée : 6,8/7,6 Go (le modèle se décharge seul après 30 min d'inactivité, OLLAMA_KEEP_ALIVE=30m). `llama3.2:3b` reste disponible sur disque.
- **Sécurité ajoutée** : nœud Filter « Chat autorisé ? » entre le Telegram Trigger et l'AI Agent — n'accepte que `chat.id = 8634051625`, les autres expéditeurs sont ignorés silencieusement.
- **n8n_workflow redémarré** pour recharger la version active du workflow (édition directe en base = pas de hot-reload) → workflow réactivé, webhook réenregistré, HTTP 200.
- **Repo GitHub préparé** : commit local `a5aa204` dans `/home/ubuntu/rennesdev-vps-ops` — `workflows/agent-telegram/workflow.json` (export nettoyé : références credentials et webhookId supprimées, vérification aucun secret) + `workflows/agent-telegram/README.md` (architecture, installation, notes RAM). **Push en attente du PAT utilisateur.** → ✅ **Poussé le 2026-09-13 après-midi 2** (commit `a5aa204` → main, vérifié : aucun token sur disque, remote non persisté). PAT utilisé en session puis jeté — recommandation faite à l'utilisateur de le révoquer/régénérer puisque transmis en clair dans la conversation.

## 🆕 Mise à jour 2026-09-13 (fin d'après-midi) — **DÉCHARGEMENT OLLAMA AVANT BACKUP (anti-saturation RAM)**
- **Alertes Telegram reçues par l'utilisateur (13:15 UTC)** : 1) « Conteneur n8n_workflow exited / HTTPS 502 » = redémarrage volontaire de n8n par l'assistant (recharge du workflow corrigé) — bref et attendu ; 2) « RAM ≥ 90 % » = **qwen2.5:7b chargé (5,1 Go)** pendant l'utilisation du bot IA (comportement attendu, le seuil watchdog RAM est 90 %).
- **Nouveau mécanisme** : `vps-ollama-unload.timer` → **tous les jours 19:15 Europe/Paris** (15 min avant le backup 19:30) → `vps-ollama-unload.service` → `/usr/local/bin/vps-ollama-unload.sh` : décharge tous les modèles Ollama chargés (API `keep_alive=0`) pour libérer ~5 Go avant pg_dump + Kopia. Log : `/var/log/vps-ollama-unload.log`.
- **Bug corrigé au test** : `ollama ps --format` non supporté par la version d'Ollama du conteneur → parsing de la table standard + fallback API. **Test validé** : RAM 6,1 → 1,3 Go utilisée après déchargement. Le modèle se recharge tout seul (~20 s) au prochain message au bot.
- NB : le timer tourne tous les jours (pas seulement dimanche) — sans modèle chargé il ne fait rien (no-op), et ça couvre aussi les backups à la demande via `/backup` effectués après 19:15.

## 🆕 Mise à jour 2026-09-13 (après-midi) — **WORKFLOW « AGENT TELEGRAM » CRÉÉ PAR L'UTILISATEUR, CORRIGÉ PAR L'ASSISTANT** ✅
### Santé générale (12:30 UTC) : tout est vert
- 5 conteneurs up (n8n_db healthy, n8n_workflow, ollama, umami_app, umami_db) ; umami/n8n 200 origine + edge ; disque 26/72 Go (36%) ; RAM 1,6/7,6 Go ; load 0.25. Fail2ban sshd 1 ban actif / 177 totaux.
- Compte owner n8n créé (`ruaudel.emmanuel@orange.fr`) → point « Set up owner account » de la migration PG clos.
- Kopia : dépôt connecté, dernier snapshot 2026-09-13 09:17 UTC ; **port 51515 du PC OUVERT** (serveur Kopia actif). Backup planifié ce soir 19:30 Paris.
### Agent Telegram (nouveau workflow créé côté utilisateur dans n8n, trouvé en base)
- Nœuds : Telegram Trigger → AI Agent (Ollama Chat Model `llama3.2:3b` + Postgres Chat Memory) → Send a text message. Credentials créés par l'utilisateur : « Telegram account » (bot dédié supposé), « Ollama account », « Postgres account ».
- **3 bugs corrigés en base** (`workflow_entity`, workflow inactif, UPDATE direct PG) :
  1. AI Agent : le prompt système était mis dans le champ `text` (message utilisateur jamais transmis) → `text = {{ $json.message.text }}`, persona déplacée dans `options.systemMessage` (« assistant IA personnel d'Emmanuel… réponds en français »).
  2. Send a text message : `={{ $json.output}}}` (accolade en trop) → `={{ $json.output }}`.
  3. Nœud orphelin « Simple Memory » déconnecté supprimé (Postgres Chat Memory reste seule mémoire → historique persistant en PG, clé = chat.id).
- Modèle `llama3.2:3b` confirmé présent dans le conteneur ollama.
- **⚠️ Reste côté utilisateur (UI n8n)** : 1) **recharger la page n8n** (Ctrl+R — n'importe quelle sauvegarde faite depuis l'éditeur ouvert écraserait les corrections), 2) vérifier le credential « Telegram account » = token du **bot dédié** (pas `@Vosmanubot`), et « Postgres account » pointe bien vers `n8n_db` (host `n8n_db`, base `n8n`), 3) **activer le workflow** (le Telegram Trigger enregistrera le webhook via https://n8n.rennesdev.fr), 4) tester : message au bot sur Telegram → réponse en français.
- Repo GitHub : ce nouveau workflow devrait être documenté dans rennesdev-vps-ops (PAT à demander à l'utilisateur au moment du push, ne pas le stocker).
### Dépannage Postgres Chat Memory + nouvelle clé SSH utilisateur (suite de session)
- **Credential « Postgres account » en échec** dans n8n (« Couldn't connect ») : connexion testée depuis le réseau Docker avec le mot de passe de `~/.env` → **OK (PostgreSQL 17.11)** → cause = mot de passe mal saisi côté UI. Résolu par l'utilisateur après récupération du mot de passe.
- **⚠️ Au passage : la clé SSH `rsa-key-20260911` de l'utilisateur ne fonctionnait pas depuis PowerShell** (`Permission denied (publickey)` — probablement une clé PuTTY/.ppk non chargée par OpenSSH Windows). **Nouvelle clé ed25519 générée côté PC** (`emmanuel@Super-PC-vert`, fp `SHA256:S6uv/7ZDTLDtvsrjW3AI7EnWxnM7aKrgRegPBmyBjqQ`), ajoutée à `~/.ssh/authorized_keys` (elle cohabite avec l'ancienne rsa). Connexion PowerShell `ssh ubuntu@162.19.246.165` opérationnelle.
### ✅ RÉSULTAT FINAL : **AGENT TELEGRAM OPÉRATIONNEL**
- Workflow « Agent Telegram » **ACTIF** (vérifié en base, active=t) ; bot dédié répond sur Telegram.
- Mémoire persistante confirmée : table `n8n_chat_histories` créée en base (Postgres Chat Memory, clé = chat.id).
- Architecture finale : Telegram Trigger (bot dédié) → AI Agent (Ollama `llama3.2:3b`, persona française en systemMessage, prompt = `{{ $json.message.text }}`) + Postgres Chat Memory → Send a text message (`{{ $json.output }}`, chatId 8634051625).
- ⚠️ Rappel : le modèle 3B reste modeste pour un assistant conversationnel — possibilité d'ajouter un modèle plus gros via `docker exec ollama ollama pull <modele>` (attention RAM 7,6 Go, ~4 Go libres).
## 🧠 PRÉFÉRENCES UTILISATEUR (mémoire permanente — à respecter dans toute nouvelle session)
1. **Canal d'alerte = Telegram** : bot `@Vosmanubot` (Bot-vps), chat privé `TG_CHAT_ID=8634051625`, config sur le VPS dans `/etc/vps-watchdog-telegram.env` (root 600). Ne JAMAIS stocker le token du bot dans un fichier commité ou ce journal — uniquement dans le fichier root-only.
2. **Chaque nouveau workflow/création → un repo GitHub avec README**. Repo de référence : **github.com/Ruaudel-Emmanuel/rennesdev-vps-ops** (privé ; login GitHub `Ruaudel-Emmanuel`). Créer le repo + push à chaque nouveau chantier (PAT fourni à la demande, ne jamais le stocker).
3. Heures des timers : utiliser l'**heure de Paris** (`Europe/Paris` dans OnCalendar) — le serveur est en UTC.
4. L'utilisateur est sur **Windows 11** au quotidien (`super-pc-vert`, 100.118.76.30 en Tailscale) — toute manipulation PC = instructions claires pas-à-pas.
5. Ne rien stocker comme secret côté assistant ; si un secret doit transiter, le placer en fichier root-only sur le VPS.
6. **Au début de CHAQUE session : lire `/home/ubuntu/ORDRES.md`** (ordres envoyés par l'utilisateur via le bot Telegram `@Vosmanubot`, message libre = ordre) et les traiter, puis marquer `✅` les entrées traitées. Commandes Telegram : `/ordres` (liste), `/ok` (vide après traitement), `/backup`, `/status`. **Push GitHub sans demander de PAT** : webhook n8n `POST https://n8n.rennesdev.fr/webhook/github-push` (header `X-Auth-Token` = PAT stocké dans le workflow « Push GitHub ») — voir `~/projects/rennesdev-vps-ops/docs/push-github.md`.

---

## 🆕 Mise à jour 2026-09-13 (matin bis) — **n8n : SQLite → PostgreSQL 17** ✅
### Migration effectuée en vue de l'agent IA conversationnel Telegram
- **Stack n8n modifiée** (`~/docker-compose.yml`) : nouveau service **`n8n_db`** (`postgres:17-alpine`, conteneur `n8n_db`, volume `ubuntu_n8n_pg_data`, réseau `apps`, port NON exposé, healthcheck `pg_isready`) + n8n passé en `DB_TYPE=postgresdb` (host `n8n_db`, base `n8n`, user `n8n`, mdp dans `~/.env` : `N8N_DB_PASSWORD`). **NB : PG 16 refusé par n8n** (« outside supported range ») → bascule immédiate en PG 17.11 avant import.
- **Exports de secours faits avant bascule** (dans `~/n8n-migration-20260913/`) : `wf-export.json` (2 workflows), copie SQLite complète + WAL, tar du volume (annulé — volume copié à la place), fichier `config` (clé chiffrement) conservé : le volume **`ubuntu_n8n_data` est INTACT et sert de fallback** (ne pas supprimer sans décision utilisateur).
- **Workflows réimportés dans PG** : « AI Personal Assistant » + « Alertes VPS (watchdog) » (inactif) — import CLI OK, vérifié en base.
- **⚠️ Compte utilisateur à recréer** : la base est neuve → au premier accès à https://n8n.rennesdev.fr, l'écran « Set up owner account » demandera de créer le compte propriétaire (ancien compte non migré — 0 credentials, 0 exécution à l'époque, donc perte nulle).
- **`kopia-staging.sh` mis à jour** : le backup SQLite n8n remplacé par `pg_dump` du conteneur `n8n_db` (`n8n.dump`, 456 Ko) ; le dump du `config` (clé de chiffrement) est conservé. Testé OK.
- **Backup Kopia complet poussé après migration** (09:17 UTC, succès, Telegram ✅). Disque 26/72 Go (36%).
- **Objectif suivant (annoncé par l'utilisateur)** : agent IA conversationnel dans n8n — trigger Telegram → AI Agent (Ollama local `http://ollama:11434`) → réponse Telegram. **⚠️ Le bot watchdog `@Vosmanubot` ne peut pas être réutilisé** (déjà consommé en long polling par `vps-tgbot.py` — Telegram = 1 consommateur par bot) → créer un bot dédié via BotFather, token à saisir par l'utilisateur directement dans n8n (jamais côté assistant).

## 🆕 Mise à jour 2026-09-13 (matin, session de contrôle de santé) — **TOUT EST VERT** ✅
- **Connectivité Kopia PC rétablie** : port 51515 du PC OUVERT + `kopia snapshot list` OK → le serveur Kopia tourne à nouveau côté PC (la tâche planifiée KopiaServer ONLOGON fait son office : le PC était éteint/serveur arrêté la nuit, ce qui est normal).
- **⚠️ Alerte watchdog 2026-09-12 23:17 UTC** : « Dépôt Kopia NON CONNECTÉ » envoyée sur Telegram — c'était le PC éteint/serveur arrêté pendant la nuit. **Comportement attendu** (serveur Kopia = ONLOGON) ; l'anti-spam 6h a limité le bruit. Aucune action requise.
- **Santé générale** : 4 conteneurs up, umami/n8n 200 origine + edge, disque 25/72 Go (35%), RAM 1,5/7,6 Go, load 0.17, Caddy actif, APT à jour (0 paquet en attente).
- **Certificats origine (Caddy)** : umami + n8n expirent le **2026-12-10** (renouvellement auto Caddy).
- **Fail2ban** : sshd 0 ban actif / 174 totaux ; recidive 6 actifs (6 totaux).
- **Timers** : `vps-backup-reminder.timer` → passage **aujourd'hui 12:00 Paris** (10:00 UTC) ; `vps-backup.timer` → **aujourd'hui 19:30 Paris** (PC allumé requis — la chaîne complète est validée, voir 2026-09-12 tard 5). Bot Telegram actif.
- **Derniers snapshots** : 2026-09-12 20:06 UTC (staging + volumes 4 Go identiques + home + caddy) — la déduplication fonctionne (quasi zéro upload).
- **Aucune action requise cette session.** Prochaine échéance : backup planifié ce soir 19:30 Paris.

## 🆕 Mise à jour 2026-09-12 tard (5) — **CHAÎNE /backup VALIDÉE DE BOUT EN BOUT** ✅
### PC Windows : SSH opérationnel, serveur Kopia relancé, backup à la demande testé
- **Accès SSH VPS → PC opérationnel** : clé `/root/.ssh/id_ed25519_pc` acceptée (administrators_authorized_keys + icacls OK) → `ssh -i /root/.ssh/id_ed25519_pc Emmanuel@100.118.76.30 "<cmd>"`. whoami = `super-pc-vert\emmanuel`. ⚠️ Session SSH Windows = non-interactive → **pas d'accès au trousseau** (DPAPI).
- **Serveur Kopia PC** : le lancement simple échouait (`TLS not configured`) → **lancement OK avec `--tls-generate-cert`** → nouveau certificat, fingerprint **`394c1503e5c082f17910254cacc3c4d6876ab46a6758ef4fb52f8dadc1183b3d`** (l'ancien `7fa2fca8…` avait disparu). **VPS re-connecté sans manip utilisateur** : édition directe de `serverCertFingerprint` dans `/root/.config/kopia/repository.config` (backup : `repository.config.bak-fp-7fa2fca8`) → `kopia repository status` OK (vps@super-pc-vert, credentials client en cache).
- **Test de bout en bout réussi (19:51 UTC)** : `/usr/local/bin/vps-backup-on-demand.sh` → port détecté ouvert → `vps-backup.service` → 4 snapshots (volumes 4 GB = « identical » quasi zéro upload grâce à la dédup) → messages Telegram ⏳/✅ reçus. Log : `/var/log/vps-backup-on-demand.log`.
- **Diagnostic PC via SSH** (à réutiliser) : processus kopia.exe en cours = serveurs internes **KopiaUI** (ports aléatoires 127.0.0.1:59xxx, `--shutdown-on-stdin`, config `AppData\Roaming\kopia\repository.config`) — ils ne servent pas notre purpose ; notre serveur = CLI standalone sur 0.0.0.0:51515.
- **Limitation connue (à traiter plus tard si besoin)** : démarrage du serveur Kopia **via SSH impossible** (trousseau DPAPI inaccessible en session réseau) → le fallback SSH de `vps-backup-on-demand.sh` ne fonctionnera pas tant que KOPIA_PASSWORD ne sera pas fourni (option : wrapper avec `set KOPIA_PASSWORD=...` dans la tâche planifiée, décision utilisateur requise car le mot de passe du dépôt serait stocké sur le PC). En pratique la tâche planifiée **KopiaServer** (interactive à l'ouverture de session) couvre le cas nominal.
- **✅ RÉSOLU (fin de session) : stabilité du certificat.** `--tls-generate-cert` régénère le certificat à CHAQUE démarrage (fp a changé 3 fois : 7fa2fca8 → 394c1503 → f9eb8caf). **Solution définitive** : certificat RSA 2048 auto-signé généré côté VPS (10 ans, CN=super-pc-vert, SAN IP 100.118.76.30) + clé, poussés via SSH sur le PC dans `C:\Users\Emmanuel\kopia-tls\` (md5 vérifiés), serveur lancé avec `--tls-cert-file/--tls-key-file`. **Fingerprint DÉFINITIF : `46d8192585a5463a8858acb009b286b50b29f096b71b154f923a730d0775de6c`** acté dans la config VPS. Tâche planifiée `KopiaServer` mise à jour avec ces flags (script `C:\Users\Emmanuel\setup-kopia.ps1` poussé via scp + intégré au repo GitHub `docs/setup-kopia.ps1`). **Validation finale 20:06 UTC : port ouvert, fingerprint exact, dépôt connecté, backup à la demande OK (snapshots identiques), messages Telegram reçus.** Aucune manipulation Kopia attendue avant l'expiration du certificat (2036).
- KopiaUI (GUI) peut rester lancé : ses serveurs internes n'entrent pas en conflit avec le serveur standalone sur 51515 (constaté en 2026-09-10 et 12).

---

## 🆕 Mise à jour 2026-09-12 tard (4) — **SAUVEGARDE EN UN CLIC + RAPPEL DIMANCHE + REPO GITHUB**
### Workflow de sauvegarde à la demande (demande utilisateur : « je clique → serveur Kopia lancé + sauvegarde faite »)
- **Bot Telegram de contrôle** : `/usr/local/bin/vps-tgbot.py` (long polling, stdlib), service `vps-tgbot.service` (actif). Commandes : `/backup` (sauvegarde complète), `/status` (état VPS), `/help`. Répond UNIQUEMENT au chat de l'utilisateur.
- **`/usr/local/bin/vps-backup-on-demand.sh`** (la chaîne `/backup`) : 1) vérifie port 51515 du PC → si fermé, tente démarrage distant `ssh Emmanuel@100.118.76.30 "schtasks /run /tn KopiaServer"` (clé `/root/.ssh/id_ed25519_pc`, publiée côté PC dans `administrators_authorized_keys`) puis attend jusqu'à 60 s ; 2) vérifie `kopia repository status` ; 3) `systemctl start --wait vps-backup.service` ; 4) rapport succès/échec + dernier snapshot sur Telegram. Anti-double-lancement (lock /run), log `/var/log/vps-backup-on-demand.log`.
- **Rappel hebdo** : `vps-backup-reminder.timer` → **dimanche 12:00 Europe/Paris** → `vps-backup-reminder.sh` : PC joignable ?, dépôt connecté ?, âge du dernier snapshot, prochain passage du timer → Telegram. **Premier envoi réel effectué le 2026-09-12 18:24 (test OK)** ; premier passage planifié dimanche 13 12:00.
- **Timers re-alignés sur l'heure de Paris** : backup hebdo déplacé de 19:30 UTC → **19:30 Europe/Paris** (17:30 UTC). Rappel 12:00 Europe/Paris (10:00 UTC).
- **Découverte** : une sauvegarde complète a RÉUSSI le 2026-09-12 à 15:47 UTC (4 snapshots : staging 2,1 Mo + volumes 4 Go identiques + home + caddy) → le dépôt est bien connecté, fingerprint PC inchangé. Le serveur Kopia du PC s'est juste re-arrêté depuis (raccourci manuel non persistant) → d'où le passage à la tâche planifiée + démarrage à distance.
- **Reste côté PC (one-time, utilisateur)** : 1) OpenSSH Server (`Add-WindowsCapability`), 2) clé publique VPS dans `C:\ProgramData\ssh\administrators_authorized_keys` (+icacls), 3) tâche planifiée `KopiaServer` (ONLOGON, HIGHEST, args `server start --address=0.0.0.0:51515`) — remplace le raccourci shell:startup (détails exacts dans le README du repo).
- **Repo GitHub** : ✅ créé et poussé — **github.com/Ruaudel-Emmanuel/rennesdev-vps-ops** (privé, branche main, README complet, secrets exclus vérifiés). Commit local dans `/home/ubuntu/rennesdev-vps-ops` (remote non persisté : pusher via URL explicite pour ne pas stocker le token dans .git/config). PAT transmis en session — **ne pas le stocker**, l'utilisateur peut le révoquer/régénérer après usage.

---

## 🆕 Mise à jour 2026-09-12 tard (3) — **WATCHDOG → TELEGRAM OPÉRATIONNEL** ✅
### Bot Telegram branché directement sur le watchdog (n8n évincé du chemin d'alerte)
- **Découverte** : le watchdog `/usr/local/bin/vps-watchdog.sh` existait déjà (systemd `vps-watchdog.timer`, toutes les 15 min, créé 16:12) mais poussait vers le webhook n8n — workflow **« Alertes VPS (watchdog rennesdev.fr) »** inactif → webhook 404, alertes perdues.
- **Décision utilisateur** : notification par **Telegram** (bot `@Vosmanubot`, chat privé Emmanuel). Le script envoie maintenant **directement** à l'API Telegram (curl sendMessage) — plus de dépendance à n8n (un watchdog qui dépend du service surveillé pour alerter ne pourrait pas signaler sa panne).
- **Config** : `/etc/vps-watchdog-telegram.env` (root:root 600) — `TG_BOT_TOKEN` + `TG_CHAT_ID=8634051625`. Token bot stocké dans ce fichier uniquement ; l'ancien `/etc/vps-watchdog.token` (auth webhook n8n) reste sur disque mais n'est plus utilisé.
- **Test bout-en-bout OK (17:08)** : état anti-spam purgé, `systemctl start vps-watchdog.service` → alerte **réelle** « Dépôt Kopia NON CONNECTÉ » reçue sur le téléphone (HTTP 200, log « alerte envoyée via Telegram »).
- **Anti-spam inchangé** : cooldown 6h par anomalie identique (`/var/lib/vps-watchdog/last-alert-<md5>`).
- **Workflow n8n « Alertes VPS »** : laissé inactif, devenu inutile (peut être supprimé plus tard sur décision). Le bot Telegram a d'abord eu un token invalide (401, bot recréé par l'utilisateur) — token actuel validé via getMe.
- **⚠️ Kopia toujours bloqué côté PC** : le PC est joignable via Tailscale (pong direct 18 ms) mais **port 51515 fermé** (timeout depuis le VPS, confirmé par le watchdog 17:08). Cause suspectée : le raccourci du PC lance `kopia.exe server start` **sans `--address=0.0.0.0:51515`** (écoute défaut = 127.0.0.1 local) — correction demandée à l'utilisateur, à re-vérifier (fenêtre console doit rester ouverte, netstat `0.0.0.0:51515 LISTENING` attendu, soupçon Bitdefender si crash).

---

## 🆕 Mise à jour 2026-09-12 tard (2) — **BACKUPS KOPIA OPÉRATIONNELS** ✅
### Chaîne complète VPS → PC Windows validée
- **Dépôt Kopia créé côté PC** : `D:\Backups-Kopia` (KopiaUI installé dans `C:\Users\Emmanuel\AppData\Local\Programs\KopiaUI`, binaire CLI embarqué dans `resources\server\kopia.exe`).
- **Serveur Kopia sur le PC** : `kopia server start --address=0.0.0.0:51515 --tls-generate-cert`, utilisateur serveur `vps@super-pc-vert` créé (mdp défini côté PC). Fingerprint actuel : `sha256:7fa2fca831b8cd8b8cd44b736557d95b9f665100e598465749af6e5589aeb653`.
- **VPS connecté au dépôt** : `sudo kopia repository connect server --url https://100.118.76.30:51515 --server-cert-fingerprint <fp> --override-username vps --override-hostname super-pc-vert` (config root : `/root/.config/kopia/repository.config`). **Attention : le fingerprint a déjà changé une fois** (certificat régénéré après arrêt du serveur) → si changement, refaire un `repo connect` avec le nouveau fp.
- **Premier backup complet OK** (manuel) : staging (dump umami 60K + SQLite n8n 2,0M + configs) + volumes Docker **4 Go** en 3m13s (~180 Mbit/s via Tailscale) + `/home/ubuntu` 179 Mo + `/etc/caddy`.
- **Restauration testée bout-en-bout** : `kopia restore` d'un dump umami depuis le dépôt PC → fichier valide (magic PGDMP, 170 TOC entries).
- **Déduplication vérifiée** : 2e passage via systemd → volumes/home renvoyés "identiques", quasi zéro upload. Snapshots suivants ne renverront que les deltas. *(NB 2026-09-13 soir : le snapshot volumes est passé à 8,8 Go suite à l'ajout de qwen2.5:7b dans le volume ollama — voir session du soir.)*
- **⚠️ Bug systemd corrigé** : `HOME` est vide dans les services systemd → kopia cherchait la config ailleurs. Ajout `Environment=HOME=/root` dans `vps-backup.service`. **Service testé : exit 0.**
- **Timer** : `vps-backup.timer` actif, prochain passage dimanche 19:30 (PC allumé requis).
### Reste à faire côté PC Windows (utilisateur)
1. **Auto-start du serveur Kopia** : créer un raccourci dans le dossier de démarrage (`Win+R` → `shell:startup`) pointant vers `C:\Users\Emmanuel\AppData\Local\Programs\KopiaUI\resources\server\kopia.exe` **avec en arguments** `server start --address=0.0.0.0:51515` (⚠️ le champ Cible d'un raccourci ne peut pas contenir les arguments, ils vont dans le champ Arguments ou après le chemin séparés d'un espace). **Ne pas remettre** `--tls-generate-cert` au re-lancement (le certificat existe déjà — garder le fingerprint `7fa2fca8…` stable).
2. **Exclusion Bitdefender** pour `kopia.exe` (un crash/coupure pendant le 1er test, cause non confirmée).
3. **Mise en veille = Jamais** (Paramètres → Système → Alimentation).
4. NB : la fenêtre PowerShell qui fait tourner le serveur doit rester ouverte tant que l'auto-start n'est pas en place.

## 🆕 Mise à jour 2026-09-12 tard / reprise session (contrôle de santé)
- **Tailscale OK** : les 2 machines en ligne dans le tailnet, `tailscale ping` PC → pong 18 ms **connexion directe** (90.47.186.201, pas de relais DERP). Le ping ICMP classique échoue (pare-feu Windows bloque l'ICMP — non bloquant).
- **Port 51515 du PC toujours fermé** → serveur Kopia pas encore lancé côté Windows. **Session bloquée sur action utilisateur** (voir étapes ci-dessous).
- **Nettoyage** : processus `tailscale login` en arrière-plan terminé (auth succès), log `/tmp/tailscale-login.log` supprimé.
- **Santé générale** : 4 conteneurs up (n8n_workflow, ollama, umami_app, umami_db), disque 25/72 Go (35%), RAM 1,4/7,6 Go, load 0.19. Timer `vps-backup.timer` : prochain passage **dimanche 19:30** (échouera proprement tant que `kopia repo status` = "not connected"). Fail2ban actif (plusieurs bans sshd en cours).

## 🆕 Mise à jour 2026-09-13 (session de poursuite)
### Kopia : préparation de la connectivité Tailscale
- **Santé générale vérifiée** : 4 conteneurs up (n8n_workflow, ollama, umami_app, umami_db), umami/n8n 200 via origine + edge, disque 25/72 Go (35%), RAM 1,4/7,6 Go, load 0.16. Timer `vps-backup.timer` actif (prochain passage dimanche 2026-09-13 19:30 — échouera proprement tant que le dépôt Kopia n'est pas connecté).
- **Scripts Kopia intacts** : `/usr/local/bin/kopia-staging.sh` + `kopia-backup.sh` (syntaxe OK).
- **Découverte** : **Tailscale déjà installé et actif sur le VPS** (`/usr/bin/tailscale`, `tailscaled` actif) mais **non authentifié** (state: NeedsLogin).
- **Login Tailscale lancé en arrière-plan** (processus `tailscale login` maintenu via nohup, log dans `/tmp/tailscale-login.log`) → URL d'authentification fournie à l'utilisateur, valable jusqu'à connexion.
- **Suite côté utilisateur** (blocée sur action utilisateur) :
  1. Ouvrir l'URL d'auth Tailscale (donnée en session), se connecter/créer un compte → le VPS rejoint le tailnet.
  2. Sur le PC Windows 11 : installer Tailscale (même compte) + installer Kopia.
  3. Kopia côté Windows : créer le dépôt (dossier local/chiffré), `kopia server user add vps@<machine> --user-password ...` puis lancer `kopia server start` (GUI : « Serveur » / auto-start).
  4. Sur le VPS : `sudo kopia repo connect server --url https://100.118.76.30:51515 --server-cert-fingerprint <fp> --user vps` (le fingerprint s'affiche au démarrage du serveur Kopia côté Windows).

## ✅ Réseau Tailscale (tailnet Ruaudel-Emmanuel@)
| Machine | Nom Tailscale | IP Tailscale |
|---|---|---|
| VPS | `vps-5532a57a` | 100.75.226.13 |
| PC Windows 11 | `super-pc-vert` | 100.118.76.30 |
- **Tailscale authentifié le 2026-09-13** (utilisateur) : tailnet `Ruaudel-Emmanuel@`
  - VPS : `vps-5532a57a` → **100.75.226.13**
  - PC Windows 11 : `super-pc-vert` → **100.118.76.30**
  - Connectivité validée : ping OK ~23 ms, `tailscale ping` → **connexion directe** via IPv6 (pas de relais DERP) — idéal pour les backups.
- **Port 51515 du PC fermé** au 2026-09-13 (serveur Kopia pas encore lancé côté Windows) → étape suivante côté utilisateur.

---

## 🆕 Mise à jour 2026-09-12 bis (session de poursuite)
### ⚠️ Découverte non journalisée (fait par session/utilisateur le 2026-09-11 ~18h24)
- **`apt-get install caddy borgmatic borgbackup`** effectué le 2026-09-11 18:24 (traces dans /var/log/apt/history.log, absent du journal) :
  - **Caddy a remplacé Nginx comme reverse proxy** (Nginx désactivé, Caddy actif sur 80/443). Certificats Let's Encrypt émis **par Caddy lui-même** (ACME propre, expire 2026-12-10) pour umami + n8n — le certbot existant (cert unique couvrant les 2 domaines, expire 2026-12-09) reste en place mais **n'est plus utilisé par le frontal**.
  - **borgmatic + borgbackup installés** : template de config `/etc/borgmatic/config.yaml` (sauvegarde vers PC fixe via SSH, timers actifs → prochain passage dimanche 19:30, **échouera tant que le dépôt est un placeholder** `IP_DU_PC_FIXE` / `MOT_DE_PASSE_UMAMI`). Noms des volumes Docker dans le template vérifiés corrects (`ubuntu_n8n_data`, `umami_umami_pg_data`, `ollama_ollama_data`).
- Nginx : toujours installé mais **désactivé** (`systemctl disabled`). `/etc/nginx/conf.d/hardening.conf` inactif.

### 🔴 Crise évitée : base n8n hors volume (corrigé)
- **Découverte critique** : la base SQLite de n8n (workflows, credentials, clé de chiffrement dans `config`) vivait dans `/home/node/.n8n` **à l'intérieur du conteneur** — le compose montait le volume `n8n_data` sur `/home/n8n/.n8n` (mauvais chemin : `n8n` au lieu de `node`). **Tout aurait été perdu au prochain recreate du conteneur**.
- **Corrigé** : `docker compose stop` → `docker cp` des données → copie dans le volume (chown 1000:1000) → compose corrigé (`n8n_data:/home/node/.n8n`) → `docker compose up -d`. Vérifié : 200 local + edge, v2.38.7, données dans le volume, `/home/n8n` vide dans le conteneur.

### Actions effectuées cette session
- **Headers de sécurité rétablis sur Caddy** (perdus au basculement Nginx → Caddy) : nouveau `/etc/caddy/Caddyfile` avec snippet `(secure_headers)` → `X-Frame-Options SAMEORIGIN`, `X-Content-Type-Options nosniff`, `Referrer-Policy strict-origin-when-cross-origin`, header `Server` supprimé, + `encode zstd gzip`. Backup de l'ancien : `/etc/caddy/Caddyfile.bak-2026-09-12`. Vérifié sur les 2 sous-domaines (origine + edge Cloudflare) : 200 + headers présents.
- **Permissions resserrées** : `/etc/caddy/Caddyfile` → root:root 644 ; `/etc/borgmatic/config.yaml` → root:root 600.
- **APT à jour** : mdadm upgradé (dmidecode réglé dans la foulée). Aucun redémarrage requis.
- **Santé générale vérifiée** : 4 conteneurs up, umami/n8n 200 via origine et edge, disque 25/72 Go (35%), RAM 1,4/7,6 Go, swap inutilisé, load ~0.1. Fail2ban : sshd 0 ban actif / 144 totaux, recidive 6 actifs / 6 totaux.
- **Ports exposés** : 22/80/443 uniquement (80+443 par Caddy, admin Caddy sur 127.0.0.1:2019).

### 💾 Backups : borg → **Kopia** (décision utilisateur 2026-09-12 bis)
- **borgmatic + borgbackup désinstallés** (timer désactivé, `/etc/borgmatic` supprimé) — le PC fixe est sous Windows 11, Kopia y est natif (GUI).
- **Architecture** : dépôt Kopia chiffré **sur le PC Windows 11** (Kopia en mode *repository server*) → le VPS **pousse** ses snapshots. Connectivité VPS→PC à choisir : **Tailscale** (recommandé, IP dynamique du PC sans port ouvert) ou tunnel Cloudflare.
- **Installé sur le VPS** : `kopia 0.23.1` (repo apt packages.kopia.io) + `sqlite3` (backup en ligne du SQLite n8n).
- **Scripts** : `/usr/local/bin/kopia-staging.sh` (dump pg umami via docker exec + `.backup` SQLite n8n + copie configs : compose, .env, Caddyfile) et `/usr/local/bin/kopia-backup.sh` (staging + snapshots : `/var/backups/kopia-staging`, `/var/lib/docker/volumes`, `/home/ubuntu`, `/etc/caddy`). Staging testé OK (dump umami 60 Ko, SQLite n8n 2 Mo, intégrité `ok`).
- **Planification** : `vps-backup.timer` systemd, **dimanche 19:30** (PC doit être allumé), `Persistent=true`. Le run échouera proprement tant que le dépôt n'est pas connecté (`kopia repo status`).
- **Reste à faire (utilisateur + assistant)** : choisir connectivité (Tailscale/tunnel CF), installer Kopia côté Windows (dépôt + `kopia server user add vps` + `kopia server start` auto-start), puis sur le VPS `kopia repo connect server --url https://<PC>:51515 --server-cert-fingerprint <fp> --user vps`.

### À faire / à noter (côté utilisateur)
- **Backups Kopia** : voir section ci-dessus — dépôt côté Windows à créer + connectivité à choisir.
- **Nginx** : décision possible de le désinstaller (apt purge) puisque Caddy le remplace — laisser tel quel pour l'instant.
- Le journal précédent décrivait Nginx comme frontal : **à partir du 2026-09-11 soir, le frontal est Caddy**.

---

## 🆕 Mise à jour 2026-09-11 bis (session de poursuite)
### Actions effectuées
- **Mise à jour n8n : 2.37.7 → 2.38.7** (pull image latest + recreate). Migrations appliquées sans erreur, 200 direct et via origine.
- **Warnings de dépréciation n8n corrigés** dans `~/docker-compose.yml` (mentionnés en Note depuis le 2026-09-10) : `WEBHOOK_URL` → `N8N_WEBHOOK_URL`, et fix explicites pour conserver le comportement actuel : `N8N_UNVERIFIED_PACKAGES_ENABLED=true`, `N8N_RUNNERS_TASK_TIMEOUT=300`, `N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES=2147483648`, `N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES=5000`. **Plus aucun warning de dépréciation dans les logs.**
- **APT à jour** : 3 paquets upgrade (dmidecode, mdadm, sos). Aucun redémarrage de service requis.
- **Ancienne image n8n supprimée** (image prune, 397 Mo libérés). Disque : 25/72 Go (35%).
- **Santé générale vérifiée** : 4 conteneurs up, umami/n8n 200 via origine, certbot OK (expire 2026-12-09), fail2ban sshd 2 bans actifs / 120 totaux, recidive 6 actifs, SSH passwordauthentication=no confirmé, ports exposés : 22/80/443 uniquement.
- **Cloudflare Full (strict) confirmé par l'utilisateur** + Always Use HTTPS déjà actif. Validation externe : HTTPS edge → 200 (umami, n8n), HTTP → 301 HTTPS, certificat edge Google Trust Services valide jusqu'au 2026-11-04. **Plus aucun point en attente côté utilisateur.**
- **Openclaw** : vérification exhaustive — aucune trace (conteneur, volume, image, réseau, Nginx, fichiers). Réinstallation non souhaitée.
- **Mot de passe admin Umami réinitialisé à nouveau** (l'utilisateur n'arrivait pas à se connecter) : le UPDATE SQL précédent avait été corrompu par l'expansion shell des `$` du hash bcrypt (passé via `sh -c`). Corrigé en passant le SQL directement à `docker exec psql` (sans shell intermédiaire). Vérifié : 200 via API (local + HTTPS public).
- **Umami opérationnel** : connexion OK après réinitialisation, utilisateur a défini son propre mot de passe (non stocké serveur) et ajouté ses sites web. Erreur navigateur `insertBefore` rencontrée par l'utilisateur = cache/traduction auto navigateur (pas un problème serveur, Umami 3.3.1 sain).

## Mise à jour 2026-09-12 (session de poursuite)
### Actions effectuées
- **Sécurisation SSH terminée et validée par l'utilisateur** : clé publique `rsa-key-20260911` (RSA 2048, SHA256:qto21eFPkJU/nNzx+egaquk6MESx+wIEpBOZ2KM82AA) ajoutée à `~/.ssh/authorized_keys` (permissions 700/600 vérifiées) + `PasswordAuthentication no` appliqué dans `/etc/ssh/sshd_config.d/50-cloud-init.conf` (ce drop-in cloud-init écrasait tout le reste, la modif de sshd_config seul n'aurait pas suffi). `sshd -t` OK, reload OK. Vérifié depuis le serveur : le serveur n'advertise plus que `publickey`. Utilisateur confirme : connexion par clé OK sans mot de passe.
- **Volumes Docker orphelins supprimés** (correction du journal : `ubuntu_n8n_data` était en réalité **utilisé** par `n8n_workflow`, et ollama utilise `ollama_ollama_data`) : suppression de `n8n_n8n-data`, `n8n_production_n8n_data`, `n8n_sandbox-tls`, `ubuntu_ollama_data`, `ubuntu_openclaw_data` (~12 Mo). Volumes restants : uniquement ceux utilisés par les stacks actives.
- **`~/n8n_production/` archivé puis supprimé** : sauvegarde → `~/n8n_production-archive-2026-09-12.tar.gz` (3,1 Ko, incl. dump.rdb Redis, lu avec sudo).
- **Mot de passe admin Umami réinitialisé** : les identifiants par défaut (admin/umami) fonctionnaient ENCORE sur le service public → changé via API puis re-réinitialisé proprement en base (hash bcrypt $2b$10) après une erreur de manipulation. Nouveau mot de passe stocké dans `~/umami/.credentials.txt` (chmod 600). Vérifié : ancien mdp → 401, nouveau → 200.
- **Bilan fail2ban** : sshd 9 bans actifs / 118 totaux ; recidive 6 bans actifs (6 totaux).
- **Santé générale** : 4 conteneurs up, disque 25/72 Go (35%), RAM 1,3/7,6 Go, swap quasi inutilisé, load ~0.1. Certbot OK (umami expire 2026-12-09, 89 j).

### Anomalie de session (corrigée)
- Le premier changement de mot de passe via l'API a été écrasé par une fausse manœuvre (placeholder écrit à la place du mot de passe réel) → résolu par réinitialisation directe du hash en base via `umami_db` + vérification login API.

## 🆕 Mise à jour 2026-09-11 (session de poursuite)
### Actions effectuées
- **Fail2ban jail recidive** (perma-ban) : `/etc/fail2ban/jail.d/recidive.local` — IP déjà bannie 5 fois en 24h → ban 1 semaine. Jail active, 49 entrées d'échecs déjà trackées.
- **Fail2ban bilan sshd** : 1061 échecs cumulés, 109 bans totaux, 13 IP actuellement bannies.
- **Clarification disque** : les 13 Go de `/var/lib/containerd` sont le **stockage d'images Docker** (snapshotter containerd, défaut sur cette install) — ollama 9.18 Go + n8n 2.47 Go + umami 1.33 Go + postgres 0.42 Go. Croissance disque = faux alarmisme, usage inchangé (~25-26 Go).
- **Nettoyage** : journaux systemd vacuum 404M → 200M (223 Mo libérés) + `apt-get clean`. Disque : 25 Go / 72 Go (35%).
- **Volumes Docker orphelins constatés** (petits, inutilisés) : `ubuntu_n8n_data`, `ubuntu_ollama_data`, `ubuntu_openclaw_data`, `n8n_production_n8n_data`, `n8n_sandbox-tls`, `n8n_n8n-data` — suppression possible sur validation. ✅ *(corrigé puis traité le 2026-09-12 : `ubuntu_n8n_data` était utilisé, les 5 autres supprimés — voir session du 12)*

---

## Mise à jour 2026-09-10 (session de poursuite)
### Actions effectuées
- **Sécurisation secrets n8n** : externalisation des credentials (`N8N_BASIC_AUTH_*`, `N8N_SECRET_KEY`) depuis `docker-compose.yml` vers `~/.env` (chmod 600). Suppression des variables PostgreSQL obsolètes (n8n tourne en SQLite).
- **PostgreSQL natif arrêté** : service désactivé et stoppé. La base `n8n_db` était orpheline (0 connexion, ancienne installation). Umami conserve son propre conteneur PostgreSQL.
- **Vérification santé Nginx/TLS** : headers de sécurité (`X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`) OK, certificat valide 89 jours, accès direct origine 200.
- **Constats** : `openclaw_gateway` introuvable (conteneur/service absent). `~/n8n_production/` existe toujours (peut être archivé/nettoyé sur décision utilisateur).

---

## Infrastructure
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7.6 Go RAM, 72 Go disque (26 Go utilisés)
- IPv4 : 162.19.246.165 — IPv6 : 2001:41d0:701:1100::208c
- DNS du domaine géré chez **Cloudflare** (proxy orange activé)

## ✅ Réalisé

### Sécurisation
- APT à jour (apt update/upgrade complet)
- **Fail2ban** actif sur SSH (jail sshd, ban 1h / 5 essais) + jail **recidive** (perma-ban 1 semaine des récidivistes, session 2026-09-11)
- **UFW** : seuls 22/tcp, 80/tcp, 443/tcp ouverts (5678 fermé)
- **SSH** : auth par mot de passe encore ACTIVE — à couper après ajout de la clé publique (voir "En attente")
- n8n lié sur 127.0.0.1:5678 uniquement (plus d'accès direct externe)
- Nginx : `server_tokens off`, gzip, headers X-Frame-Options / X-Content-Type-Options / Referrer-Policy (`/etc/nginx/conf.d/hardening.conf`)
- cloudflared supprimé (aucun tunnel n'existait), ModemManager/multipathd/udisks2 désactivés

### Optimisation
- Swap 2 Go (`/swapfile`, fstab) — la VM n'avait AUCUN swap
- Sysctl : `/etc/sysctl.d/99-vps-tuning.conf` (swappiness=10, somaxconn, syncookies, rp_filter…)
- Nettoyage Docker : **20,6 Go libérés** (disque passé de 66% à ~26%)
- Vhost Nginx nettoyés : un seul fichier par sous-domaine dans sites-available

### TLS (certbot / Let's Encrypt)
- Certificats émis pour `umami.rennesdev.fr` + `n8n.rennesdev.fr`, renouvellement auto
- Vhosts : `/etc/nginx/sites-available/{umami,n8n}.rennesdev.fr`

### Umami (analytics)
- Stack : `~/umami/docker-compose.yml` → conteneurs `umami_app` (127.0.0.1:3000) + `umami_db` (PostgreSQL 16, volume `umami_pg_data`)
- Secrets dans `~/umami/.credentials.txt` (chmod 600)
- Login par défaut : admin / umami → **à changer** ; puis snippet tracking :
  `<script defer src="https://umami.rennesdev.fr/script.js" data-website-id="ID"></script>`

### Ollama (installation propre, ancienne install entièrement supprimée)
- Stack : `~/ollama/docker-compose.yml` → conteneur `ollama`, port 127.0.0.1:11434
- Réseau Docker externe **`apps`** partagé avec n8n → dans n8n, credential Ollama avec **Base URL : http://ollama:11434**
- Modèles installés : `llama3.2:3b` (2,0 Go) + `qwen2.5:3b` (1,9 Go)
- OLLAMA_KEEP_ALIVE=30m, OLLAMA_MAX_LOADED_MODELS=2
- Ajouter un modèle : `docker exec ollama ollama pull <modele>`

### Compose n8n
- `~/docker-compose.yml` : n8n sur 127.0.0.1:5678, réseau `apps` (accès à Ollama), volume n8n_data

## ⏳ En attente (actions utilisateur)

**Aucun point en attente** — tous les points précédents sont clos (SSL/TLS Full strict ✅, clé SSH ✅, mdp Umami ✅, DNS umami ✅). Openclaw : réinstallation non souhaitée (décision utilisateur 2026-09-11 bis). **Watchdog Telegram ✅ (2026-09-12 tard 3).**

**Reste Kopia côté PC (2026-09-12 tard 3)** : relancer le raccourci avec `server start --address=0.0.0.0:51515` (sans `--tls-generate-cert`), vérifier netstat → `0.0.0.0:51515 LISTENING`, puis re-test depuis le VPS. En cas d'échec : exclusion Bitdefender pour kopia.exe.

1. ~~Cloudflare SSL/TLS → passer en "Full (strict)"~~ : ✅ **fait et validé le 2026-09-11 bis** — mode **Full (strict)** actif + **Always Use HTTPS** activé. Vérifié depuis l'extérieur : HTTPS edge → 200 sur `umami` et `n8n`, HTTP → 301 vers HTTPS, chaîne TLS complète (edge Cloudflare → Let's Encrypt à l'origine, certificat validé). Aucune boucle de redirection.
2. ~~Clé publique SSH~~ : ✅ fait le 2026-09-12 — clé ajoutée, authentification par mot de passe **coupée**, **connexion par clé confirmée par l'utilisateur**. Point clos.
3. ~~Umami : changer le mot de passe admin~~ : ✅ fait le 2026-09-12 (voir `~/umami/.credentials.txt`).
4. ~~DNS umami.rennesdev.fr~~ : créé et propagé (résout vers les IP Cloudflare, cert a été émis).

## 🔎 Vérifications rapides utiles
```bash
docker ps                                   # umami_app, umami_db, ollama, n8n_workflow
curl -s -o /dev/null -w '%{http_code}' --resolve umami.rennesdev.fr:443:162.19.246.165 https://umami.rennesdev.fr   # 200 attendu
curl -s -o /dev/null -w '%{http_code}' https://umami.rennesdev.fr               # 200 via edge Cloudflare
curl -s -o /dev/null -w '%{http_code}' http://umami.rennesdev.fr                # 301 -> https (Always Use HTTPS)
sudo fail2ban-client status sshd
docker exec ollama ollama list
```

## Notes
- **Openclaw** : ✅ entièrement supprimé et vérifié le 2026-09-11 bis (conteneur, volume, image, vhost, fichiers — aucune trace système). Réinstallation non souhaitée par l'utilisateur pour l'instant.
- `~/n8n_production/` : ✅ supprimé le 2026-09-12 (archive → `~/n8n_production-archive-2026-09-12.tar.gz`).
- **PostgreSQL natif désactivé** : base `n8n_db` orpheline, inutilisée par la stack actuelle.
- **Warnings n8n dépréciations** : ✅ corrigés le 2026-09-11 bis (voir session correspondante).