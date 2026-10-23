# 📋 État du VPS rennesdev.fr — État courant
> Journal allégé depuis le 2026-09-14 (rotation, règle n°7) : ce fichier décrit l'état **actuel** uniquement.
> Historique complet : `ETAT-VPS-archive-2026-09.md` (et suivants, un par mois) — aussi sur GitHub.
> Rotation : le 1er de chaque mois, les entrées du mois écoulé partent dans une nouvelle archive.

---
## 🆕 Dernière session — 2026-10-01
- **✅ Audio Transcriber testé et finalisé** : app Windows tkinter (capture système → faster-whisper → Ollama qwen2.5-coder:latest → .md). Bug de nommage `qwen2.5-coder:7b` → `qwen2.5-coder:latest` corrigé. Test transcription + résumé validé bout-en-bout.
- **✅ Section Prompt idéal de départ ajoutée au README.md** d'Audio Transcriber (règle 15). Push GitHub fait via webhook.
- **✅ Règle 15 enregistrée** : systématiquement ajouter le prompt idéal dans le README en fin de projet, et demander les contraintes techniques à l'utilisateur au début de chaque projet.

## 🆕 Dernière session — 2026-09-28 (2e partie)

- **🔌 Agent n8n branché sur Ollama local (ordre Telegram « branche l'agent de mon n8n sur le ollama local »)** : le workflow « AI Personal Assistant » (draft inactif jusque-là, assistant rédacteur de messages SMS/Telegram : chatTrigger + agent LangChain + mémoire PG + envoi Telegram) tournait sur **Google Gemini cloud** (`models/gemini-3.7-flash`). **Remplacé par un nœud `lmChatOllama` « Ollama Chat Model » → modèle `qwen2.5:7b` local** (credential `ollamaApi` `JAPrAr0LBw7RVQAY`, copiée d'Agent Telegram), connexion `ai_languageModel` repointée. **Publié + activé** (snapshot neuf + alignement versionId/activeVersionId + outbox → completed, trigger chat webhook enregistré, invariant sain, 0 pending, healthz 200). ℹ️ C'était volontairement un brouillon (l'ETAT 27/09) ; l'utilisateur le destine désormais à être son agent — activation assumée, réversible (mettre inactive ou repasser Gemini).
- **🧠 Préférence enregistrée (règle 14)** : quand l'utilisateur dit « n8n », il faut **passer par cet agent** (AI Personal Assistant, Ollama local qwen2.5:7b).

## 🆕 Dernière session — 2026-09-28

- **✅ Workflow « Diffusion Actus Discord » : post LinkedIn par actu + envoi Telegram (ordre Telegram 28/09)** : le Code node « Diffusion Actus » (RSS Airtable → Discord, inchangé) génère désormais pour **chaque nouvelle actu** un **post LinkedIn en français via Ollama local `qwen2.5:3b`** (prompt : titre accrocheur + corps 3-5 phrases + question ouverte ; `keep_alive: 10m`, `num_ctx 4096`, ~20 s/actu à chaud, nettoyage markdown du titre) puis l'envoie (avec le lien de l'actu) vers un **nouveau nœud Telegram « Telegram — actu LinkedIn »** (credential `telegramApi`, chat Manu `8634051625`). Le nœud Code retourne un item par actu (titre/lien/feed/texte) → envoi Telegram par item. `executionTimeout` porté à **15 min** (10 actus × ~20 s + RSS). Discord, marquage Airtable et cache 12 h inchangés ; les « pas de nouvelle / quota 429 / aucun candidat » retournent `[]` (plus de bruit). Description à jour.
- **🔧 Publication n8n 2.41 (même mécanique 27/09)** : draft + **snapshot neuf `workflow_history`** (nœuds = les nouveaux AVANT le snapshot) + alignement `versionId`/`activeVersionId` + outbox `pending/publish` → restart → **activated trigger, outbox completed**. ⚠️ Pièges notés : le SQL initial cassait sur les `'` du JS (chaîne simple) → **dollar-quoting `$nodesql$…$nodesql$::json` obligatoire** sinon erreur psql + rollback ; générer le JS en Python par chaînes exactes (jamais `re.sub` template : il mord les `\s` et les `${}`) ; `node --check` en enveloppant dans `async function main()` (await top-level = normal en Code node n8n).
- **🧪 Test bout-en-bout réel** : cron temporaire `*/2 * * * *` + **flux Airtable de test `TEST-Pipeline`** (Google News FR ; webhook Discord volontairement invalide pour ne pas spammer le canal) ; **cache de flux 12 h vidé** via `staticData.global` dans `workflow_entity` (donnée runtime, pas de publication). Runs 472/473 → **success ~206-272 s** ; `execution_data` run 473 : sortie Code = items `{titre, lien, feed, texte}` (ex. « Titre : L’Iran nie toute implication… ») et nœud Telegram → `{"ok":true,"result":<message_id>}` ×4+ vers chat `8634051625`. **Feature validée.** Cron remis à `0 9,15,21 * * *`, flux de test supprimé (Airtable DELETE `records[]=` URL-encodé, lots ≤ 10) + **19 articles de test marqués repurgeés**, cache flux revidé.
- ⚠️ La génération (~3-4 min) **dépasse le cron de test 2 min** → superposition des runs (écartée ici par le marquage Airtable) : ne pas poser un cron plus fréquent que la durée d'exécution. Les 4 flux réels n'avaient aucune actu non marquée au moment du test.
- ✅ État final : invariant sain (versionId = activeVersionId = snapshot = published, active, **0 pending / 6 completed** outbox), cron `0 9,15,21 * * *`, 3 nœuds (Horloge → Diffusion Actus étendu → Telegram), IDs valides, healthz 200.

## 🆕 Dernière session — 2026-09-27 (2e partie)

- **✅ Publication des workflows n8n (ordre « publie les workflows qui ne le sont pas »)** : dans n8n **2.41, « publier » = « mettre en production (activer) »** (`POST /workflows/:id/publish` = `activateWorkflow`). Au démarrage suivant la maj, 4 workflows **actifs avant la maj ont été dé-publiés/désactivés par le système de publication** (Codeur, Diffusion Actus, Diffusion Photos, ÉCLAIREUR) : ils n'avaient pas de version publiée (`workflow_published_version`) ni de snapshot référencé par `activeVersionId` → l'applier a pris le chemin `unpublish` (outbox 14:20, résultat `unpublished`), et la **compaction d'historique a purgé leurs snapshots non référencés** (47141bac, 576ab0e7).
- **🔧 Mécanique n8n 2.41 découverte en lisant le code du conteneur** (`dist/workflows/publication/*`) : l'applier publie si `workflow_entity.activeVersionId` ≠ NULL, dé-publie sinon ; `resolveActivationMode` = `activate` quand raison= publish et pas d'ancienne version ; l'invariant des workflows sains = **`versionId` = `activeVersionId` = ligne `workflow_history` = ligne `workflow_published_version`** (le `versionId` de l'entité est la cible d'activation et doit exister dans `workflow_history` — sinon « Version not found ») ; outbox = records `status=pending`/`reason=publish` consommés au boot + polling (`startPolling`).
- **✅ Réparation (14:46-14:49)** : pour les 4 workflows — backup `~/n8n-db-avant-publish-2026-09-27.sql.gz`, création d'un **snapshot neuf** dans `workflow_history` (auteurs `n8n`, autosaved=false), alignement `versionId`/`activeVersionId`, `active=true`, record outbox `pending/publish` → restart → consumer : **4× `completed`**, triggers activés (Codeur 14h00 lun-ven, Diffusions 3×/jour, webhook ÉCLAIREUR ré-enregistré), 7 autres workflows re-publiés au boot. **Invariant vérifié : 11 actifs + publiés, 0 incohérent, 0 pending, webhooks 200.**
- **ℹ️ Restent volontairement NON publiés (brouillons)** : **AI Personal Assistant** (idée en réserve, Gemini + chatTrigger — l'activer le mettrait en écoute) et **My Sub-workflow** (sous-workflow utilitaire). Leur dire « publier » les activerait — à ne faire que sur demande explicite.
- ⚠️ Pièges notés pour les prochains runs : toute édition SQL d'un workflow doit ensuite passer par cette mécanique (snapshot + alignement + outbox) sinon l'activation sera perdue au restart ; la compaction d'historique purge les snapshots non référencés (ne pas laisser de snapshot « en réserve ») ; `activeVersionId` NULL = signal de dé-publication. Détail : skill `n8n-ops`.

## 🆕 Dernière session — 2026-09-27
- **✅ n8n mis à jour 2.39.8 → 2.41.3** (dump préalable `~/n8n-db-avant-MAJ-2026-09-27.sql.gz`, image **épinglée** `n8nio/n8n:2.41.3` au lieu de `:latest` dans `~/docker-compose.yml`) : healthz 200, tous les triggers réactivés, webhooks OK. 💡 Au démarrage, n8n 2.41 a **guéri automatiquement** les IDs cassés à la publication (`healBrokenNodeIds`) : snapshot `workflow_history` neuf + repoint `activeVersionId` pour « GitHub — descriptions auto » (mais pas le draft — doublons restés dans `workflow_entity.nodes`).
- **✅ Workflow « GitHub — descriptions auto » réparé (ordre 12:15, « Invalid workflow structure »)** : 2 paires de nœuds partageaient le même ID (`11111111-…-0002` entre « GitHub — liste des repos » et « Horloge hebdo (lun 22h00) » ; `-0003` entre « Filtre — sans description » et « Dépendances — vérifie et crée les PR »). Draft + vieux snapshot alignés sur le snapshot guéri (IDs uniques). Au passage, **hygiène des IDs sur tous les workflows** : ÉCLAIREUR (11 IDs NULL → UUIDs du snapshot guéri), Stripe + Tally ×2 (IDs « faits main » de 37-38 car. → UUIDs 36 car., drafts + snapshots — causaient `value too long for type character varying(36)` dans `workflow_publication_trigger_status` au démarrage), Alertes VPS (`webhook-1`) et Agent Telegram (`filter-chat-id-001`) → UUIDs. **Contrôle final : plus aucun ID invalide/dupliqué (drafts et snapshots), zéro erreur au redémarrage.** Pièges documentés dans le skill `n8n-ops`.
- **✅ Descriptions ajoutées aux 13 workflows (ordre 12:18)** : description précise (rôle, déclencheur, dépendances) dans `workflow_entity` + snapshots actifs (`workflow_history`).
- **✅ Workflow « Codeur — missions du jour » publié et activé (ordre 12:13)** : existant (créé le 25/09, inactif, `shared_workflow` déjà en place) — snapshot `workflow_history` créé + `activeVersionId` posé + `active=true`. Cron **14h00 lun-ven** : RSS codeur.com → dédup via `/projects/vps-state/codeur-sent.json` → Ollama choisit le top 5 → Telegram ; message « 📭 Codeur : aucune nouvelle » sinon. Trigger vérifié activé dans les logs ; réseau `apps` n8n→ollama OK.
- **✅ PR #4 deps de Lecteur-PDF réparée (ordre 12:22, CI `npm ci` EUSAGE)** : la branche `deps/maj-auto-2026-09-26` bumpait `pdfjs-dist` ^4.10.38 → ^6.3.289 dans `package.json` sans régénérer le lock. Fix : `npm install --package-lock-only` (lock v3, Node 22 local) → commit `09e0690` → push via webhook (PAT jamais en session) → **CI verte → PR mergée automatiquement (13:41 UTC)** via check `build` + allow_auto_merge. ⚠️ Le nœud deps ne régénère pas les lockfiles : à surveiller sur les prochaines PR deps npm (piste d'amélioration : régénération via ExecuteCommand — non implémenté).

## 🆕 Dernière session — 2026-09-26
- **✅ PAT GitHub centralisé — single source of truth (option env, décision assistant/utilisateur « B »)** : les scripts et workflows GitHub utilisaient 6 copies du PAT en dur (3 nœuds httpRequest + Config Push GitHub + 2 nœuds Code deps). Bascule sur **`GITHUB_PAT`** variable d'env n8n, lue via `$env.GITHUB_PAT`. Changements : `~/.env` += `GITHUB_PAT` ; `docker-compose.yml` n8n_workflow += `GITHUB_PAT=${GITHUB_PAT}` et **`N8N_BLOCK_ENV_ACCESS_IN_NODE=false`** ; conteneur recréé. **5 nœuds refactorés** (3 httpRequest header `=Bearer {{ $env.GITHUB_PAT }}` dans Agent Telegram « GitHub — mes repos », descriptions auto ×2 ; 2 nœuds Code deps `githubToken: ('Bearer ' + $env.GITHUB_PAT)`) avec snapshots `workflow_history` + repoint `activeVersionId` (Agent Telegram, GitHub — descriptions auto ; My Sub-workflow inactif = update nodes seul). Validation : tous les workflows s'activent, snapshots actifs sur `$env`, runtime 200, backups (`n8n-db-avant-env-github-…`, `docker-compose.yml.bak-env-github`). Il reste **une seule copie inline** : le **Config node de Push GitHub** (requis par les scripts `github-push.sh`/`vps-issue.sh` qui extraient le PAT de la DB).
- **⚠️ Credential « GitHub account » (n8n, githubApi) testée et invalide (401), supprimée le 26/09** : elle avait été créée/mise à jour le 25/09 mais retournait 401 au runtime n8n (le type `githubApi` envoie `token <accessToken>` mais le token stocké était mort) et **n'était référencée par aucun workflow**. Ne pas la recréer à tort — la source est désormais l'env `GITHUB_PAT`.
- **🧠 Pièges n8n 2.x découverts (importants, vs version précédente)** : (1) `process.env` est **bloqué par défaut** et n'existe même pas dans la sandbox des nœuds Code (task runner IsolatedVm) → utiliser **`$env.VAR`** dans les nœuds Code (⚠️ `process` « is not defined ») ; (2) pour activer l'accès env, **`N8N_BLOCK_ENV_ACCESS_IN_NODE=false`** ; (3) dans un **header httpRequest**, une expression doit être **préfixée par `=`** (`=Bearer {{ $env.GITHUB_PAT }}`), sinon elle reste un littéral (401 silencieux !).
- **⚠️ Sécurité signalée en attente** : `N8N_SECRET_KEY` runtime = valeur faible de type placeholder (`une_cle_secrete_tres_longue_et_unique`) — chiffre les données n8n (y compris le PAT inline résiduel du Config node). Recommandé : la renforcer (n8n re-chiffre au démarrage).

## 🆕 Dernière session — 2026-09-25
- **✅ Ordre Telegram « je ne veux plus avoir cette alerte » traité, puis décision utilisateur ajustée** : après désactivation du rapport de santé (timer `vps-metrics-report`), l'utilisateur a demandé de **réactiver le rapport VPS, mais uniquement le lundi** → `systemctl enable --now vps-metrics-report.timer` (`enabled`/`active`, tir **lundi 08:00 Europe/Paris**, prochain : 28/09). L'émetteur identifié était bien ce timer systemd (le workflow n8n « Alertes VPS (watchdog) » est inerte — webhook non appelé par le watchdog).
- **✅ Journal du soir allégé** : le message Telegram 📔 « Journal VPS publié » (23:00) est **coupé** (`$TG` commenté dans `/usr/local/bin/vps-daily-journal.sh` ligne 143) — le **push GitHub journalier vers le repo privé `VPS-Rennesdev.fr` est conservé**, ainsi que l'alerte ⚠️ en cas de push échoué.
- **✅ Rappels de backup : un seul conservé** — le rappel `vps-backup-reminder` (**dimanche 12:00**, avant le backup 19:30) est l'unique rappel programmé, validé tel quel. Les messages ✅/❌ de fin de backup (confirmations d'action) et les alertes watchdog Kopia (anomalies uniquement) ne sont pas des rappels et restent actifs.
- **Messages Telegram périodiques désormais** : watchdog (anomalies, 15 min), rapport 📊 lundi 08:00, rappel backup dimanche 12:00, confirmations backup, journal (push GitHub seulement), github-weekly vendredi 19:00.

