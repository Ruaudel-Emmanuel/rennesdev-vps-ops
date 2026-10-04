---
name: n8n-ops
description: Tout ce qui concerne n8n sur le VPS rennesdev.fr — architecture (compose, PG 17), édition des workflows en base (pièges workflow_history/activeVersionId/connections), variables d'env, cron, exports, quota Airtable. Utiliser dès qu'on travaille sur n8n, un workflow, la base n8n_db ou Airtable.
---

# n8n — mémoire opérationnelle

## Architecture
- Conteneurs : `n8n_workflow` (127.0.0.1:5678) + `n8n_db` (**PostgreSQL 17**) — `~/docker-compose.yml`, mdp dans `~/.env` (`N8N_DB_PASSWORD`).
- Version **2.41.3** (maj 27/09, image **épinglée** `n8nio/n8n:2.41.3` dans le compose — plus de `:latest` ; pg_dump de secours avant : `~/n8n-db-avant-MAJ-<date>.sql.gz`).
- ⚠️ **Hygiène des IDs de nœuds (incident 27/09 « Invalid workflow structure »)** : tout ID de nœud doit être un **UUID de 36 caractères** et **unique dans le workflow**. 3 pièges vus en vrai : (1) IDs dupliqués (copier-coller de nœuds entre workflows sans régénérer l'UUID) → l'éditeur refuse d'ouvrir le workflow (« Nodes X and Y share the node ID ») ; (2) IDs « faits main » > 36 car. (ex. `00000000-tally-…`, `webhook-1`, `filter-chat-id-001`) → erreur `value too long for type character varying(36)` au démarrage (insertion dans `workflow_publication_trigger_status`, table de statut de publication) ; (3) IDs NULL → idem. Vérif : `SELECT w.name FROM workflow_entity w, jsonb_array_elements(w.nodes::jsonb) n WHERE length(n->>'id')<>36 GROUP BY w.name;` + doublons par HAVING count(*)>1.
- 💡 n8n **2.41 guérit automatiquement** les IDs manquants/dupliqués **à la publication** (`healBrokenNodeIds`, log « publishing a healed version ») : il crée un nouveau snapshot `workflow_history` + repointe `activeVersionId` — mais **pas le draft** (`workflow_entity.nodes`) : corriger les deux (ou aligner le draft sur le snapshot guéri).
- Descriptions des workflows : ajoutées le 27/09 pour les 13 workflows (colonne `description` de `workflow_entity` + `workflow_history` pour les snapshots actifs). Les mettre à jour à chaque évolution notable de workflow.
- ⚠️ `~/.env` n'est pas 100 % compatible bash (ligne parasite) — ne pas le `source`er aveuglément, extraire la variable voulue avec grep/cut.
- ExecuteCommand réactivé via `NODES_EXCLUDE=[]` (montage `/home/ubuntu/projects:/projects`). Code node : **`NODE_FUNCTION_ALLOW_BUILTIN=crypto`** dans le compose (`NODES_ALLOW_BUILTIN` ne marche PAS pour les task runners).

## Variable d'env centralisée — PAT GitHub (mise en place 26/09)
- **Single source of truth** : `GITHUB_PAT` dans `~/.env` + `docker-compose.yml` (`GITHUB_PAT=${GITHUB_PAT}`) + **`N8N_BLOCK_ENV_ACCESS_IN_NODE=false`** (n8n 2.x bloque `process.env` par défaut ; sans ce flag l'accès env échoue). Conteneur à recréer après changement (`docker compose up -d --no-deps --force-recreate n8n_workflow`).
- **Nœuds Code** : utiliser **`$env.GITHUB_PAT`** (⚠️ `process.env` N'EXISTE PAS dans la sandbox du task runner → « process is not defined »). Ex. : `githubToken: ('Bearer ' + $env.GITHUB_PAT)`.
- **Headers httpRequest** : l'expression doit être **préfixée par `=`** → `=Bearer {{ $env.GITHUB_PAT }}`. Sans `=`, la valeur reste un *littéral* → **401 silencieux arnaqueur**.
- **Ne pas créer de credential n8n `githubApi` pour les httpRequest** : testée le 26/09, la credential retournait 401 (type OAuth/token) et n'était référencée par aucun workflow. La source est l'env `GITHUB_PAT`. (Credential GitHub account supprimée.)
- Rotation du PAT = maj `~/.env` GITHUB_PAT + restart conteneur (+ maj Config node de « Push GitHub » pour les scripts) → plus de chirurgie SQL dans tous les nœuds.

## Modèle publication/activation n8n 2.41 (incident 27/09 — « publier » ≠ « brouillon »)
- **« Publier » = « activer »** : `POST /workflows/:id/publish` appelle `activateWorkflow` — il n'existe pas d'état « publié mais inactif ». Brouillon volontairement inactif : **My Sub-workflow** (sous-workflow utilitaire) reste NON publié. (AI Personal Assistant était aussi brouillon ; **publié + activé le 28/09** sur Ollama local — règle 14, voir inventaire.)
- **Invariant des workflows sains** : `workflow_entity.versionId` = `workflow_entity.activeVersionId` = une ligne `workflow_history` = une ligne `workflow_published_version` (même uuid partout). `activeVersionId` NULL = l'applier **dé-publie** le workflow (l'activation est perdue).
- **Séquence correcte pour publier/activer un workflow** (ce que fait `activateWorkflow`) : (1) créer un snapshot `workflow_history` depuis le draft (auteurs `n8n`, autosaved=false) ; (2) sur l'entité : `versionId` = snapshot, `activeVersionId` = snapshot, `active=true` ; (3) insérer un record `workflow_publication_outbox` (`status=pending`, `reason=publish`, `publishedVersionId` = snapshot) ; (4) restart n8n (drain au boot — le polling seul suffit aussi) → logs « Activated trigger … result completed ».
- ⚠️ Le `versionId` de l'entité est la **cible d'activation** et DOIT exister dans `workflow_history`, sinon « Version not found » à l'activation depuis l'UI.
- ⚠️ **Compaction d'historique** : elle purge périodiquement les snapshots non référencés (ni `versionId`, ni `activeVersionId`, ni publié) — ne jamais laisser de snapshot « en réserve ».
- Outbox : statuts `pending`/`in_progress`/`completed`/`partial_success`/`failed` ; raisons `publish`/`startup`/`leadership-takeover`/`reconcile` ; index unique (workflowId, status) pour pending/in_progress ; `__unpublish__` = sentinelle de dé-publication.
- Après TOUTE édition SQL d'un workflow : re-publier via cette mécanique, puis vérifier logs + invariant + webhooks.

## Éditer un workflow en base (n8n 2.39) — 3 pièges mortels
1. **Éditer `workflow_entity` ne suffit plus** (draft/publish) : insérer un **snapshot dans `workflow_history`** puis pointer `workflow_entity."activeVersionId"` dessus.
2. Quand le snapshot est fait avec `SELECT ... FROM workflow_entity`, insérer les **nouveaux nodes EN MÊME TEMPS ou AVANT** — sinon le snapshot prend les anciens nodes et l'exécution continue sur l'ancien code malgré activeVersionId à jour.
3. **Les `connections` référencent les nœuds par NOM** — renommer un nœud sans maj des connections coupe le fil (runs « success » en 0 s sans rien faire !).
4. Toujours `psql -v ON_ERROR_STOP=1`.
5. Champ cron = `expression` (pas `cronExpression`). Timezone : `Europe/Paris` dans settings.
6. **Créer un workflow de zéro en SQL** (pièges supplémentaires, trouvés le 19/09) :
   - le nœud `n8n-nodes-base.webhook` doit avoir un **`webhookId` (uuid)** au niveau du node — sinon n8n enregistre le chemin sous la forme `<workflowId>/webhook/<path>` (URL de test) et l'URL production renvoie 404 « not registered » ;
   - il faut aussi une ligne dans **`shared_workflow`** (`workflowId`, `projectId` du projet owner, role `workflow:owner`) — sinon l'activation boucle sur `EntityNotFoundError: SharedWorkflow` ;
   - HTTP Request en `responseFormat: "text"` : le HTML arrive dans `$json.data` (pas `body`) et **sans `statusCode`** → utiliser `options.response.response.fullResponse = true` pour avoir `statusCode` + `body` ;
   - après insert + activation, **redémarrer `n8n_workflow`** pour enregistrer le webhook production ;
   - Cloudflare coupe les réponses > **100 s** (524) : un workflow synchrone long (ex. inférence Ollama) doit tenir sous ce délai.
   - Workflow de référence : **ÉCLAIREUR** (`workflows/eclaireur/` du repo ops), webhook `POST /eclaireur` protégé par header `X-Eclaireur-Key` (clé : `/etc/eclaireur-key.txt`, root 600, copiée dans le nœud Config).

## Inventaire des workflows
| Workflow | Cron (Paris) | Détail |
|---|---|---|
| Agent Telegram (bot IA) | Telegram + 07:00 | Ollama qwen2.5:7b, PG Chat Memory, rapport GitHub + radar cadence |
| **AI Personal Assistant** (actif 28/09) | chatTrigger webhook | assistant rédacteur messages SMS/Telegram — agent LangChain + **Ollama local qwen2.5:7b** (ex-Gemini cloud, basculé 28/09), mémoire PG, envoi Telegram. **= l'agent « n8n » référent (règle 14)** |
| GitHub — descriptions auto | 07:45 + lun 22h00 (deps) | descriptions repos + branches/PR deps |
| Diffusion Actus Discord | 09:00/15:00/21:00 | RSS Airtable → Discord **+ post LinkedIn par actu (Ollama qwen2.5:3b local) envoyé sur Telegram chat 8634051625** (ajouté 28/09, executionTimeout 15 min), voir règle Airtable |
| Diffusion Photos Discord | 09:30/15:30/21:30 | idem, base « rss photo », embeds violets |
| Stripe — alerte paiement | webhook /stripe-paiement | voir skill `stripe` |
| Tally — alerte message | webhook /tally-alerte | voir skill `tally` |
| Tally — photographe | webhook /tally-photographe | voir skill `tally` |
| Push GitHub | webhook /github-push | voir skill `github-ops` |
| **ÉCLAIREUR — lecture de page web (Ollama)** | webhook /eclaireur | URL → HTTP GET → extraction texte (2500 car. max) → qwen2.5:3b (résumé ou Q&A), `keep_alive: 0` (décharge immédiate), clé `X-Eclaireur-Key`. Voir `workflows/eclaireur/README.md` |
| **Codeur — missions du jour** (publié + actif le 27/09) | 14h00 lun-ven | RSS codeur.com → dédup via `/projects/vps-state/codeur-sent.json` (état base64) → Ollama choisit le top 5 → Telegram (chat 8634051625) ou « aucune nouvelle » |

## Quota Airtable (règle n°10 — 1 000 appels/mois)
- Design économe obligatoire : **dédup groupée** (1 appel, formule OR ≤ 20 liens < 48 h), **marquage groupé AVANT envoi** (1 appel, ≤ 10 records → jamais de doublon Discord si quota lâche), **cache staticData 12 h** pour les listes, fréquence limitée, **pause auto 24 h sur 429** (staticData).
- Référence : workflows « Diffusion » restructurés le 16/09 (~6-10 appels/j vs ~100).

## Processus standard
1. `node --check` sur tout code JS avant injection.
2. Modification en base → test réel (exécution manuelle via webhook temporaire ou cron temporaire) → restaurer le cron définitif.
3. **Export + README** (secrets → placeholders, double vérification grep) → push GitHub via webhook « Push GitHub » (skill `github-ops`).
4. Suppression d'un workflow : supprimer l'entité d'abord (cascade FK `workflow_entity.versionId` → `workflow_history`).

## Divers
- Tests bout-en-bout : cron temporaire → exécution trigger → vérifier l'exécution (id, durée) → restaurer cron.
- Mémoire chat : purge possible en DB (table des mémoires PG) — ex. chat `github-daily` purgé le 15/09.
