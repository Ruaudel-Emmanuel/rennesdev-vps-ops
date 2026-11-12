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
- **Centralisation (mise en place 26/09)** : source unique pour les **nœuds de workflow n8n** = variable d'env **`GITHUB_PAT`** (`~/.env` + compose, lue via `$env.GITHUB_PAT` dans les nœuds Code et `=Bearer {{ $env.GITHUB_PAT }}` dans les headers httpRequest — voir skill `n8n-ops`). Les **5 anciennes copies inline** des nœuds ont été supprimées.
- **Seconde source, distincte (scripts shell)** : le Config node **« Config (PAT GitHub) »** du workflow **« Push GitHub »** (base n8n, conteneur `n8n_db`, **nom de base = `n8n`** — piège : `-d n8n_db` échoue, POSTGRES_DB=n8n ; POSTGRES_USER=n8n), assignments[0].value de `nodes[1]`. C'est ce que lisent les scripts `github-push.sh` / `vps-issue.sh` (extraction SQL). → **2 sources à tenir synchronisées** lors d'une rotation : `~/.env` GITHUB_PAT **et** le Config node du workflow Push GitHub.
- **Credential n8n `githubApi`** testée invalide (401) et **supprimée le 26/09** — ne pas la recréer pour les httpRequest.
- **Jamais affiché en session** : extraction en variable shell du curl, jamais sur disque ni dans le journal. ⚠️ Affiché 4 fois en septembre (18/09 ×3, 21/09) → **ROTATION EFFECTUÉE le 21/09** : l'utilisateur a collé le nouveau token dans « Push GitHub », propagation SQL aux 5 occurrences (« GitHub — descriptions auto » ×3, « Agent Telegram » ×1) + snapshot `workflow_history` + `activeVersionId` + restart n8n ; ancien token (complet) vérifié absent des 3 workflows ; test push réel OK. Procédure complète : `docs/push-github.md` du repo ops. **✅ Ancien token révoqué le 21/09 — rotation close.** Leçon d'URL : un `https://x-access-token:<token>` sans `@github.com/...` rejette avec le token dans le message — toujours vérifier l'URL complète.
- Piège : modifier le cron/code depuis un fichier local périmé peut réécrire l'ANCIEN token en base — toujours recharger l'état frais depuis la DB avant écriture.
- **⚠️ Réflexe post-rotation (incident 22/09)** : la propagation du 21/09 a été écrasée par une écriture postérieure → les workflows deps/Agent Telegram sont repassés à l'ancien token (401 silencieux). Après TOUTE rotation, **vérifier** : (a) `~/.env` GITHUB_PAT est à jour + restart conteneur ; (b) le Config node de « Push GitHub » est à jour ; (c) un `grep github_pat_` dans les workflows → 0 occurrence inline attendue hors Config node. Test API : `/user/repos` avec le PAT courant doit renvoyer 200 (401 = token mort).

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
- **⚠️ PR deps + lockfile (incident 27/09, PR #4 Lecteur-PDF)** : le nœud deps de « GitHub — descriptions auto » bump `package.json` via l'API mais **ne régénère pas `package-lock.json`** → `npm ci` en CI échoue en EUSAGE (« lock file's X does not satisfy Y »). Correctif : `npm install --package-lock-only` sur la branche deps + push → CI verte → auto-merge déclenché automatiquement. À chaque PR deps sur un repo npm avec lock commité : vérifier la synchro lock ↔ package.json avant de laisser tourner l'auto-merge. (Piste d'amélioration : faire régénérer le lock par le nœud deps via ExecuteCommand — non implémenté.)
- **Deps auto** : le nœud deps de « GitHub — descriptions auto » scanne **dynamiquement** `/user/repos` (non-archivés) + `package.json`/`requirements.txt` → tout nouveau repo est couvert automatiquement.
- **Autre habitude prise** (règle 13) : à chaque tâche récurrente, se demander « peut-on l'automatiser ? » — si oui, automatiser.
- **Pipeline incident → issue (21/09)** : script `/usr/local/bin/vps-issue.sh` (root 700, repo ops `scripts/`) — `open`/`close`/`close-prefix`, PAT extrait de la base n8n en variable shell, `jq` pour payloads, dédoublonnage par titre + retry. Le **watchdog** ouvre une issue « Watchdog VPS : … » par alerte fraîche et clôt automatiquement les issues watchdog ouvertes quand il redevient vert (close-prefix). Le **journal quotidien** ouvre une issue sur push échoué et la clôt au push réussi. Défaut : repo `rennesdev-vps-ops`, label `incident` (créé au besoin). Issues désactivées par défaut sur les repos → PATCH `has_issues: true`.
- **Rapport hebdo** (github-weekly-report.sh) : section « Suggestions d'issues roadmap » = repos actifs silencieux ≥ 21 j (calcul sur `pushed_at`), suggestion prête à copier.
- **Templates GitHub** mergés sur Nav.rennesdev, Lecteur-PDF, construction-site-tracker : `.github/ISSUE_TEMPLATE/` (bug.yml, idee.yml, config.yml blank_issues_enabled: false) + `PULL_REQUEST_TEMPLATE.md` (checklist CI/doc/secret). À déployer sur les autres repos actifs si demandé.
- **À venir (phase B)** : workflow n8n « alerte VPS → issue GitHub » (watchdog, push échoué, journal) avec auto-close par le commit de fix ; radar de cadence → suggestion d'issue roadmap.

## Nettoyage hebdo artefacts/caches Actions (12/11)
- Repo dédié **`github-actions-cleanup`** (privé) : `cleanup.py` (liste `/user/repos` non archivés → supprime tous les artefacts + caches via API, per_page=100, rapport Telegram + `/var/log/github-cleanup-last.txt`), `README.md`, `.github/workflows/test-artifact.yml` (workflow_dispatch qui upload 1 Mo pour tester le cycle).
- **Cron = systemd timer** `github-cleanup.timer` (`OnCalendar=Sun 04:00 Europe/Paris`, Persistent) → `github-cleanup.service` (oneshot, `python3 /home/ubuntu/projects/github-actions-cleanup/cleanup.py`). Units dans `~/projects/rennesdev-vps-ops/systemd/` + `/etc/systemd/system/`. Test 12/11 : dispatch test-artifact → artefact 1 Mo créé → `cleanup.py` l'a supprimé (artifacts=0), service OK, 21 dépôts actifs scannés.
- **Scope PAT requis** : Actions read+write sur les dépôts (fine-grained : sinon 404 sur `/actions/artifacts`). PAT actuel OK (testé 12/11, 204 dispatch + 204 delete). PAT voit 71 repos (sélection fine-grained), 21 non archivés.
- Commandes : `sudo python3 ~/projects/github-actions-cleanup/cleanup.py [--dry-run] [--repo NOM]` · `systemctl start github-cleanup.service` · `systemctl list-timers github-cleanup.timer`.

## Link checker hebdo (12/11)
- Repo dédié **`link-checker`** (privé) : `check_links.py` — scanne le README des 21 dépôts actifs + les .html/.md des repos site (`rennesdev`, `RuaudelEmmanuel.github.io`, `RuaudelPhoto`), check chaque lien http(s) (HEAD→GET, UA navigateur, 15 s, 150 ms de délai) : 2xx/3xx OK, 401/403/**999** = « protégé » (bot), 404/410/5xx/timeout = mort. localhost & paramètres vides exclus. Sorties : `/var/log/link-checker-last.txt` + `.json` + Telegram. Exit 1 si morts (alerte dans journalctl).
- **Cron = systemd timer** `link-checker.timer` : **samedi 05h00 Europe/Paris** (décalé du cleanup dimanche 04h00) → `link-checker.service`. Units dans `~/projects/rennesdev-vps-ops/systemd/` + `/etc/systemd/system/`, enable ✅.
- Test 12/11 : 22 fichiers, 50 liens uniques → 47 OK, 2 protégés (LinkedIn 999, Malt 403), **1 mort confirmé : `github.com/Ruaudel-Emmanuel/construction-site-tracker` (404 public) dans `rennesdev/portofolio.html` ligne 537** — repo renommé `Suivi-d-Interventions-avec-Photos` (lien à corriger manuellement).
- Commandes : `sudo python3 ~/projects/link-checker/check_links.py [--repo NOM] [--max N]` · `systemctl start link-checker.service`.

## Secret scan hebdo gitleaks (12/11)
- Repo dédié **`secret-scan`** (privé) : `scan_secrets.py` + `.gitleaks.toml` + README. gitleaks **v8.30.1** installé dans `/usr/local/bin/gitleaks`.
- Pour chaque dépôt actif : clone `--mirror` dans `/var/cache/secret-scan/<repo>.git` (auth via **credential helper inline** `-c credential.helper='!f(){...}'` → le PAT n'est JAMAIS persisté dans `.git/config` — vérifié), update via `remote update` si déjà cloné, puis `gitleaks detect --redact` (secrets masqués dans les rapports).
- Sorties : Telegram + `/var/log/secret-scan-last.txt`/`.json` (root 600, umask 077). Exit 1 si findings. Faux positifs → allowlist dans `.gitleaks.toml`.
- **Cron = systemd timer** `secret-scan.timer` : **mardi 03h00 Europe/Paris** → prochain run mar. 17/11. Units dans `~/projects/rennesdev-vps-ops/systemd/` + `/etc/systemd/system/`.
- Test 12/11 (run complet via service) : **23 dépôts scannés, historique complet, 0 finding** 🎉.
- Commandes : `sudo python3 ~/projects/secret-scan/scan_secrets.py [--repo NOM] [--max-repos N]` · `systemctl start secret-scan.service`.
- ⚠️ Si un vrai secret est un jour détecté : révoquer le token immédiatement, purger l'historique (`git filter-repo`), noter dans une issue privée du repo secret-scan.

## Bot stale (actions/stale) — 1x/jour, cron NATIF GitHub (12/11)
- Repo dédié **`stale-bot`** (privé) : `stale.yml` (template déployé dans chaque repo) + `deploy_stale.py` + README.
- **Pas redondant avec GitHub-Auditor** : l'Auditor ne fait que *rapporter* (LLM, 06h00) ; stale *agit* (label « stale » à 60 j, fermeture auto à 74 j pour les issues ; PR : 90 j/120 j ; exemptions `pinned,security`). Le cron tourne sur les runners GitHub (`cron: '30 3 * * *'` UTC) → **zéro ressource VPS**, pas de systemd timer. Déclenchable à la main (workflow_dispatch).
- Déploiement 12/11 : **22 dépôts pushés sur main + 1 PR ouverte** (Lecteur-PDF, main protégé par ruleset → PR #9 `chore/add-stale-bot`, à merger manuellement) + 0 erreur. Test : dispatch manuel sur GitHub-Auditor → run `success`. PAT requis : Contents read+write.
- Commandes : `sudo python3 ~/projects/stale-bot/deploy_stale.py [--repo NOM] [--force]`.

## Audit mensuel Actions non épinglées en SHA (12/11)
- Repo dédié **`actions-audit`** (privé) : `audit_actions.py` + README. Scanne tous les `.github/workflows/*.yml` des dépôts actifs (pyyaml), classe chaque `uses:` : SHA-40 ✅ / tag ❌ (avec **SHA résolu** via `git ls-remote` pour le fix) / `docker://` ⚠️ / `./` local ✅. Sorties Telegram + `/var/log/actions-audit-last.{txt,json}` (600). Exit 1 si non épinglées.
- **Cron = systemd timer** `actions-audit.timer` : **1er du mois 06h00 Europe/Paris** (`OnCalendar=*-*-01 06:00:00 Europe/Paris`) → prochain run 01/12.
- Premier run 12/11 : 25 dépôts / 27 fichiers → 30 non épinglées, dont 23× notre propre `stale@v11` déployé le jour même → template `stale-bot/stale.yml` corrigé en SHA (`actions/stale@4391f3da665fdf50b6810c1a66712fb9ba21aa93` = v11) + redéployé `--force` sur 24 dépôts (PR #9 Lecteur-PDF mise à jour aussi). Re-run : **7 restantes** (Lecteur-PDF ci.yml ×4, live-readme ×2, github-actions-cleanup test-artifact ×1) avec SHA prêts dans le rapport.
- **fix_pins.py** (dans le repo actions-audit) : lit `/var/log/actions-audit-last.json` et pousse les SHA (push main, ou branche `chore/pin-actions-sha` + PR si main protégé). Appliqué 12/11 : live-readme + github-actions-cleanup pushés ✅, Lecteur-PDF → **PR #10** (4 pins, à merger — CI ruleset avec auto-merge). Re-audit : plus que Lecteur-PDF en attendant le merge.
- Commandes : `sudo python3 ~/projects/actions-audit/audit_actions.py [--repo NOM]` · `sudo python3 ~/projects/actions-audit/fix_pins.py [--dry-run] [--repo NOM]` · `systemctl start actions-audit.service`.

## Récap des crons GitHub (12/11)
| Tâche | Timer | Jour/heure (Paris) | Repo |
|---|---|---|---|
| Secret scan gitleaks (historique) | `secret-scan.timer` | mardi 03h00 | `secret-scan` |
| Link checker (README + sites) | `link-checker.timer` | samedi 05h00 | `link-checker` |
| Nettoyage artefacts/caches Actions | `github-cleanup.timer` | dimanche 04h00 | `github-actions-cleanup` |

## Inventaire & hygiène
- 97 dépôts → **79 archivés** (15/09), **18 actifs** conservés. Doublons historiques : Fiscale-vps/Fisclale-vps/Fiscale_vps, Devis-Python/Devis-Python-Steamlit.
- Repos récents : `Lecteur-PDF` (18/09), `VPS-Rennesdev.fr` (journal VPS, timer quotidien 23h), `git-ops-journal` (gestion du compte + automatisations), `construction-site-tracker` (Suivi Interventions, Play Store).
- Ruleset : certains repos exigent une **PR approvée** pour merger sur main (pas de push direct) → pousser sur une branche + PR.
- Releases GitHub : API `POST /repos/<login>/<repo>/releases` puis upload assets sur `uploads.github.com` (PAT en variable shell).

## Anonymat (règle permanente)
Aucun secret/identifiant dans les contenus commités (grep de vérification avant push). Le nom des repos peut contenir le domaine (choix utilisateur), le contenu est anonymisé.