## 🆕 Dernière session — 2026-09-24
- **✅ Bug « gros bouton bleu ne fait rien » (retours testeurs Play, ordre 23/09) corrigé sur Lecteur-PDF** : cause réelle trouvée et **reproduite en Chromium piloté via browserless** — le div `#viewer` (plein écran, `position:absolute`) est déclaré après `#empty` dans le DOM → il peint **au-dessus** du bouton bleu et interceptait tous les taps (démontré : un clic Puppeteer sur le bouton n'atteint jamais le bouton ; un `input.click()` direct déclenche bien le sélecteur). Fix : `z-index: 5` sur `#empty`. **Durcissements** : pdfjs renommé `.mjs` → `.js` (MIME garanti `application/javascript` — un module ES servi en `octet-stream` est refusé et tuait tout le JS de la page, reproduit également) ; moteur PDF chargé dynamiquement avec handlers toujours attachés + **message d'erreur visible** si échec. **Validation réelle : clic bouton → sélecteur de fichier s'ouvre ; PDF synthétique injecté → rendu canvas + « 1 / 1 », zéro erreur JS.**
- Pipeline complet : branche `fix/bouton-ouvrir-pdf` (règle 11) → push webhook (PAT jamais en session) → **PR #3** (body corrigé) → **CI `build` verte** → merge → branche distante supprimée → **release GitHub v1.0.2** (versionCode 3, AAB 3,5 Mo + APK 3,7 Mo signés, apksigner vérifié). ⚠️ Piège au passage : l'upload d'asset de release doit passer par `uploads.github.com`, pas `api.github.com` ; et `page.click()` Puppeteer est un **testeur d'accessibilité discret** — il a détecté le bug d'occlusion qu'un test visuel n'aurait pas vu.
- Reste utilisateur : téléverser l'AAB v1.0.2 dans la piste **Test fermé** de la Play Console (les 14 jours continuent, l'itération de version ne casse pas la piste).

