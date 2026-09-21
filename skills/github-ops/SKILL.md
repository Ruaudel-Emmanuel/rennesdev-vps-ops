---
name: github-ops
description: Tout ce qui concerne GitHub sur le VPS rennesdev.fr — PAT, push sans secret, workflows d'automatisation (descriptions, dépendances/PR, rapport hebdo, radar cadence), inventaire des dépôts. Utiliser dès qu'on parle de GitHub, PR, PAT ou des workflows n8n liés à GitHub.
---

# GitHub — mémoire opérationnelle

## Règles de gestion des repos (ordre utilisateur 19/09)
- **1 projet = 1 repo** dédié (jamais un sous-dossier d'un repo existant) — ex. `Nav.rennesdev` a son propre repo.
- **Améliorer un projet = nouvelle branche** dédiée dans le repo du projet (pas de commit direct sur main pour les évolutions).
- **Toutes les améliorations = commits commentés** (messages explicites).

## PAT (token)
- Emplacement : base n8n (conteneur `n8n_db`, **nom de base = `n8n`** — piège : `-d n8n_db` échoue, POSTGRES_DB=n8n ; POSTGRES_USER=n8n), workflow **« Push GitHub »** → nœud **« Config (PAT GitHub) »** (assignments[0].value de `nodes[1]`). C'est l'unique source ; les autres nœuds/workflows y font référence.
- **Jamais affiché en session** : extraction en variable shell du curl, jamais sur disque ni dans le journal. ⚠️ Le 18/09/2026 il a été affiché par erreur (sortie psql non filtrée) → rotation recommandée : l'utilisateur génère un nouveau token fine-grained (vérifier qu'il commence par `github_pat_` ou `ghp_`, permissions : Contents RW + Pull requests RW + Administration RW pour créer des repos), le colle dans « Push GitHub » → nœud Config, puis l'assistant le propage par SQL (jamais affiché) vers « GitHub — descriptions auto » et « Agent Telegram ».
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

## Inventaire & hygiène
- 97 dépôts → **79 archivés** (15/09), **18 actifs** conservés. Doublons historiques : Fiscale-vps/Fisclale-vps/Fiscale_vps, Devis-Python/Devis-Python-Steamlit.
- Repos récents : `Lecteur-PDF` (18/09), `VPS-Rennesdev.fr` (journal VPS, timer quotidien 23h), `git-ops-journal` (gestion du compte + automatisations), `construction-site-tracker` (Suivi Interventions, Play Store).
- Ruleset : certains repos exigent une **PR approvée** pour merger sur main (pas de push direct) → pousser sur une branche + PR.
- Releases GitHub : API `POST /repos/<login>/<repo>/releases` puis upload assets sur `uploads.github.com` (PAT en variable shell).

## Anonymat (règle permanente)
Aucun secret/identifiant dans les contenus commités (grep de vérification avant push). Le nom des repos peut contenir le domaine (choix utilisateur), le contenu est anonymisé.
