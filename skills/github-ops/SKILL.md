---
name: github-ops
description: Tout ce qui concerne GitHub sur le VPS rennesdev.fr — PAT, push sans secret, workflows d'automatisation (descriptions, dépendances/PR, rapport hebdo, radar cadence), inventaire des dépôts. Utiliser dès qu'on parle de GitHub, PR, PAT ou des workflows n8n liés à GitHub.
---

# GitHub — mémoire opérationnelle

## Règles de gestion des repos (ordre utilisateur 19/09)
- **1 projet = 1 repo** dédié (jamais un sous-dossier d'un repo existant) — ex. `Nav.rennesdev` a son propre repo.
- **Améliorer un projet = nouvelle branche** dédiée dans le repo du projet (pas de commit direct sur main pour les évolutions).
- **Toutes les améliorations = commits commentés** (messages explicites).
- **Vision (ordre 21/09)** : dynamique sans excès, autonomie maximale, attractif pour recruteurs sans travail phénoménal — toute automatisation doit ajouter de l'activité réelle et régulière, jamais du bot-spam cosmétique.

## PAT (token)
- Emplacement : base n8n (conteneur `n8n_db`, **nom de base = `n8n`** — piège : `-d n8n_db` échoue, POSTGRES_DB=n8n ; POSTGRES_USER=n8n), workflow **« Push GitHub »** → nœud **« Config (PAT GitHub) »** (assignments[0].value de `nodes[1]`). C'est l'unique source ; les autres nœuds/workflows y font référence.
- **Jamais affiché en session** : extraction en variable shell du curl, jamais sur disque ni dans le journal. ⚠️ Affiché par erreur 3 fois en 2026-09-18 et une 4e fois le **21/09** (git pull avec URL mal formée — sans hôte — sortie d'erreur avec token) → **rotation à la prochaine occasion** : l'utilisateur génère un nouveau token fine-grained (vérifier qu'il commence par `github_pat_` ou `ghp_`, permissions : Contents RW + Pull requests RW + Administration RW pour créer des repos), le colle dans « Push GitHub » → nœud Config, puis l'assistant le propage par SQL (jamais affiché) vers « GitHub — descriptions auto » et « Agent Telegram ». **Piège d'URL git : toujours vérifier que le push/pull contient bien `@github.com/<owner>/<repo>.git`** — un `https://x-access-token:<token>` sans hôte rejette avec le token dans le message d'erreur.
- Piège : modifier le cron/code depuis un fichier local périmé peut réécrire l'ANCIEN token en base — toujours recharger l'état frais depuis la DB avant écriture.

## Push sans secret (méthode standard, règle n°2)
```
curl -s -X POST https://n8n.rennesdev.fr/webhook/github-push \
  -H 'Content-Type: application/json' \
  -H "X-Auth-Token: $PAT" \
  -d '{"repo":"Nom","path":"dir-sous-projects","message":"...","branch":"main","private":true}'
```
- Webhook → nœud Config (PAT) → If (X-Auth-Token == PAT) → Code → ExecuteCommand `/home/ubuntu/projects/scripts/github-push.sh` (monté `/home/ubuntu/projects:/projects`).
- Le script **crée le repo s'il n'existe pas** (privé/public), clone si besoin, commit+push. Token jamais persisté dans `.git/config`. Doc : `~/projects/rennesdev-vps-ops/docs/push-github.md`.

## Workflows d'automatisation (dans n8n)
| Workflow | Déclencheur | Rôle |
|---|---|---|
| « Push GitHub » | Webhook | push/création repos (ci-dessus) |
| « GitHub — descriptions auto » | cron **07:45 Paris** + **lun 22h00** (deps) | génère les descriptions de repos (PATCH) ; nœud deps : branche `deps/maj-auto-<date>` + **PR automatique** |
| « Agent Telegram » | cron **07:00 Paris** | rapport quotidien repos + radar cadence + conseils IA |
| `github-weekly.timer` | **ven 19h00 Paris** | rapport hebdo (API `/users/<login>/events` — ⚠️ `/user/events` = 404 avec PAT fine-grained) → repo `git-ops-journal/semaines/` + récap Telegram |

- Dépendances : détection `package.json`/`requirements.txt` via API Git tree, versions npm/PyPI (préversions ignorées), préversions `^`/`~` préservées, branche créée via API Git (blob→tree→commit→ref), `main` jamais touché.
- Pièges connus : `httpRequest({json:false})` auto-parse les JSON (pas de `JSON.parse` sur un objet) ; `encodeURIComponent` casse les packages npm scopés ; champ cron n8n = `expression` (pas `cronExpression`) ; nœud en mode all-items → pairing vers 1 seul item (utiliser `runOnceForEachItem` dans `parameters.mode`).

## Radar de cadence (dans « Agent Telegram »)
- NIVEAU1 (7 j) : rennesdev, rennesdev-vps-ops, RuaudelEmmanuel.github.io, RuaudelPhoto.
- NIVEAU2 (14 j) : Rennesdev-api, Fiscale-vps, Trombi, construction-site-tracker, Besoin-visio, local_contextual_ai, ai_gemma_service, surveillance-tarifaire.

## CI, rulesets & templates (mis en place 21/09)
- **Review solo impossible** : GitHub refuse l'auto-approval de ses propres PR → la protection de main passe par des **checks CI requis** + `allow_auto_merge` (dépôt PATCH) au lieu de « 1 review approuvée ».
- **Ruleset `construction-site-tracker`** (id 23667839) : cible `~DEFAULT_BRANCH` (⚠️ PAS `~ALL` — avec checks requis, `~ALL` bloque même les push de branches de travail), règles = `deletion` + `non_fast_forward` + `required_status_checks` (contexte `build`, integration_id 15368 = GitHub Actions). Ruleset doit exister déjà (PUT = update OK ici ; l'ancien PATCH 404 du 18/09 venait d'un problème de droits/état).
- **CI Android (construction-site-tracker)** : `.github/workflows/ci.yml` — checkout → JDK 21 (temurin) → **Node 22** (⚠️ Capacitor 8 exige ≥ 22) → cache Gradle (`gradle/actions/setup-gradle@v4`) → `npm ci` (⚠️ échoue si lock désynchronisé avec package.json — régénérer avec `npm install`) → **`npx cap sync android`** (génère `capacitor-cordova-android-plugins` et les assets web, gitignés) → `./gradlew assembleDebug`. Le build debug ne dépend pas du keystore (guard `exists()`).
- **minSdk 24** (plugin Camera ioncamera 1.0.2) — changement fonctionnel du 21/09, s'applique au prochain build release.
- **CI Lecteur-PDF (21/09)** : même gabarit, ruleset 23774769 (check `build` requis) + auto-merge. **Piège supplémentaire** : `org.gradle.java.home=<chemin VPS>` commité dans `android/gradle.properties` → invalide sur les runners → **ne jamais commiter le chemin Java du VPS**, laisser setup-java fournir le JDK.
- **Deps auto** : le nœud deps de « GitHub — descriptions auto » scanne **dynamiquement** `/user/repos` (non-archivés) + `package.json`/`requirements.txt` → tout nouveau repo est couvert automatiquement.
- **Autre habitude prise** (règle 13) : à chaque tâche récurrente, se demander « peut-on l'automatiser ? » — si oui, automatiser.
- **Pipeline incident → issue (21/09)** : script `/usr/local/bin/vps-issue.sh` (root 700, repo ops `scripts/`) — `open`/`close`/`close-prefix`, PAT extrait de la base n8n en variable shell, `jq` pour payloads, dédoublonnage par titre + retry. Le **watchdog** ouvre une issue « Watchdog VPS : … » par alerte fraîche et clôt automatiquement les issues watchdog ouvertes quand il redevient vert (close-prefix). Le **journal quotidien** ouvre une issue sur push échoué et la clôt au push réussi. Défaut : repo `rennesdev-vps-ops`, label `incident` (créé au besoin). Issues désactivées par défaut sur les repos → PATCH `has_issues: true`.
- **Rapport hebdo** (github-weekly-report.sh) : section « Suggestions d'issues roadmap » = repos actifs silencieux ≥ 21 j (calcul sur `pushed_at`), suggestion prête à copier.
- **Templates GitHub** mergés sur Nav.rennesdev, Lecteur-PDF, construction-site-tracker : `.github/ISSUE_TEMPLATE/` (bug.yml, idee.yml, config.yml blank_issues_enabled: false) + `PULL_REQUEST_TEMPLATE.md` (checklist CI/doc/secret). À déployer sur les autres repos actifs si demandé.
- **À venir (phase B)** : workflow n8n « alerte VPS → issue GitHub » (watchdog, push échoué, journal) avec auto-close par le commit de fix ; radar de cadence → suggestion d'issue roadmap.

## Inventaire & hygiène
- 97 dépôts → **79 archivés** (15/09), **18 actifs** conservés. Doublons historiques : Fiscale-vps/Fisclale-vps/Fiscale_vps, Devis-Python/Devis-Python-Steamlit.
- Repos récents : `Lecteur-PDF` (18/09), `VPS-Rennesdev.fr` (journal VPS, timer quotidien 23h), `git-ops-journal` (gestion du compte + automatisations), `construction-site-tracker` (Suivi Interventions, Play Store).
- Ruleset : certains repos exigent une **PR approvée** pour merger sur main (pas de push direct) → pousser sur une branche + PR.
- Releases GitHub : API `POST /repos/<login>/<repo>/releases` puis upload assets sur `uploads.github.com` (PAT en variable shell).

## Anonymat (règle permanente)
Aucun secret/identifiant dans les contenus commités (grep de vérification avant push). Le nom des repos peut contenir le domaine (choix utilisateur), le contenu est anonymisé.