## 🆕 Dernière session — 2026-09-22
- **⚠️ Incident « Dépendances GitHub — échec de la liste des repos : 401 » résolu** : le workflow deps (« GitHub — descriptions auto ») appelait `/user/repos` avec un **PAT mort** — la rotation du 21/09 avait été **écrasée par une écriture postérieure** (piège documenté : fichier local périmé). Vérification complète : « GitHub — descriptions auto » ×3 et « Agent Telegram » ×1 = ancien token (401 sur l'API), seul « Push GitHub » avait le bon (200). **Re-propagation SQL** (snapshot `workflow_history` + `activeVersionId` + restart n8n, healthz 200) : les 2 workflows re-conformes, `/user/repos` avec le PAT courant = 200. **Nouveau réflexe (à ajouter à toute rotation)** : vérifier la conformité des tokens de TOUS les workflows après propagation (grep comparé au PAT courant). Prochain run deps lundi 22h00 pour confirmation bout-en-bout.
- **✅ SPECTRE créé et déployé (ordres 21/09 — le projet n'existait pas, création selon la vision en réserve)** : analyse de contenu par IA avec **les 2 features demandées intégrées d'emblée** — (1) **onglet « Texte collé »** (coller le contenu d'une page web), (2) **onglet « Document »** upload PDF/MD/TXT ≤ 20 Mo (PDF via `pdftotext`/poppler). 3e mode : URL rendue par **Browserless** (Chromium headless, réseau `apps`, `domcontentloaded`). IA : **OpenRouter** si `/etc/openrouter-key.txt` (modèle `OPENROUTER_MODEL`, défaut `qwen/qwen-2.5-7b-instruct:free`), **fallback auto Ollama qwen2.5:3b** (`keep_alive: 0`) tant que la clé n'existe pas. Texte plafonné **3 000 car.** + `num_ctx 4096` (6 000 car. dépassait 95 s d'eval CPU → timeout). Zéro dep npm, image `node:22-alpine`+poppler, conteneur `spectre` (127.0.0.1:8087, réseau `apps`, mem_limit 512 m), `.env` local pour `BROWSERLESS_TOKEN` (gitigné). **Tests réels OK** : texte collé 15 s, MD 11 s, PDF facture 14 s, URL Wikipedia 76 s (résumé 5 points), erreurs propres (URL invalide, type non supporté). Repo **public `SPECTRE`** créé + poussé via webhook, README complet. **Vhost Caddy `spectre.rennesdev.fr` ajouté** (basic auth, credentials `/etc/caddy/spectre-auth.txt` root 600, config validée + reload OK) — **reste utilisateur : record DNS A `spectre.rennesdev.fr`** (proxy orange) puis restart Caddy pour le cert.
- Leçon latence : Ollama CPU = eval du prompt ~15 tok/s → 3 000 car. ≈ 60-70 s au total, à garder sous les 100 s Cloudflare ; tout texte plus long exigera OpenRouter.

## 🆕 Dernière session — 2026-09-21 (7e partie)
- **✅ Mega-readme v2 (ordres : métriques + bilinguisme)** :README du repo profil réécrit — **section Métriques** (impact client : 5-10 h/sem par dirigeant, 1-5 h/sem par brique du catalogue de 15 briques, devis 48 h → 15 min, erreurs réduites ; infra en chiffres : 10 conteneurs, CI 100 % des PR, deps auto-mergées hebdo, journal auto, incidents auto, backups chiffrés) + **version bilingue FR/EN** avec sélecteur d'ancre en haut. **Le lien portfolio a été corrigé par l'utilisateur lui-même sur GitHub** (2 commits « Fix portfolio link ») : pointe désormais vers **https://rennesdev.fr/portofolio.html** (vérifié : 200) — le README garde ce lien (exception assumée à l'anonymat : profil vitrine, choix utilisateur).
- ⚠️ **PAT GitHub affiché une 4e fois en session 21/09** (git pull mal formé — URL sans hôte — sortie d'erreur complète avec token). Rien sur disque, rien commité. **Rotation recommandée** : l'utilisateur génère un nouveau token fine-grained, le colle dans « Push GitHub », l'assistant le propage par SQL aux autres nœuds.
- Le repo `RuaudelEmmanuel.github.io` = **ancien site, conservé volontairement** (décision utilisateur 21/09) : le QR code de sa carte de visite renvoie vers ce site ; sur sa page d'accueil un bouton renvoie vers rennesdev.fr. Migration totale le jour du changement de carte de visite — ne pas toucher au repo.
- **✅ PAT GitHub roté et déployé partout (clôture de la rotation)** : l'utilisateur a collé le nouveau token dans « Push GitHub » ; propagation SQL aux 5 occurrences (« GitHub — descriptions auto » ×3, « Agent Telegram » ×1) avec snapshot `workflow_history` + `activeVersionId` + restart n8n (healthz 200) ; ancien token vérifié **absent** des 3 workflows ; procédure documentée dans `docs/push-github.md` (pièges : id de workflow ≠ activeVersionId ; colonnes camelCase à quoter en SQL) ; test réel : push ops OK avec le nouveau token. **✅ Ancien token révoqué par l'utilisateur le 21/09 — rotation entièrement close.**
- **✅ Mega-readme profil (ordre utilisateur)** : repo public **`Ruaudel-Emmanuel`** (nom exact du login = README affiché sur la page de profil) créé + `README.md` poussé — missions/objectifs, stacks en badges, **5 projets phares liés** (Nav.rennesdev, Lecteur-PDF, construction-site-tracker, rennesdev-vps-ops, surveillance-tarifaire), section « ce GitHub s'administre tout seul », cartes stats/streak, contact. Grep secrets = OK. Topics ajoutés. Clone local `~/projects/Ruaudel-Emmanuel`. **Utilisateur : pins posés + lien portfolio corrigé en direct sur GitHub.**

## 🆕 Dernière session — 2026-09-21 (6e partie)
- **✅ CI sur Lecteur-PDF (suite, ordre « toujours se demander si automatisable »)** : workflow CI mergé via PR #2 (même gabarit que construction-site-tracker : JDK 21, Node 22, `npm ci`, `npx cap sync android`, `assembleDebug`) → **check `build` requis** (ruleset 23774769 : `deletion` + `non_fast_forward` + required check, cible `~DEFAULT_BRANCH`) + `allow_auto_merge` → **2e repo en auto-merge complet des PR deps** (le workflow deps scanne les repos dynamiquement via `/user/repos`). Fix au passage : **`org.gradle.java.home` (chemin du VPS) commité dans `android/gradle.properties`** → invalide sur les runners GitHub, retiré. Vérifié : `npm ci` local OK, CI verte sur la PR et sur main.

## 🆕 Dernière session — 2026-09-21 (5e partie)
- **✅ Suite (ordres « . » = continuation)** : **templates déployés sur les 11 repos actifs** (les 3 vitrines + rennesdev-vps-ops #3, VPS-Rennesdev.fr #1, git-ops-journal #1, Besoin-visio #1, RuaudelPhoto #1, rennesdev #1, Fiscale-vps #4, surveillance-tarifaire #2 — toutes mergées, vérifié 11/11). 2 rulesets supplémentaires relaxés au passage : **Fiscale-vps** (23605002) et **surveillance-tarifaire** (23605165) avaient « 1 review » + cible `~ALL` (bloquait même le push de branche) → reconfigurés : cible `~DEFAULT_BRANCH`, règles `deletion` + `non_fast_forward`, review retirée. Déploiement scripté en une passe.

## 🆕 Dernière session — 2026-09-21 (4e partie)
- **✅ Phase B « alerte → issue » (choix utilisateur)** : nouveau script **`/usr/local/bin/vps-issue.sh`** (root 700) — ouvre/clôt des issues GitHub via l'API (PAT extrait de la base n8n en variable shell, jamais affiché ; `jq` ; dédoublonnage par titre + retry ; modes `open`/`close`/`close-prefix`, défaut : repo `rennesdev-vps-ops`, label `incident`). **Issues activées** (désactivées par défaut sur rennesdev-vps-ops). Intégrations : (1) **watchdog** — chaque alerte fraîche ouvre une issue « Watchdog VPS : … », et un passage **vert** clôt automatiquement les issues watchdog ouvertes ; (2) **journal quotidien** — push échoué → issue ouverte, push réussi → clôture auto. Tests réels ✓ (2 issues de test clôturées avec commentaire). (3) **Rapport hebdo** : section « Suggestions d'issues roadmap » — repos actifs silencieux ≥ 21 jours.
- Choix d'implémentation : script hôte direct plutôt que workflow n8n — tâche purement mécanique (règle du 18/09). Scripts versionnés dans le repo ops.

## 🆕 Dernière session — 2026-09-21 (3e partie)
- **✅ Phase A « dynamiser issues + code review » (choix utilisateur)** : (1) **construction-site-tracker** — ruleset 23667839 reconfiguré : « 1 review » (impossible en solo) remplacé par **check CI requis `build`** sur la branche par défaut + `deletion`/`non_fast_forward` + `allow_auto_merge` ; **workflow CI** (JDK 21 → Node 22 → cache Gradle → `npm ci` → `npx cap sync android` → `assembleDebug`) mergé via PR #5 avec le **rattrapage du commit Cible API 36** + 3 fixes révélés par la CI : package-lock régénéré (capacitor 6→8), Node 22, **minSdk 22 → 24** (plugin Camera ioncamera) ; (2) **templates mergés sur les 3 vitrines** (Nav.rennesdev #1, Lecteur-PDF #1, construction-site-tracker #6).
- ⚠️ **Impact produit** : minSdk 24 s'appliquera au **prochain build release**. Pièges notés : ruleset `~ALL` bloque **tous** les push de branches → toujours `~DEFAULT_BRANCH` ; Capacitor 8 exige Node ≥ 22 ; `npm ci` échoue si lock désynchronisé.
- Clone local `lecteur-pdf` sur `master` (origin = main) → renommé `main`.

## 🆕 Dernière session — 2026-09-21 (2e partie)
- **✅ Alerte « Journal VPS : push échoué » (depuis le 18/09) résolue** — cause : le service (root) voit le clone `~/projects/vps-journal` appartenant à ubuntu → **git refuse (« dubious ownership »)** → échec silencieux. **Correctifs** : (1) `safe.directory '*'` pour root ; (2) script réorienté vers le **clone canonique `~/projects/VPS-Rennesdev.fr`** (ancien clone `vps-journal` supprimé) ; (3) test réel : **journaux 18→21/09 poussés** (`ec138fe`) + Telegram de succès ; (4) script versionné dans le repo ops.
- Leçon : après une restructuration de répertoires, toujours vérifier les chemins des scripts systemd.

## 🆕 Dernière session — 2026-09-21
- **🔧 Incident détecté et résolu : containerd + dockerd brûlaient ~80 % de CPU (2 cœurs) en continu depuis le 10/09** — load 5,8-6,1 sans processus visible. Diagnostic : arrêt temporaire de Netdata → CPU des démons Docker tombe à 0,2 % → coupable = collecteur go.d **docker** de Netdata, API Docker interrogée **toutes les secondes** (`/images/json` devenu coûteux sur le snapshotter containerd, store 16 Go). Fix : `go.d/docker.conf` dans le volume netdata (`update_every: 30`) + healthcheck filebrowser 5 s → 60 s (~17 000 spawns runc/jour). **Résultat : load 5,9 → 1,4, containerd/dockerd à 0,1 % CPU.** Doc : `docs/netdata.md`. ⚠️ Re-vérifier après MAJ de l'image Netdata.
- Contrôle santé initial : tout vert (RAM 25 %, disque 61 %, Kopia OK, 6 timers actifs, ORDRES.md absent).

## 🆕 Dernière session — 2026-09-20 (3e partie)
- **✅ Publicité GitHub maximisée (ordre utilisateur — visibilité pour recruteurs)** : grep secrets préalable sur chaque repo (aucun secret réel trouvé — fingerprints Kopia et `whsec_MASQUE` inoffensifs) puis passage en **public** via API : `Nav.rennesdev`, `Lecteur-PDF`, `Besoin-visio`, `RuaudelPhoto`. Restent privés : `git-ops-journal`, `VPS-Rennesdev.fr` (journals d'exploitation, détails infra) — choix défendu, à valider par l'utilisateur.
- **⚠️ Découverte : `Lecteur-PDF` était archivé sur GitHub** (impossible d'y pousser les futures releases du test fermé Play) → désarchivé en même temps que la mise en public. 12 repos actifs publics désormais (vs 5 avant).
- `rennesdev-vps-ops` est public : vérifié sans secrets (IP serveur, IP Tailscale, timers visibles — pas exploitable de l'extérieur : UFW 22/80/443, SSH par clé, Cloudflare proxy, Tailscale = réseau privé).

- **✅ Suite (ordre utilisateur)** : `git-ops-journal` et `VPS-Rennesdev.fr` passés en **public** après grep élargi (tokens, chat ID, IP Tailscale, mots de passe — rien trouvé ; contenu des journaux anonymisé par conception : ni domaine ni IP publique). README des deux corrigés (« Repo privé » → « Repo public »), poussés via webhook. **14 repos actifs publics au total**, restent 0 actif en privé. Clonage de `VPS-Rennesdev.fr` dans `~/projects/` (convention projets).

## 🆕 Dernière session — 2026-09-20 (2e partie)
- **✅ Skill `vps-sante` mis à jour** (il datait d'avant les derniers services) : script `vps-sante.sh` couvre désormais **10 conteneurs** (+ filebrowser, nav_rennesdev, uptime_kuma, browserless), **3 vhosts récents** (nav/uptime → 401 attendu sans auth = basic auth OK ; fichiers → 200 = page login), **5 certificats** et **6 timers** (+ github-weekly, vps-daily-journal). Contrôle relancé : **TOUT VERT** (RAM 26 %, disque 60 %, snapshot Kopia 17:34 du jour, cert LE up 17h34 OK). Copie repo `rennesdev-vps-ops` mise à jour et poussée via webhook (PAT jamais en session).
- RAS sinon : ORDRES.md absent, pas d'anomalie, 4 paquets APT en phasing (normal).
- **Clôture de session (18h52 UTC)** : sauvegarde Kopia à la demande exécutée — 4 snapshots (staging + dumps PG umami/n8n, volumes Docker, /home/ubuntu, /etc/caddy) vers le PC `super-pc-vert`. Tous les changements du jour inclus (ETAT-VPS.md, scripts, repos publics).

## 🆕 Dernière session — 2026-09-20
- **✅ n8n mis à jour 2.39.6 → 2.39.8** (dump préalable `~/n8n-db-avant-MAJ-2026-09-20.sql.gz`, conteneur recréé) : `/healthz` 200, 10 workflows actifs, webhooks OK.
- **✅ Uptime-Kuma en production** : conteneur `uptime_kuma` (127.0.0.1:3001, mem_limit 512 m, volume `kuma_data`, réseau `apps`), vhost **https://uptime.rennesdev.fr** (basic auth + login Kuma), **8 moniteurs** (n8n, Umami, Nav, Fichiers, Netdata, Browserless, Ollama, port PG n8n_db — 60 s, maxretries 2), **notification Telegram liée aux 8**, 130+ heartbeats enregistrés. Skill `uptime-kuma` créé (argument commercial « Résilience/Garantie »). Record DNS créé par l'utilisateur (proxy orange).
- **✅ Browserless (Chromium headless) déployé** : conteneur `browserless` (127.0.0.1:3100 → 3000, mem_limit 1500 m, shm 512 m), token API dans `~/.env` (`BROWSERLESS_TOKEN`). Usage depuis n8n : `http://browserless:3000?token=…`. Tests réels : screenshot PNG 200, mauvais token → 401.
- **🔧 Fin de chantier interrompu (continué par l'assistant)** : cert LE d'uptime non émis (retries ACME planifiés avant la création du DNS — même piège que Nav le 19/09) → **restart Caddy, cert obtenu 15:41 UTC, HTTPS 200**. Fichier `/etc/caddy/uptime-auth.txt` incomplet (commentaires sans ligne identifiants) → **mot de passe régénéré** et écrit (root 600) ; mot de passe Kuma (bcrypt en base) réaligné sur le même, vérifié par comparaison bcrypt.
- **⚠️ Incident Caddy (rattrapé dans la foulée)** : deux appels `caddy hash-password` défaillants (refus stdin dans cet environnement ; `-p` prend le mot de passe littéral, pas un fichier) puis des `sed` trop larges ont vidé/écrasé les hash `basic_auth` du Caddyfile — le reload en échec a maintenu la config valide en RAM ; restauration faite depuis les plaintexts root-only (`nav-auth.txt`, `netdata-auth.txt`, uptime regénéré), hash produits avec bcryptjs du conteneur Kuma (`$2a$10$`, accepté par Caddy). Piège supplémentaire détecté et corrigé : extraction du mot de passe nav par `cut -d:` sur les deux lignes du fichier → chaîne parasite (le moniteur Kuma « Nav » a signalé DOWN 15h46-15h55, retour UP après remise du vrai hash). Vérifié : uptime 302→dashboard, nav 200, netdata 200, **401 sans auth sur les 3**, 8/8 moniteurs UP. Leçons : écrire les hash via Python/heredoc, jamais un sed sur motif partiel ; extraire un mot de passe en ciblant la ligne exacte (`sed -n 's/^password: //p'`).
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
| n8n | **v2.41.3** (maj 27/09, image épinglée `n8nio/n8n:2.41.3`) — `n8n_workflow` (127.0.0.1:5678) + `n8n_db` (**PostgreSQL 17**) — `~/docker-compose.yml`, mdp dans `~/.env` (`N8N_DB_PASSWORD`) |
| Ollama | `ollama` (127.0.0.1:11434), réseau Docker `apps` — modèles : `qwen2.5:7b` (bot IA), `llama3.2:3b`, `qwen2.5:3b`. `OLLAMA_KEEP_ALIVE=10m` (réduit de 30 min le 18/09, choix utilisateur) |
| Netdata | `netdata`, UI **127.0.0.1:19999** + **https://netdata.rennesdev.fr** (basic auth, credentials `/etc/caddy/netdata-auth.txt` root 600) — `~/netdata/docker-compose.yml` |
| File Browser | `filebrowser`, UI **127.0.0.1:8085** + **https://fichiers.rennesdev.fr** (auth JWT intégrée, credentials `/etc/caddy/filebrowser-auth.txt` root 600, scope `/home/ubuntu`) — `~/filebrowser/docker-compose.yml` |
| Nav.rennesdev | `nav_rennesdev` (`node:22-alpine`, zéro dep) — **https://nav.rennesdev.fr** (basic auth, credentials `/etc/caddy/nav-auth.txt` root 600) → 127.0.0.1:8086 — `~/projects/Nav.rennesdev/docker-compose.yml` (repo GitHub `Nav.rennesdev`) — navigateur léger mode lecture, v2 = assistant IA |
| Uptime-Kuma | `uptime_kuma` (`louislam/uptime-kuma:1`, mem_limit 512 m) — **https://uptime.rennesdev.fr** (basic auth + login Kuma, credentials `/etc/caddy/uptime-auth.txt` root 600) → 127.0.0.1:3001 — 8 moniteurs + notification Telegram — volume `kuma_data` |
| Browserless | `browserless` (`ghcr.io/browserless/chromium`, mem_limit 1500 m, shm 512 m) — Chromium headless piloté par API (scraping JS, PDF, screenshots) — 127.0.0.1:3100 ; usage n8n : `http://browserless:3000?token=` (`BROWSERLESS_TOKEN` dans `~/.env` + `~/projects/SPECTRE/.env`) |
| SPECTRE | `spectre` (image node:22-alpine+poppler, zéro dep) — **https://spectre.rennesdev.fr** (basic auth, credentials `/etc/caddy/spectre-auth.txt` root 600) → 127.0.0.1:8087 — `~/projects/SPECTRE/` (repo public `SPECTRE`) — analyse de contenu IA : URL rendue Browserless, texte collé, PDF/MD ; IA OpenRouter (si clé) sinon Ollama qwen2.5:3b |
| Bot contrôle | `vps-tgbot.service` → `/usr/local/bin/vps-tgbot.py` (long polling) : `/backup`, `/status`, `/ordres`, `/ok`, `/help` |
| Bot IA | Workflow n8n « Agent Telegram » (bot dédié) : Telegram → Filter chat.id → Ollama qwen2.5:7b + PG Chat Memory → réponse |
| Sécurité | UFW (22/80/443), fail2ban (sshd + recidive), SSH par clé uniquement, `passwordauthentication=no` |

## Timers systemd
| Timer | Horaires (Europe/Paris) | Rôle |
|---|---|---|
| `vps-watchdog` | toutes les 15 min | anomalies → Telegram (`/usr/local/bin/vps-watchdog.sh`) |
| `vps-metrics-report` | **lundi 08:00** | rapport métriques → Telegram (`/usr/local/bin/vps-metrics-report.sh`) — **réactivé le 25/09 sur demande (lundi uniquement)** |
| `vps-ollama-unload` | tous les jours 19:15 | décharge les modèles ollama avant backup |
| `vps-backup` | dimanche 19:30 | backup Kopia complet (PC allumé requis) |
| `vps-backup-reminder` | dimanche 12:00 | rappel Telegram (PC joignable ? dépôt ? âge snapshot) |
| `github-weekly` | vendredi 19:00 | rapport hebdo GitHub → repo `git-ops-journal` + Telegram |
| `vps-daily-journal` | tous les jours 23:00 | journal quotidien du VPS → repo `VPS-Rennesdev.fr` (**message Telegram coupé le 25/09**) |

## Backups (Kopia)
- Chaîne : `vps-backup.timer` → `kopia-backup.sh` (staging = dump umami + pg_dump n8n + configs, puis snapshots : `/var/lib/docker/volumes`, `/home/ubuntu`, `/etc/caddy`) → **dépôt Kopia sur le PC Windows** (`super-pc-vert`, 100.118.76.30, port 51515, TLS cert RSA fixe, fingerprint `46d81925…`).
- À la demande : `/backup` Telegram → `vps-backup-on-demand.sh` (démarre le serveur Kopia du PC via SSH si besoin, clé `/root/.ssh/id_ed25519_pc`).
- Restauration : `kopia restore` (testée sur dumps). Certificat PC valable jusqu'en 2036.

## Tailscale
- VPS `vps-5532a57a` = 100.75.226.13 ↔ PC `super-pc-vert` = 100.118.76.30 (connexion directe, ~20 ms).

## 🧠 PRÉFÉRENCES UTILISATEUR (mémoire permanente)
9. **Pas d'alerte Telegram pour les situations normales** : PC éteint = pas d'alerte Kopia. Une alerte = quelque chose à faire. Un **seul** rappel de backup (dimanche 12:00, avant le backup 19:30). Journal du soir : push GitHub uniquement, plus de message Telegram (25/09).
11. **Règle GitHub (ordre 19/09)** : tout nouveau projet = **son propre repo** (jamais un sous-dossier d'un repo existant) **et naît avec son README** (ordre 19/09) ; toute amélioration d'un projet = **nouvelle branche** dédiée dans le repo du projet ; toutes les améliorations = **commits commentés**.
1. **Canal d'alerte = Telegram** : bot `@Vosmanubot` (Bot-vps), chat `TG_CHAT_ID=8634051625`, config `/etc/vps-watchdog-telegram.env` (root 600). JAMAIS de token dans un fichier commité ou ce journal.
2. **Chaque nouveau workflow/création → repo GitHub avec README** : `github.com/Ruaudel-Emmanuel/rennesdev-vps-ops` (privé, local : `~/projects/rennesdev-vps-ops`). **Push sans PAT en session** : webhook n8n `POST https://n8n.rennesdev.fr/webhook/github-push` — PAT extrait de la base n8n (`n8n_db`, table `workflow_entity`, workflow « Push GitHub ») directement en variable shell du curl, jamais affiché ni sur disque. Voir `docs/push-github.md`.
3. Heures des timers : **Europe/Paris** (le serveur est en UTC).
4. L'utilisateur est sur **Windows 11** (`super-pc-vert`) — manipulations PC = pas-à-pas clairs.
5. **Aucun secret côté assistant** ; secrets → fichiers root-only sur le VPS.
6. **Au début de CHAQUE session : lire `/home/ubuntu/ORDRES.md`** (ordres via bot `@Vosmanubot`, message libre = ordre), les traiter, marquer ✅. `/ordres` liste, `/ok` vide.
7. **Maintenance du journal** : `ETAT-VPS.md` = état courant + dernière session ; le 1er de chaque mois → déplacer les entrées datées du mois écoulé dans `ETAT-VPS-archive-<AAAA-MM>.md` puis pusher les deux sur GitHub. Skill `vps-sante` (`~/.agents/skills/vps-sante/`) = procédure standard de contrôle de santé. **Par sujet → skills dédiés** (chargés seulement quand le sujet sort) : `github-ops`, `n8n-ops`, `stripe-ops`, `tally-ops` (`~/.agents/skills/`).
8. **Rapport hebdomadaire lundi 08:00 Paris** sur Telegram (`vps-metrics-report.timer`) — **réactivé le 25/09** (lundi uniquement, décision utilisateur). Vérifier qu'il est actif au contrôle santé.
10. **Airtable forfait gratuit = 1 000 appels API/mois** (partagés entre les workflows) : tout workflow Airtable doit être économe — appels groupés (formule OR, batch records), cache staticData des listes, fréquence limitée, pause auto sur 429. Se référer au design des workflows « Diffusion » (16/09).

12. **Vision GitHub (ordre 21/09)** : le GitHub doit être **dynamique sans excès** et se gérer **le plus autonome possible** — l'objectif est qu'il soit attractif pour un recruteur sans travail phénoménal de l'utilisateur. Règle de décision pour toute automatisation GitHub : est-ce que ça ajoute de l'activité réelle et régulière sans créer de bruit ni de charge manuelle ? Privilégier l'auto-merge, les auto-issues, les rapports ; éviter le bot-spam cosmétique.

14. **Agent n8n = référent « n8n » (ordre 28/09)** : quand l'utilisateur dit « n8n », il désigne l'agent n8n (workflow **« AI Personal Assistant »** — rédacteur de messages SMS/Telegram, chatTrigger + agent LangChain, **Ollama local qwen2.5:7b**). Toujours passer par cet agent pour les demandes « n8n ».
13. **Principe d'automatisation (ordre 21/09)** : se demander systématiquement « **Peut-on l'automatiser ?** » — si oui, automatiser, en priorité pour GitHub et les outils où c'est possible. S'applique à chaque nouveau besoin, incident récurrent ou tâche répétitive repérée pendant les sessions.
15. **Prompt idéal + contraintes techniques (ordre 01/10)** : (a) **En fin de projet** (branche fusionnée, release, ou projet terminé), ajouter systématiquement la section **„Prompt idéal de départ“** dans le README.md (cf. skill `readme-prompt-fin-projet`). (b) **Au début de chaque nouveau projet**, demander à l'utilisateur ses **contraintes techniques** (OS, stack, hébergement, budget, public cible) avant de commencer à coder.

## ⏳ En attente (actions utilisateur)
> ℹ️ Pourquoi « hors VPS » : ce n'est pas que le PC est plus sûr — c'est de la redondance (le VPS = point de défaillance unique ; sans keystore, l'app est figée à jamais sur le Play Store). La copie existe déjà via le snapshot Kopia hebdo de `/home/ubuntu` vers le PC — l'enjeu est de vérifier qu'un restore fonctionne.
- ✅ 2026-09-24 : **bug du bouton bleu corrigé (release v1.0.2) et téléversée par l'utilisateur dans la piste Test fermé** de la Play Console — les testeurs reçoivent la mise à jour, le comptage des 14 jours continue. Note : le test fermé est lancé avec ~20 testeurs (ordre 23/09), premiers retours reçus et traités.
- **lecteur-pdf : Play Console** — créer l'app « Lecteur PDF » (⚠️ package = `fr.rennesdev.lecteurpdf`), upload AAB v1.0.0 en Tests internes, fiche store + captures, déclaration « aucune donnée ». Guide : `PLAY-STORE.md` du repo `Lecteur-PDF`.
- ✅ 2026-09-20 : record DNS A `uptime.rennesdev.fr` créé (proxy orange) — cert LE émis, HTTPS 200, 8 moniteurs + notification Telegram actifs.
- ✅ 2026-09-19 : record DNS A `nav.rennesdev.fr` créé (proxy orange) — cert LE émis, HTTPS 200, navigation testée. **Nav.rennesdev v1 terminée.**
- ✅ 2026-09-18 : record DNS A `fichiers.rennesdev.fr` créé (proxy orange, cert LE émis, HTTPS 200).
- ✅ 2026-09-18 : **2 keystores sauvegardés hors VPS** (l'utilisateur).
- ✅ 2026-09-18 : **PAT GitHub roté et déployé partout, ancien token révoqué** — rotation close.
- **✅ 2026-09-22 : SPECTRE en production** — record DNS A créé (proxy orange), restart Caddy, **cert LE émis, HTTPS 401/200, analyse testée via l'URL publique**. **OpenRouter branché le jour même** : clé fournie par l'utilisateur dans `/etc/openrouter-key.txt` (root 600, montée read-only dans le conteneur), modèle **`inclusionai/ling-3.0-flash-vl:free`** (défaut) — **analyse 1,6 s (texte collé) et 5,5 s (URL Wikipedia) vs 11-76 s en Ollama CPU** ; fallback Ollama auto en cas d'échec API. ⚠️ La plupart des modèles gratuits sont bloqués par la data policy du compte OpenRouter (« 0 endpoints matching guardrail ») — pour débloquer gemma/qwen : activer les endpoints d'entraînement dans les réglages Privacy du compte.
- **Play Console (bloqué sur le test fermé, 2026-09-19)** : 2 apps créées (brouillon + tests internes), questionnaires (classification du contenu, cible et contenu) et fiches Play Store **remplis**, icônes et illustrations générées via Google AI Studio, uploads AAB en tests internes, **11 testeurs**. ⚠️ **Compte « Particulier » confirmé (profil validé 01/07/2026) → test fermé obligatoire : ≥ 20 testeurs optés en continu pendant 14 jours** avant production. Reste utilisateur : créer la piste « Test fermé » par app (AAB déjà validé), recruter 9-10 testeurs de plus (≥ 20, opt-in + installation réelle), tenir 14 jours (les 2 apps en parallèle avec les mêmes testeurs), puis « Demander l'accès à la production ».
- ✅ 2026-09-18 : **PR #2 (recréée en #4) fusionnée** — projet Android Capacitor sur `main` de `construction-site-tracker` (avec la PR deps #1).
- **construction-site-tracker : Play Console** — créer l'app, upload de l'AAB (release v1.0.0) en Tests internes, laisser « Google gère la clé de signature de l'app » (Play App Signing), complétérer fiche store + déclaration données. Guide pas-à-pas : `PLAY-STORE.md` dans le repo.
- ✅ 2026-09-18 : **keystore suivi-interventions sauvegardé hors VPS** (couvert par la ligne keystores ci-dessus).
- ✅ 2026-09-17 : points GitHub précédents tous traités (ancien token révoqué, issue fermée, PR relues, Tally photographe OK, PAT roté, dépôts confirmés) — validé par l'utilisateur.

## 🔎 Vérifications rapides utiles
```bash
bash ~/.agents/skills/vps-sante/scripts/vps-sante.sh   # contrôle complet (exit 0 = vert)
docker ps                                              # 10 conteneurs attendus (dont filebrowser, nav, uptime_kuma, browserless)
curl -s -o /dev/null -w '%{http_code}' https://n8n.rennesdev.fr   # 200
sudo fail2ban-client status sshd
docker exec ollama ollama list
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:19999     # 200 (netdata)
systemctl list-timers github-weekly.timer --no-pager             # vendredi 19h00 Paris
systemctl list-timers vps-daily-journal.timer --no-pager         # tous les jours 23h00 Paris
```

## Notes
- 💡 **OpenRouter (25/09)** : la limite mensuelle de dépense (10 €) a été supprimée par l'utilisateur — plus d'interruption de session assistant par épuisement de crédit. Les usages IA cloud (assistant pi, SPECTRE) peuvent être utilisés sans craindre le quota mensuel ; garder le fallback Ollama local pour le chat perso (décision ferme inchangée).
- 💡 **SPECTRE (déployé le 22/09, choix utilisateur via ordres)** : ex-idée en réserve, lancée le 22/09 avec les 2 features demandées (texte collé + documents PDF/MD). Rendu de page par **Browserless** (déployé le 20/09 — pas de conteneur Playwright dédié). **IA : OpenRouter actif depuis le 22/09 (clé montée, ling-3.0-flash-vl:free, 1-6 s) avec fallback Ollama auto** (plafond Cloudflare 100 s). ÉCLAIREUR reste tel quel sur Ollama local. **Le chat perso (Agent Telegram, qwen2.5:7b) reste en local, décision ferme** (données de conversation personnelles ne quittent pas le VPS). Gestion clé : `/etc/openrouter-key.txt` root-only, jamais en session, fallback Ollama si API down (déjà implémenté dans server.js). Contraintes inchangées : RAM, taille de contexte, respect des sites (lecture publique seule, pas de contournement paywall/anti-bot).
- Historique détaillé (crises résolues, installations, debugging) : `ETAT-VPS-archive-2026-09.md`.
- Docs ops + workflows + scripts versionnés : `~/projects/rennesdev-vps-ops/` (= repo GitHub).
- Skill de contrôle santé : `~/.agents/skills/vps-sante/` (copié dans le repo GitHub).

=== Rotation 2026-10-03 13:15 ===

# 📋 État du VPS rennesdev.fr — État courant
> Rotation 2026-10-03 — l'historique complet des sessions antérieures est archivé dans `ETAT-VPS-ARCHIVE.md`.
> Ce fichier est la version légère, prête pour les nouveaux relevés.

## 📌 Résumé condensé de l'historique

**Infrastructure**
- VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7,6 Go RAM, 72 Go disque
- IPv4 : 162.19.246.465 (proxy Cloudflare Orange, Full Strict, Always Use HTTPS)
- IPv6 : 2001:41d0:701:1100::208c
- Tailscale : `vps-5532a57a` (100.75.226.13)
- DNS Cloudflare, Caddy 80/443 (certs ACME Let's Encrypt auto)

**Services conteneurisés** (réseau Docker `apps`)
| Conteneur | Port(s) | Image |
|---|---|---|
| `n8n_workflow` | 127.0.0.1:5678 | n8nio/n8n:2.41.3 |
| `n8n_db` | (5432, réseau apps) | postgres:17-alpine |
| `ollama` | 127.0.0.1:11434 | ollama/ollama:latest |
| `browserless` | 127.0.0.1:3100 | ghcr.io/browserless/chromium |
| `filebrowser` | 127.0.0.1:8085 | filebrowser/filebrowser:v2 |
| `nav_rennesdev` | 127.0.0.1:8086 | node:22-alpine |
| `uptime_kuma` | 127.0.0.1:3001 | louislam/uptime-kuma:1 |
| `spectre` | 127.0.0.1:8087 | node:22-alpine (+poppler) |
| `netdata` | 127.0.0.1:19999 | netdata/netdata |
| `umami_app` | 127.0.0.1:3000 | ghcr.io/umami/… |
| `umami_db` | (5432, réseau umami) | postgres:16-alpine |

**Ollama** — modèles disponibles : `qwen2.5:7b` (bot IA), `qwen2.5:3b` (analyses), `llama3.2:3b`. `OLLAMA_KEEP_ALIVE=10m`. Serveur écoute `127.0.0.1:11434`.

**Timers systemd** (Europe/Paris)
| Timer | Horaire | Rôle |
|---|---|---|
| `vps-watchdog` | toutes les 15 min | anomalies → Telegram |
| `vps-metrics-report` | lundi 08:00 | rapport métriques → Telegram |
| `vps-ollama-unload` | 19:15 | décharge modèles avant backup |
| `vps-backup` | dimanche 19:30 | Kopia → PC (super-pc-vert) |
| `vps-backup-reminder` | dimanche 12:00 | rappel Telegram |
| `github-weekly` | vendredi 19:00 | rapport hebdo GitHub |
| `vps-daily-journal` | 23:00 | push journal VPS → GitHub |

**Backups Kopia** — dépôt sur PC `super-pc-vert` (100.118.76.30:51515), TLS. Snapshots : volumes Docker + /home/ubuntu + /etc/caddy.

**Sécurité** — UFW 22/80/443, fail2ban (sshd + recidive), SSH clé uniquement, `passwordauthentication=no`.

**Dernières opérations importantes** (après la rotation septembre)
- ✅ Migration n8n 2.39.8 → 2.41.3 (27/09) ; mécanique de publication par snapshots `workflow_history` + `activeVersionId` + outbox rodée
- ✅ Centralisation PAT GitHub : `GITHUB_PAT` dans `~/.env` + compose n8n ; documentation dans skills `github-ops` + `n8n-ops`
- ✅ GitHub Auditor : workflow n8n (audit des dépôts → Telegram) — publié et actif ; `keep_alive` corrigé à 600 (évite ECONNABORTED)
- ✅ SPECTRE déployé : analyse IA texte/document/PDF/URL (OpenRouter + fallback Ollama local)
- ✅ Audio Transcriber : app Windows tkinter (capture → faster-whisper → Ollama → .md)
- ✅ Skills : `vps-sante`, `github-ops`, `n8n-ops`, `stripe-ops`, `tally-ops`, `uptime-kuma`, `questionnement-contraintes-tech`, `readme-prompt-fin-projet`

**Fichiers de référence**
| Fichier | Rôle |
|---|---|
| `ETAT-VPS-ARCHIVE.md` | Anciennes sessions (avant rotation 10/2026) |
| `ORDRES.md` | Ordres en attente (via bot @Vosmanubot) |
| `~/projects/rennesdev-vps-ops/` | Documentation ops + workflows + scripts |

**Canaux de communication**
- Bot @Vosmanubot (TG_CHAT_ID=8634051625) : ordres, alertes, rapports
- Canal alerte : Telegram uniquement.

## ⚙️ État Actuel
> (section à renseigner)

## 🐳 Services Docker
> (section à renseigner)

## 🔴 Logs & Erreurs
> (section à renseigner)

## 🆕 Dernière session — 2026-10-03
- **✅ Rotation automatisée créée** : script `vps-etat-rotate.sh` + timer systemd (dimanche 18h00) — archive ETAT-VPS.md → ETAT-VPS-ARCHIVE.md et crée une version légère.
- **✅ Script+service+timer poussés** (`commit`).
- **✅ ORDRES.md** : ordre du jour marqué traité.

=== Rotation 2026-10-03 13:15 === — fin

=== Rotation 2026-10-04 16:00 ===

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

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.41.3, Ollama, Browserless, FileBrowser, Netdata, Uptime‑Kuma, Nav.rennesdev, SPECTRE, Umami (app+db). PG 17 pour n8n, PG 16 pour Umami.

**Ollama** — modèles : qwen2.5:7b (bot IA), qwen2.5:3b (analyses, dont GitHub Auditor & SPECTRE), llama3.2:3b. `OLLAMA_KEEP_ALIVE=10m`.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30 (rappel 12h00). Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, metrics 📊 lun 08:00, ollama-unload 🧠 19:15, backup 💾 dim 19:30, backup-reminder 🔔 dim 12:00, github-weekly 📈 ven 19:00, daily-journal 📝 23:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Workflows n8n** : 14 workflows dont **GitHub Auditor** (06h00, analyse groupée de tous les dépôts actifs via Ollama qwen2.5:3b, rapport Telegram) — republié le 04/10 (batching des appels Ollama, fix invariant).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel
> (section à renseigner — libre)

## 🐳 Services Docker
> (section à renseigner — synthèse des conteneurs, versions, ports exposés)

## 🔴 Logs & Erreurs
> (section à renseigner — incidents, anomalies en cours)

=== Rotation 2026-10-04 16:00 === — fin
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

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.41.7, Ollama, Browserless, FileBrowser, Netdata, Uptime‑Kuma, Nav.rennesdev, SPECTRE, Umami (app+db). PG 17 pour n8n, PG 16 pour Umami.

**Ollama** — modèles : qwen2.5:7b (bot IA), qwen2.5:3b (analyses), llama3.2:3b. `OLLAMA_KEEP_ALIVE=10m`.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30 (rappel 12h00). Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, metrics 📊 lun 08:00, ollama-unload 🧠 19:15, backup 💾 dim 19:30, backup-reminder 🔔 dim 12:00, github-weekly 📈 ven 19:00, daily-journal 📝 23:00, aac-weekly 🧹 lun 05:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts), `~/projects/aac-audit-journal/` (journal AAC), `~/projects/GitHub-Auditor/workflows/` (workflows versionnés : github-auditor.json + scan-ubuntu-latest/).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel — 2026-10-07 12:22

**Santé générale :** ✅ Tout vert
- RAM : 24% (1.8/7.6 GiB) — Load : 0.24 — Disque : 65% — Uptime : 5j 1h51
- 6 paquets APT en attente de mise à jour
- n8n : **2.41.7** — 15 workflows dont 14 actifs : Agent Telegram, AI Personal Assistant, GitHub — descriptions auto, GitHub Auditor, Scan ubuntu-latest, Push GitHub, Diffusion Actus/Photos Discord, Stripe/Tally (×2), Codeur, Alertes VPS, ÉCLAIREUR
- Ollama : **0.34.0** — modèles : qwen2.5:7b, qwen2.5:3b, llama3.2:3b
- Bot Telegram vps-tgbot : actif polling OK

## 🐳 Services Docker

| Conteneur | Statut | Notes |
|---|---|---|
| n8n_workflow | ✅ running (recréé 10:42) | v2.41.7, port 5678 |
| n8n_db | ✅ running | PostgreSQL 17 |
| umami_app + db | ✅ running | Stack Umami |
| ollama | ✅ running | v0.34.0, 3 modèles |
| netdata | ✅ running | Monitoring |
| filebrowser | ✅ running | Fichiers |
| nav_rennesdev | ✅ running | Navigation |
| uptime_kuma | ✅ running | Uptime monitoring |
| browserless | ✅ running | Chromium headless |

## 🔴 Anomalies en cours

| Anomalie | Statut | Détail |
|---|---|---|
| Kopia — dépôt déconnecté | ⚠️ Attendu | PC super-pc-vert inaccessible (port 51515 fermé). Normal si PC éteint (dimanche après-midi, backup programmé à 19:30) |

**Dernier backup réussi :** 2026-10-04 (daily journal OK)
**Dernier backup à la demande :** 2026-10-01 (log présent)

## 📦 Nouveautés de la session (2026-10-05)

| Ajout | Détail |
|---|---|
| 🧹 **AAC maintenance hebdo** | `aac-weekly-maintenance.timer` — chaque lundi 05:00 |
| 📋 **Journal AAC** | [`aac-audit-journal`](https://github.com/Ruaudel-Emmanuel/aac-audit-journal) — suivi des audits et actions |
| 🔧 **Préflight Kopia** | Script backup renforcé (test snapshot avant backup) |
| 🔀 **PRs nettoyées** | 6 PRs deps traitées (0 restante) |
| 📦 **Workflow versionné** | `GitHub-Auditor/workflow/github-auditor.json` |
| 📐 **Règle d'auto** | Principe documenté dans skills : si automatisable → automatisé, pas forcément dans n8n

## 📦 Nouveautés de la session (2026-10-06)

| Ajout | Détail |
|---|---|
| 🤖 **Workflow « Scan ubuntu-latest »** | Workflow n8n cron 05h00, scanne tous les workflows GitHub pour détecter `runs-on: ubuntu-latest`, analyse via Ollama qwen2.5:3b + rapport Telegram |
| 🔧 **CI failures corrigées** | Lock file désynchronisé sur branches `deps/maj-auto-2026-10-05` → `npm install --package-lock-only` + commit push (Lecteur-PDF et construction-site-tracker) |
| 🚧 **Figé sur ubuntu-24.04** | PRs #6 (Lecteur-PDF) et #8 (construction-site-tracker) pour `runs-on: ubuntu-latest` → `ubuntu-24.04` |
| 📝 **Profil GitHub mis à jour** | Projet #7 « Scan ubuntu-latest » ajouté au README du profil Ruaudel-Emmanuel |
| 📦 **Workflows versionnés** | scan-ubuntu-latest exporté dans `rennesdev-vps-ops/workflows/` et `GitHub-Auditor/workflows/` |
| ⬆️ **pi mis à jour** | pi 1.0.0 → 1.0.4

## 📦 Nouveautés de la session (2026-10-07)

| Ajout | Détail |
|---|---|
| 🔄 **Rotation PAT GitHub** | Nouveau PAT détecté dans `.env` — synchronisé aussi dans le Config node de « Push GitHub », snapshot `workflow_history` créé, conteneur n8n redémarré. Test API GitHub ✅ 200 |
| 🔧 **Push GitHub republié** | `activeVersionId` pointé sur le nouveau snapshot, publication outbox traitée, triggers réactivés |
| 📊 **15 workflows n8n** | 14 actifs, 1 brouillon (My Sub-workflow). Dont 5 liés à GitHub (Agent Telegram, GitHub — descriptions auto, GitHub Auditor, Scan ubuntu-latest, Push GitHub) |
| ⚠️ **2 workflows en erreur** | GitHub Auditor (04h00) et Scan ubuntu-latest (03h00) en erreur avant la rotation — à vérifier aux prochains crons (05h00 et 06h00)


---


=== Rotation 2026-10-11 16:00 ===

# 📋 État du VPS rennesdev.fr — État courant
> Journal allégé depuis le 2026-09-14 (rotation, règle n°7) : ce fichier décrit l'état **actuel** uniquement.
> Historique complet archivé dans `ETAT-VPS-ARCHIVE.md`.
> Rotation : les entrées anciennes partent dans l'archive.

## 📌 Infrastructure

| Élément | Valeur |
|---|---|
| **Hébergement** | VPS OVH — Ubuntu 26.04 LTS, 4 vCPU, 7,6 Go RAM, 72 Go disque |
| **IPv4** | 162.19.246.465 (proxy Cloudflare Orange, https, www → 443, Full Strict) |
| **IPv6** | 2001:41d0:701:1100::208c |
| **Tailscale** | `vps-5532a57a` (100.75.226.13) ↔ PC `super-pc-vert` (100.118.76.30) |
| **DNS** | Cloudflare — Caddy 80/443 (ACME Let's Encrypt auto) |
| **Sécurité** | UFW 22/80/443, fail2ban (sshd + recidive), SSH clé uniquement |
| **Conteneurs** | Docker réseau `apps` — 11 conteneurs dont n8n (v2.41.3), Ollama, PG 17/16 |
| **Backups** | Kopia → PC `super-pc-vert:51515` (TLS), dim 19h30 |
| **Timers** | watchdog 15 min, metrics lun 08h00, backup dim 19h30, reminder dim 12h00, daily-journal 23h00 |
| **Canaux** | bot @Vosmanubot (TG_CHAT_ID=8634051625) |

## ⚙️ État Actuel — 2026-10-09 11:30

| Métrique | Valeur |
|---|---|
| **Santé** | ✅ Tout vert |
| **RAM** | 23% |
| **Load** | 0.34 |
| **Disque** | 65% |
| **Uptime** | 7 jours |
| **APT** | 10 paquets en attente |
| **n8n** | v2.41.3 — 16 workflows (9 actifs) |
| **Ollama** | 3 modèles : qwen2.5:7b, qwen2.5:3b, llama3.2:3b |

### Conteneurs Docker

| Conteneur | Statut |
|---|---|
| n8n_workflow | ✅ running |
| n8n_db (PG 17) | ✅ running |
| umami_app + umami_db (PG 16) | ✅ running |
| ollama | ✅ running |
| netdata | ✅ running |
| filebrowser | ✅ running |
| nav_rennesdev | ✅ running |
| uptime_kuma | ✅ running |
| browserless | ✅ running |
| spectre | ✅ running |

### Workflows n8n

| Workflow | Statut | Rôle |
|---|---|---|
| **Agent Github** | ✅ **Actif** | IA GitHub via OpenRouter (gpt-4o-mini). Audit lun 06h00, actions mar 06h00, descriptions ven 07h00. Push rapports sur `GitHub-Auditor/agent-github/` (main) |
| **Agent Telegram** | ✅ Actif | Bot IA (Ollama) + rapport GitHub 07h00 + missions Codeur 14h00 lun-ven |
| **AI Personal Assistant** | ✅ Actif | Assistant rédacteur SMS/Telegram (Ollama local) |
| **Push GitHub** | ✅ Actif | Webhook push GitHub |
| **Diffusion Actus Discord** | ✅ Actif | RSS Airtable → Discord + post LinkedIn |
| **Diffusion Photos Discord** | ✅ Actif | RSS photos → Discord |
| **Scan ubuntu-latest** | ✅ Actif | Scan workflows GitHub |
| **Stripe — alerte paiement** | ✅ Actif | Webhook Stripe |
| **Tally** (×2) | ✅ Actif | Webhooks Tally messages + photographe |
| **Alertes VPS (watchdog)** | ✅ Actif | Watchdog VPS |
| Anciens workflows (×5) | ❌ Inactif | Remplacés/intégrés |

## 📜 Historique des sessions

### 🆕 2026-10-08 — Agent Github + restructuration

| Changement | Détail |
|---|---|
| **🤖 Agent Github (nouveau)** | Agent IA OpenRouter qui remplace GitHub — descriptions auto, GitHub Auditor et Codeur |
| **📅 Planning** | Lundi 06h00 audit → Mardi 06h00 actions correctives → Vendredi 07h00 descriptions |
| **🔗 Codeur → Agent Telegram** | Pipeline Codeur.com intégré dans Agent Telegram (14h00 lun-ven) |
| **🔑 OpenRouter** | Clé API dans `.env`, utilisée par Agent Github |
| **📤 Rapports** | Push sur `Ruaudel-Emmanuel/GitHub-Auditor/agent-github/` |
| **🗑️ Nettoyage** | GitHub Auditor, descriptions auto, Codeur désactivés |
| **🌐 Agent Github v2** | Workflow Agent Github v1 obsolète, v2 fonctionnel avec `finished:true` |

### 🆕 2026-10-09 — Fix Agent Github : Push rapport + Fetch rapport

| Changement | Détail |
|---|---|
| **🐛 Push rapport** | Erreur `"sha" wasn't supplied` (PUT sans SHA sur fichier existant). Nœuds orphelins « SHA main » et « Merge SHA » déconnectés et récupérant le mauvais SHA (commit au lieu du blob) |
| **🔧 Fix SHA** | « SHA main » → « Get file SHA » (GET `/contents/{path}` pour blob SHA). « Merge SHA » → « Handle SHA » (SHA ou null si 404). Connexion rétablie dans le flux |
| **🔧 Fix body** | Body du PUT inclut `{ sha }` si fichier existe déjà (graceful handling des runs multiples) |
| **🐛 Push rapport (2)** | Erreur `request invalid` car `?branch=` vers branche inexistante. Le flux Audit pushait vers `main` mais l'URL contenait `?branch=xxx` (branche jamais créée) |
| **🔧 Fix URL** | Retiré `?branch=` → push vers `main`. Les fichiers sont nommés par date (`audit-YYYY-MM-DD.md`) |
| **🐛 Fetch rapport (mardi)** | Erreur `url parameter must be a string got undefined`. « Lire dernier audit » listait les branches au lieu des fichiers. Aucune branche créée → `$json.url = undefined` |
| **🔧 Fix Actions** | « Lister branches » → « Lister fichiers » (GET `/contents/agent-github/` sur `main`). « Lire dernier audit » parse les noms de fichiers. Si aucun fichier → `throw Error` → sortie error vers Telegram directement |
| **📤 Backup** | Sauvegarde SQL des workflows avant/après : `/tmp/n8n-workflow-backup-avant-fix.sql` |

### 🆕 2026-10-07 — Rotation PAT GitHub

- **🔄 Rotation PAT GitHub** : Nouveau PAT synchronisé dans `.env`, Config node « Push GitHub », snapshot `workflow_history`, conteneur redémarré. Test API ✅ 200
- **🔧 Push GitHub republié** : activeVersionId pointé, outbox traitée, triggers réactivés

### 🆕 2026-10-06 — Scan ubuntu-latest

- **🤖 Nouveau workflow « Scan ubuntu-latest »** : cron 05h00, scanne les workflows GitHub → Ollama qwen2.5:3b → rapport Telegram
- **🔧 CI failures corrigées** : Lock file désynchronisé sur branches deps → `npm install --package-lock-only` + commit push

### 🆕 2026-10-05 — Maintenance AAC

- **🧹 AAC maintenance hebdo** : `aac-weekly-maintenance.timer` — chaque lundi 05h00
- **📋 Journal AAC** : [`aac-audit-journal`](https://github.com/Ruaudel-Emmanuel/aac-audit-journal)

### 🆕 2026-10-01 — Audio Transcriber

- **✅ Audio Transcriber testé et finalisé** : app Windows tkinter (capture → faster-whisper → Ollama → .md)
- **✅ Prompt idéal** : ajouté au README (règle 15)

### 🆕 2026-09-28 — AI Personal Assistant + LinkedIn

- **🔌 Agent n8n branché sur Ollama local** : AI Personal Assistant passe de Gemini cloud → Ollama qwen2.5:7b local
- **✅ LinkedIn automatique** : Diffusion Actus Discord génère un post LinkedIn par actu via Ollama

### 🆕 2026-09-27 — Mise à jour n8n 2.41

- **⬆️ n8n 2.41.3** : 4 workflows dé-publiés par la migration → réparés (snapshot + outbox)
- **📦 Workflows versionnés** : exports dans `rennesdev-vps-ops/workflows/`
- **📝 15 workflows documentés** dans inventaire n8n-ops

### 🆕 2026-09-26 — Airtable + GitHub

- **📊 Airtable** : quota 1 000/mois, optimisation économe (dédup groupée, cache 12h, pause 24h sur 429)
- **🔧 GITHUB_PAT** : variable d'env centralisée + `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`

### 🆕 2026-09-25 — GitHub

- **🐙 Push GitHub** : webhook `/webhook/github-push` — push de fichiers vers GitHub via script shell
- **📊 GitHub — descriptions auto** : quotidien 07h45 + hebdo lun 22h00
- **📊 Codeur — missions du jour** : RSS → Ollama → Telegram (14h00 lun-ven)

### 🆕 2026-09-19 — ÉCLAIREUR

- **📖 ÉCLAIREUR** : webhook `/webhook/eclaireur`, lecture de page web → Ollama résumé

### 🆕 2026-09-17 — Stripe + Tally

- **💳 Stripe** : webhook `/stripe-paiement` → alerte Telegram
- **📋 Tally** : webhooks `/tally-alerte` et `/tally-photographe` → alerte Telegram

### 🆕 2026-09-14 — Discord

- **📢 Diffusion Actus/Photos Discord** : RSS Airtable → Discord (3×/jour)

### 🆕 2026-09-12 — VPS Watchdog

- **🛡️ Watchdog VPS** : vps-watchdog.timer (15 min) + vps-tgbot
- **✅ Reverse proxy Caddy** : umami, n8n, uptime, nav, fichiers, spectre

### 🆕 2026-09-11 — Base

- **🚀 Démarrage n8n** : AI Personal Assistant, Agent Telegram, Push GitHub
- **🐳 Ollama + Browserless** : conteneurs dédiés
- **📊 Netdata** : monitoring système

## 🔴 Anomalies

| Anomalie | Statut | Détail |
|---|---|---|
| Kopia — dépôt déconnecté | ⚠️ Attendu | PC super-pc-vert inaccessible (port 51515 fermé si PC éteint) |
| Dernier backup réussi | 2026-10-04 | Snapshot Kopia OK |
=== Rotation 2026-10-11 16:00 === — fin

---
=== Rotation 2026-10-16 09:49 === — fin
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

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.43.4, pi agent v1.2.0, Ollama, Browserless, FileBrowser, Netdata, Uptime‑Kuma, Nav.rennesdev, SPECTRE, Umami (app+db). PG 17 pour n8n, PG 16 pour Umami.

**Ollama** — modèles : qwen2.5:7b (bot IA), qwen2.5:3b (analyses), llama3.2:3b. `OLLAMA_KEEP_ALIVE=10m`.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30 (rappel 12h00). Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, metrics 📊 lun 08:00, ollama-unload 🧠 19:15, backup 💾 dim 19:30, backup-reminder 🔔 dim 12:00, github-weekly 📈 ven 19:00, daily-journal 📝 23:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel
**Date** : Jeu 15 Oct 2026, 12:33 UTC (14:33 Paris)
**Uptime** : 13j 2h02 | **Load** : 0.07 | **RAM** : 1.9/7.6 Go (25%) | **Disque** : 51/72 Go (72%)

**Global** : ✅ VPS stable. APT à jour, n8n 2.43.6, pi agent 1.2.0.

⚠️ RAM 25% — Ollama déchargé. Normal (pas de run Agent Github aujourd'hui).

**Fail2ban** : 470 bans sshd (0 actifs), 2 recidive (0 actifs).
**Timers** : 7/7 actifs (dont watchdog ⏱ 15 min).

## 🐳 Services Docker
> Réseau `apps` — 11 conteneurs, tous Up

| Conteneur | Image | Port interne | Santé |
|---|---|---|---|
| `n8n_workflow` | n8nio/n8n:2.43.6 | 127.0.0.1:5678 | ✅ Up |
| `n8n_db` | postgres:17-alpine | (interne 5432) | ✅ Up healthy |
| `ollama` | ollama/ollama:latest | 127.0.0.1:11434 | ✅ Up |
| `umami_app` | ghcr.io/umami-software/umami:postgresql-latest | 127.0.0.1:3000 | ✅ Up |
| `umami_db` | postgres:16-alpine | (interne 5432) | ✅ Up |
| `netdata` | netdata/netdata:latest | 127.0.0.1:19999 | ✅ Up healthy |
| `filebrowser` | filebrowser/filebrowser:v2 | 127.0.0.1:8085 | ✅ Up healthy |
| `nav_rennesdev` | node:22-alpine | 127.0.0.1:8086 | ✅ Up |
| `uptime_kuma` | louislam/uptime-kuma:1 | 127.0.0.1:3001 | ✅ Up healthy |
| `browserless` | ghcr.io/browserless/chromium:latest | 127.0.0.1:3100 | ✅ Up |
| `spectre` | spectre-spectre | 127.0.0.1:8087 | ✅ Up |

**Ollama modèles** : qwen2.5:7b, qwen2.5:3b, llama3.2:3b
**Caddy** : v2.11.7 | **Docker Compose** : v2.40.3 | **OS** : Ubuntu 26.04.1 LTS

## 📋 Travaux du 12/10/2026

### 🔧 Workflow Agent Github — refactoring complet
Le workflow « Agent Github » (id `67ca20bb...`) a été entièrement restructuré :

| Étape | Action |
|---|---|
| **1. Table `rapports_audit`** | Créée dans la base `n8n` (PostgreSQL 17) pour stocker les rapports d'audit du lundi |
| **2. INSERT PostgreSQL** | Ajout d'un nœud `Extraire données PG` + `PG: Insérer audit` sur la branche du lundi |
| **3. SELECT PostgreSQL** | Le déclencheur du mardi lit `SELECT analyse_md FROM rapports_audit ORDER BY date_audit DESC LIMIT 1` au lieu de l'API GitHub |
| **4. OpenRouter → Ollama** | Remplacement des 3 appels HTTP OpenRouter (GPT-4o-mini) par **1 AI Agent unique** + **Ollama qwen2.5:7b** local |
| **5. Memory Postgres** | Ajout de `Postgres Chat Memory` (session `agent-github-main`) |
| **6. Contexte + routage** | 1 nœud `Préparer contexte` détecte le trigger (Mon/Tue/Fri) et définit le `systemMessage` dynamique. 1 nœud `Router sortie` aiguille vers les actions GitHub. |
| **7. Nœuds supprimés** | 8 nœuds supprimés → workflow propre de 25 nœuds |

### 🆕 Repo GitHub `Agent-Github`
- Créé : [`Ruaudel-Emmanuel/Agent-Github`](https://github.com/Ruaudel-Emmanuel/Agent-Github)
- Contenu : `README.md` + `workflow/agent-github.json` (export complet du workflow)
- Privé, auto-init, issues activées

### 🔧 vps-daily-journal — corrigé
- `git diff --cached` retiré dans git 2.53 → remplacé par `git status --porcelain`
- `export HOME=/root` ajouté
- 20 journaux en attente commités + pushés (`7714e4e`)

### 🛑 aac-weekly-maintenance — arrêté
- Timer + service masqués. Script Python d'export workflow en échec.

### 📦 APT & n8n — mises à jour appliquées le 12/10/2026
- **APT** : 15 paquets mis à jour (Caddy 2.11.6→2.11.7, OpenSSH 10.2p1-3.6→3.7, Tailscale 1.102.4→1.104.1, alsa-ucm-conf, glycin*, libx11-6, open-iscsi). **0 paquets en attente.**
- **n8n** : 2.41.7 → **2.42.7** (image pullée, compose patché, conteneur recréé).

### 🗄️ Premier audit fondateur PostgreSQL
- Audit initial inséré dans `rapports_audit` (id=1, 2026-10-12, 62 repos, 2 282 chars markdown).
- Requête du mardi `SELECT analyse_md FROM rapports_audit ORDER BY date_audit DESC LIMIT 1` retourne désormais un vrai rapport.

### 🔧 Agent Github — 3 bugs corrigés
**Bug 1 — Postgres Chat Memory (sessionId manquant)**
- `parameters: {}` → ajout `sessionKey=sessionId` + `sessionId=agent-github-main`
- Connexion AI Agent fixée (`ai_memory → sessionMemory`)

**Bug 2 — Topologie chaînée (GitHub → PG → Filtre → Contexte)**
- Le lundi, les repos GitHub étaient remplacés par l'audit PG, puis Filtre dropait les champs → `"Aucun dépôt actif à auditer."`
- **Nouvelle topologie** :
  - **Lundi (audit)** : ⏰ Audit → GitHub: Liste repos → **Filtre: sans desc** (annotate) → **Préparer contexte** (CAS 3 lit via `$('GitHub: Liste repos')`) → AI Agent
  - **Mardi (actions)** : ⏰ Actions → **PG: Lire dernier audit** → **Préparer contexte** (CAS 2 lit analyse_md) → AI Agent
  - **Vendredi (descriptions)** : ⏰ Descriptions → GitHub: Liste repos → **Filtre: sans desc** (needs_description flag) → **Préparer contexte** (CAS 1 check besoins) → AI Agent
- Filtre: sans desc ne filtre plus : annotte tous les repos avec `needs_description: !r.description`

**Bug 3 — Router sortie envoyait l'audit à toutes les branches**
- `Creer issue GitHub` recevait l'audit du lundi → 404 `repos//issues`
- Parse issues: `if (action !== 'actions') return []`
- Clean + PATCH: `if (action !== 'descriptions') return null`
- Le mardi et vendredi ne sont pas encore testés (les crons feront le test à leurs heures).

### 🔴 1. spectre.rennesdev.fr — DNS NXDOMAIN → 📦 Archivé le 12/10/2026
- ~~Le domaine `spectre.rennesdev.fr` ne résout pas (NXDOMAIN).~~
- ~~Le conteneur tourne bien sur `127.0.0.1:8087`, le bloc Caddy est configuré.~~
- ~~**Cause probable** : enregistrement DNS manquant sur Cloudflare → à créer (proxy orange, www → 443).~~
- **Action** : archivé à la demande. Le conteneur reste UP localement, le service est fonctionnel en direct. L'enregistrement DNS Cloudflare reste à créer quand nécessaire.

### 🔴 2. Kopia — dépôt déconnecté
- `kopia repository not connected` — impossible de lister les snapshots.
- Le PC `super-pc-vert` est en ligne via Tailscale (ping OK), mais le port 51515 ne répond pas (timeout).
- **Cause probable** : Kopia server pas lancé sur le PC, ou firewall Windows bloque.
- **Note utilisateur** : pas de sauvegarde aujourd'hui ni dimanche prochain (PC éteint).
- Dernier backup hebdo connu : dimanche 11/10 (18h).

### ⚠️ 3. vps-daily-journal.service — échec chronique 🔧 Corrigé le 12/10/2026
- **Cause racine** : `git diff --cached` retiré dans git 2.53. Combiné à un accès système sans `export HOME=/root`, git ne trouvait pas la config `safe.directory = *`.
- 20 journaux (22/09 → 11/10) accumulés en staging → commités + push via `7714e4e`.
- **Correctifs** : `export HOME=/root` + `git diff --cached` → `git status --porcelain | wc -l`.

### ⚠️ 4. aac-weekly-maintenance.service — échec → 🛑 Arrêté le 12/10/2026
- Échoué le 12/10 à 03:02. Log dans `/var/log/aac-weekly-maintenance.log`.
- Le PAT est extrait (93 car.), l'export du workflow GitHub Auditor commence mais le script Python échoue silencieusement (probablement un problème de subprocess ou de parsing JSON).
- **Action** : timer + service stoppés et masqués (`systemctl mask`). La maintenance hebdo AAC est suspendue.

### ✅ 5. APT — à jour (15 paquets mis à jour le 12/10)
Caddy 2.11.7, OpenSSH 10.2p1-3.7, Tailscale 1.104.1, glycin*, libx11*, open-iscsi, etc. **0 paquets en attente.**

### ℹ️ Bruteforce SSH
- 4 IP actuellement bannies (sshd) + 1 (recidive). Activité constante mais contenue par fail2ban.

## 📋 Travaux du 13/10/2026

### 🔧 pi agent — mise à jour 1.0.4 → 1.2.0
- Mise à jour via `npm install -g @earendil-works/pi-coding-agent --prefix=$HOME/.local`
- Version 1.2.0 désormais active.

### 🔧 n8n — mise à jour 2.42.7 → 2.43.4
- **Sauvegarde** : `~/n8n-db-avant-MAJ-20261013-124825.sql.gz` (5,1 Mo) via `pg_dump`
- **Image** : `~/docker-compose.yml` épinglée `n8nio/n8n:2.42.7` → `n8nio/n8n:2.43.4`
- **Pull + recreate** : `docker compose pull && docker compose up -d --no-deps --force-recreate n8n_workflow`
- **Vérification** : migrations DB OK, tous les triggers activés, webhooks fonctionnels, zéro erreur au démarrage.

### 🔧 Agent Github — routage post-AI Agent (Switch → Filtres)

**Problème :** Le workflow passait l'AI Agent mais le Switch ne routait pas les sorties.

**Causes :**
- Les conditions du Switch comparaient des littéraux (`"date" == "lundi"`) au lieu d'expressions
- Le champ `action` (audit/descriptions/actions) défini par Préparer contexte était perdu après l'AI Agent
- Les nœuds Clean+PATCH et Parse issues référençaient `$('Router sortie')` qui n'existait pas

**Correctifs appliqués :**

| Nœud | Action |
|---|---|
| **Router sortie** | Créé — préserve `action` + `full_name`/`name` depuis Préparer contexte + `content` (réponse LLM) |
| **Switch** | **Remplacé** par 3 **Filtres** (plus fiables que le Switch avec expressions) |
| **Filtre audit** | Nouveau — `$json.action == "audit"` → Format audit |
| **Filtre descriptions** | Nouveau — `$json.action == "descriptions"` → Clean+PATCH |
| **Filtre actions** | Nouveau — `$json.action == "actions"` → Parse issues |
| **Clean+PATCH** | Réécrit — fallbacks pour `full_name`/`name` |
| **Parse issues** | Réécrit — extraction JSON robuste (regex + fallback) |
| **Format audit** | Réécrit — lit `$json.content` au lieu de l'ancien format |

**Topologie finale :**
```
AI Agent → Router sortie
  ├→ Filtre audit       → Format audit → Format rapport MD → PG → Telegram
  ├→ Filtre descriptions → Clean+PATCH → GitHub PATCH → Recap desc → Telegram
  └→ Filtre actions     → Parse issues → Creer issue GitHub → Telegram
```

**Déploiement :**
- 6 versions successives du workflow (éditions SQL directes dans `workflow_entity` + `workflow_history`)
- Publication via outbox (version active : 9e40cf79 → a559b83a → 11a87191)
- Branch GitHub : `feat/routage-agent-unique`
- README mis à jour avec la section architecture (Option 1 — AI Agent unique + structuration JSON)

## 📋 Travaux du 14/10/2026

### 🔧 Agent Github — refonte complète en workflow unique quotidien

Le workflow « Agent Github » a été repensé pour fonctionner avec **1 seul déclencheur quotidien** au lieu de 3 (lun/mar/ven) :

| Changement | Détail |
|---|---|
| **1 seul trigger** | `⏰ Quotidien (06h00)` cron `0 6 * * *` |
| **IA Agent décide** | L'Agent choisit `[AUDIT]` ou `[MAINTENANCE]` via system prompt |
| **Router sortie supprimé** | Remplacé par `Parse sortie IA` qui lit le tag sur la 1ʳᵉ ligne |
| **Descriptions auto supprimées** | Nœuds `Filtre: sans desc`, `Clean+PATCH`, `GitHub: PATCH`, `Recap desc` retirés |
| **Push GitHub-Auditor** | Nouveau nœud `GitHub: Push file` → pushe le rapport sur `Ruaudel-Emmanuel/GitHub-Auditor` |
| **SHA conditionnel** | `GitHub: Get SHA` + `Prepare push payload` — gère création ET mise à jour du fichier |
| **Audit + Maintenance en 1 run** | Après audit, `AI Agent Maintenance` enchaîne avec les actions de maintenance dans la même exécution |
| **2 nœuds Ollama** | 1 par Agent (même modèle qwen2.5:7b, pas de RAM supplémentaire — séquentiel) |

**Topologie finale (26 nœuds) :**
```
⏰ Quotidien (06h00)
  ↓
GitHub: Liste repos → PG: Lire dernier audit
  ↓
Préparer contexte → AI Agent 1
  ↓ Parse sortie IA 1
  │
  ├─ [AUDIT] → Format audit → Format rapport MD → Get SHA
  │             → Prepare payload → Push file → Extraire PG
  │             → PG: Insérer audit → Telegram (📨 audit)
  │                                   ↓
  │                        Prepare maintenance
  │                             ↓
  │                        AI Agent 2 (Ollama 2)
  │                             ↓
  │                        Parse output 2 → Filtre maintenance
  │                                            ↓
  │                                       Parse issues → Creer issue → Telegram
  │
  └─ [MAINTENANCE] direct → Filtre maintenance → Parse issues → Creer issue → Telegram
```

### 🐛 Bugs corrigés
- **422 SHA manquant** : Ajout d'une étape GET SHA avant le PUT GitHub Contents
- **Conflit ai_languageModel** : 2 nœuds Ollama distincts (1 par Agent)
- **ORDRES.md nettoyé** : Traces d'erreur de test archivées

## 📋 Travaux du 15/10/2026

### 🔧 n8n — mise à jour 2.43.4 → 2.43.6
- **Sauvegarde** : `~/n8n-db-avant-MAJ-20261014-113119.sql.gz` (6,0 Mo) via `pg_dump`
- **Image** : `~/docker-compose.yml` épinglée `n8nio/n8n:2.43.4` → `n8nio/n8n:2.43.6`
- **Pull + recreate** : `docker compose pull && docker compose up -d --no-deps --force-recreate n8n_workflow`
- **Vérification** : migrations DB OK, zéro erreur au démarrage

### 🔧 README GitHub-Auditor — repositionnement produit
- **README.md** : réécrit en anglais avec positionnement produit (value proposition, segments cibles, bénéfices)
- **README-FR.md** : créé — version française complète
- **Structure** : problème → solution → bénéfices uniques → segments → installation 5 min → exemple → privacy
- **Commit** : pushé sur `Ruaudel-Emmanuel/GitHub-Auditor` (main)

### 🔧 README Agent-Github — traduction anglaise + architecture à jour
- **README.md** : traduit en anglais et mis à jour avec l'architecture single-trigger du 14/10/2026
- **Commit** : pushé sur `Ruaudel-Emmanuel/Agent-Github` (main)

### 🔧 Workflow Agent Github — GitHub: Get SHA gère 404 (Code node)
- **Problème** : `GitHub: Get SHA` (httpRequest) échouait en 404 quand le fichier d'audit n'existait pas encore → chaîne bloquée → Telegram jamais atteint
- **Correctif** : remplacé par un **Code node** avec `try/catch` : 404 → `{ sha: null }` → PUT crée le fichier
- **Publication** : DB modifiée (workflow_entity + workflow_history + outbox), n8n restarté, workflow activé
- **Export** : `workflow/agent-github.json` mis à jour sur le repo

### 📣 Diffusion GitHub-Auditor
- **Issue #2** créée sur le repo : annonce publique « show and tell »
- **Post LinkedIn** : rédigé et envoyé sur Telegram (prêt à copier-coller)
- **Post n8n community** : rédigé et sauvegardé (prêt à poster sur community.n8n.io)

### 🧠 Nouveau skill créé : positionnement-readme
- **Fichier** : `/home/ubuntu/.agents/skills/positionnement-readme/SKILL.md`
- **Contenu** : méthode complète pour positionner un README comme une page produit, ciblage audience en 4 segments, template de structure, 5 canaux de diffusion, checklist de publication

=== Rotation 2026-10-16 09:49 === — fin

=== Rotation 2026-10-18 16:00 ===

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

**Services conteneurisés** (réseau Docker `apps`) : n8n v2.43.6, pi agent v1.2.0, Ollama, Browserless, FileBrowser, Netdata, Uptime‑Kuma, Nav.rennesdev, SPECTRE, Umami (app+db). PG 17 pour n8n, PG 16 pour Umami.

**Ollama** — modèles : qwen2.5:7b (bot IA), qwen2.5:3b (analyses), llama3.2:3b. `OLLAMA_KEEP_ALIVE=10m`.

**Backups** — Kopia → PC (super-pc-vert:51515, TLS). Hebdo dimanche 19h30 (rappel 12h00). Stocke volumes docker + /home/ubuntu + /etc/caddy.

**Timers** (Europe/Paris) : vps-watchdog ⏱ 15 min, metrics 📊 lun 08:00, ollama-unload 🧠 19:15, backup 💾 dim 19:30, backup-reminder 🔔 dim 12:00, github-weekly 📈 ven 19:00, daily-journal 📝 23:00.

**Fichiers suivis** : `ETAT-VPS-ARCHIVE.md` (historique), `ORDRES.md` (ordres Telegram), `~/projects/rennesdev-vps-ops/` (doc ops + workflows + scripts).

**Canaux** : bot @Vosmanubot (TG_CHAT_ID=8634051625).

## ⚙️ État Actuel
**Date** : Jeu 16 Oct 2026, 09:50 UTC (11:50 Paris)
**Uptime** : 13j 23h18 | **Load** : 0.39 | **RAM** : 2.1/7.6 Go (28%) | **Disque** : 52/72 Go (72%)

**Global** : ✅ VPS stable. Dernier backup Kopia OK il y a 0h.

⚠️ RAM 28% — Ollama modèles chargés ? Normal.
⚠️ `spectre.rennesdev.fr` : 000 (attendu 401) — DNS non configuré, service archivé.

**Fail2ban** : 494 bans sshd (0 actifs), 2 recidive (0 actifs).
**Timers** : 6/6 actifs (dont watchdog ⏱ 15 min).
**APT** : 5 paquets en attente (open-vm-tools, python3-distupgrade, snapd, tzdata, ubuntu-release-upgrader-core).

## 🐳 Services Docker
> Réseau `apps` — 11 conteneurs, tous Up

| Conteneur | Image | Santé |
|---|---|---|
| `n8n_workflow` | n8nio/n8n:2.43.6 | ✅ Up |
| `n8n_db` | postgres:17-alpine | ✅ Up healthy |
| `ollama` | ollama/ollama:latest | ✅ Up |
| `umami_app` | ghcr.io/umami-software/umami:postgresql-latest | ✅ Up |
| `umami_db` | postgres:16-alpine | ✅ Up |
| `netdata` | netdata/netdata:latest | ✅ Up healthy |
| `filebrowser` | filebrowser/filebrowser:v2 | ✅ Up healthy |
| `nav_rennesdev` | node:22-alpine | ✅ Up |
| `uptime_kuma` | louislam/uptime-kuma:1 | ✅ Up healthy |
| `browserless` | ghcr.io/browserless/chromium:latest | ✅ Up |
| `spectre` | spectre-spectre | ✅ Up (DNS non configuré — archivé) |

**Ollama modèles** : qwen2.5:7b, qwen2.5:3b, llama3.2:3b
**Caddy** : v2.11.7 | **Docker Compose** : v2.40.3 | **OS** : Ubuntu 26.04.1 LTS

## 📋 Travaux du 16/10/2026

### 🔧 Sauvegarde Kopia — déclenchée manuellement
- **Commande** : `sudo /usr/local/bin/kopia-backup.sh`
- **Résultat** : ✅ 4 snapshots créés (staging, volumes docker, /home/ubuntu, /etc/caddy) en ~1 min
- **Dernier snapshot** : 2026-10-16 09:43:17 UTC, 10.9 GB, files:4003 dirs:113

### 🔧 ETAT-VPS.md — rotation archivage + nouveau
- Ancien état archivé dans `ETAT-VPS-ARCHIVE.md` (rotation 2026-10-16 09:50)
- Nouvel état créé avec les données fraîches du healthcheck
=== Rotation 2026-10-18 16:00 === — fin

=== Rotation 2026-10-23 15:47 ===

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

=== Rotation 2026-10-23 15:47 — fin ===
