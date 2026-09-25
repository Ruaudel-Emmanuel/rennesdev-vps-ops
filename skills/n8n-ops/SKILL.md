---
name: n8n-ops
description: Tout ce qui concerne n8n sur le VPS rennesdev.fr — architecture (compose, PG 17), édition des workflows en base (pièges workflow_history/activeVersionId/connections), variables d'env, cron, exports, quota Airtable. Utiliser dès qu'on travaille sur n8n, un workflow, la base n8n_db ou Airtable.
---

# n8n — mémoire opérationnelle

## Architecture
- Conteneurs : `n8n_workflow` (127.0.0.1:5678) + `n8n_db` (**PostgreSQL 17**) — `~/docker-compose.yml`, mdp dans `~/.env` (`N8N_DB_PASSWORD`).
- Version **2.39.8** (maj 16/09, pg_dump de secours avant : `~/n8n-db-avant-MAJ-<date>.sql.gz`).
- ⚠️ `~/.env` n'est pas 100 % compatible bash (ligne parasite) — ne pas le `source`er aveuglément, extraire la variable voulue avec grep/cut.
- ExecuteCommand réactivé via `NODES_EXCLUDE=[]` (montage `/home/ubuntu/projects:/projects`). Code node : **`NODE_FUNCTION_ALLOW_BUILTIN=crypto`** dans le compose (`NODES_ALLOW_BUILTIN` ne marche PAS pour les task runners).

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
| GitHub — descriptions auto | 07:45 + lun 22h00 (deps) | descriptions repos + branches/PR deps |
| Diffusion Actus Discord | 09:00/15:00/21:00 | RSS Airtable → Discord, voir règle Airtable |
| Diffusion Photos Discord | 09:30/15:30/21:30 | idem, base « rss photo », embeds violets |
| Stripe — alerte paiement | webhook /stripe-paiement | voir skill `stripe` |
| Tally — alerte message | webhook /tally-alerte | voir skill `tally` |
| Tally — photographe | webhook /tally-photographe | voir skill `tally` |
| Push GitHub | webhook /github-push | voir skill `github-ops` |
| **ÉCLAIREUR — lecture de page web (Ollama)** | webhook /eclaireur | URL → HTTP GET → extraction texte (2500 car. max) → qwen2.5:3b (résumé ou Q&A), `keep_alive: 0` (décharge immédiate), clé `X-Eclaireur-Key`. Voir `workflows/eclaireur/README.md` |

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
