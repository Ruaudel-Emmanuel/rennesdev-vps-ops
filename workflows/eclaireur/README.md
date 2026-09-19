# ÉCLAIREUR — lecture de page web par LLM local

Workflow n8n « ÉCLAIREUR — lecture de page web (Ollama) ». Donne au bot la capacité de **lire le contenu d'une page web** (option « a » du projet de même nom) : récupération HTTP, extraction du texte, analyse par Ollama.

## Usage

```bash
# Résumé d'une page
curl -s -X POST https://n8n.rennesdev.fr/webhook/eclaireur \
  -H 'Content-Type: application/json' \
  -H "X-Eclaireur-Key: $(sudo cat /etc/eclaireur-key.txt)" \
  -d '{"url":"https://exemple.com/article"}'

# Question sur une page
curl -s -X POST https://n8n.rennesdev.fr/webhook/eclaireur \
  -H 'Content-Type: application/json' \
  -H "X-Eclaireur-Key: $(sudo cat /etc/eclaireur-key.txt)" \
  -d '{"url":"https://exemple.com/article","question":"Qui ? Quand ?"}'
```

Réponse JSON : `{ "url", "question", "modele", "reponse" }`. En cas d'erreur : `{ "error": "..." }` (200, clé/page illisible) ou 401 (`Clé invalide`).

## Chaîne des nœuds

```
Webhook (POST /eclaireur, clé X-Eclaireur-Key) → Config (clé) → Clé valide ?
  ├─ false → Réponse refusée (401)
  └─ true → Lire la page (HTTP GET, fullResponse, timeout 20 s, onError=continue)
       → Extraire le texte (Code : strip HTML/scripts/styles, entités FR, max 2500 car.)
            ├─ erreur → Réponse erreur (200, {error})
            └─ ok → Prépare la requête (Code : prompt système + utilisateur, JSON /api/chat)
                 → Analyse (Ollama) : POST http://ollama:11434/api/chat
                 → Répondre (Respond to Webhook)
```

## Choix techniques (et pourquoi)

| Choix | Raison |
|---|---|
| Modèle **qwen2.5:3b** | le 7b traite le prompt à ~12 tokens/s en CPU → >100 s pour 4000 car. ; le 3b fait ~28 tokens/s |
| Texte limité à **2500 caractères** | Cloudflare (proxy) coupe les réponses >100 s (524) : il faut tenir le résumé complet sous ~90 s |
| `num_predict: 350`, résumé 5 phrases max | borne la génération (CPU) |
| **`keep_alive: 0`** dans la requête /api/chat | usage à la demande → le modèle se **décharge immédiatement** après la réponse (RAM au repos inchangée, vérifié : 1,6 Go) |
| `num_ctx: 8192` | prompt ≈ 1200-1500 tokens max |
| Clé dans le header `X-Eclaireur-Key` | le webhook est public via n8n.rennesdev.fr ; sans clé, n'importe qui ferait travailler Ollama (CPU + SSRF partiel). Valeur : `/etc/eclaireur-key.txt` (root 600), copiée dans le nœud Config du workflow (comme le PAT dans « Push GitHub ») |
| Erreurs en HTTP 200 avec `{"error": ...}` | les codes 4xx/5xx d'origine traversent mal Cloudflare (page d'erreur CF au lieu du JSON) |
| `onError: continueRegularOutput` + détection `item.error` | un protocole invalide (ftp://) ou DNS KO faisait un 500 sec ; maintenant renvoyé proprement |
| `fullResponse: true` + `responseFormat: text` | sinon n8n ne fournit ni `statusCode` ni le HTML brut au nœud Code (champ `data` seulement) |

## Pièges à retenir (trouvés en déploiement)

1. **Nœud Webhook sans `webhookId`** → n8n enregistre un chemin de forme `<workflowId>/webhook/<path>` (URL de test) et le webhook production renvoie 404 « not registered ». Toujours mettre un `webhookId` (uuid) sur le nœud.
2. **Workflow créé en SQL sans ligne `shared_workflow`** (`workflowId`, `projectId`, `workflow:owner`) → l'activation échoue en boucle (`EntityNotFoundError SharedWorkflow`).
3. Les 2 points ci-dessus + snapshot `workflow_history` + `activeVersionId` : voir la procédure standard dans le skill `n8n-ops`.

## Performances mesurées (VPS 4 vCPU, CPU-only)

| Cas | Durée |
|---|---|
| Résumé d'une page wiki (~2500 car.) | ~83 s |
| Question ciblée sur une page | ~52 s |
| Erreur (URL invalide, page 404, clé invalide) | < 2 s |

⚠️ Une page dont le texte dépasse 2500 caractères est tronquée (le LLM ne voit que le début). L'amélioration possible : passage à un modèle plus rapide ou bascule sur l'option « b » (navigateur headless) — voir `ETAT-VPS.md`, idée « ÉCLAIREUR / SPECTRE ».
