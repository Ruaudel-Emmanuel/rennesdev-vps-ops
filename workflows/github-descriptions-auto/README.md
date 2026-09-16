# 🏷️ GitHub — descriptions auto (n8n)

Workflow n8n qui ajoute automatiquement une **description courte aux dépôts GitHub** qui n'en ont
pas. Chaîne : liste des repos → filtre (non archivés, sans description, non fork) → génération de
la description par **Ollama `qwen2.5:7b`** (local) → nettoyage → PATCH sur l'API GitHub → récap
Telegram.

```
[Horloge quotidienne (07h45)]  cron 45 7 * * * (Europe/Paris)
   → [GitHub — liste des repos]        GET /user/repos (PAT fine-grained, per_page=100)
   → [Filtre — sans description]       Code : !archived && !description && !fork
   → [Ollama — génère la description]  POST ollama:11434/api/generate, qwen2.5:7b, temp 0.2
   → [Nettoie la description]          Code, mode PAR ITEM (pairing fiable) : 1re ligne, ≤ 80 car.
   → [GitHub — ajoute la description]  PATCH /repos/{full_name} {description}
   → [Récapitule]                      « 🏷️ Descriptions GitHub ajoutées (n) »
   → [Telegram — récap]                bot Bot-vps, chat 8634051625
```

## ⚠️ Point d'attention (bug corrigé le 16/09)

Le nœud « Nettoie la description » **doit rester en mode `Run Once for Each Item`**
(`parameters.mode = runOnceForEachItem`). En mode « all items », `$('Filtre …').item` se résout
vers le même item pour tous → tous les PATCH partaient sur un seul dépôt (statut n8n « success »
malgré tout, très piégeux). Historique : exécution #223 (11 repos → 1 seul patché),
#224 (10 → 1), #225 OK (9 repos décrits, 0 restant).

## Secrets

- PAT GitHub fine-grained : injecté dans les 2 nœuds HTTP (Authorization: Bearer …) — jamais
  commité (masqué `GITHUB_PAT_MASKED` dans l'export).
- Credential Telegram n8n « Bot-vps ».

## Vérification

```bash
curl -s -H "Authorization: Bearer $PAT" "https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator" \
  | python3 -c "import json,sys; repos=json.load(sys.stdin); \
print([r['name'] for r in repos if not r['archived'] and not r['description'] and not r['fork']])"
# → [] = tous les dépôts actifs sont décrits
```
