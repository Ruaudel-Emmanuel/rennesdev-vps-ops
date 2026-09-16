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

---

## 🔧 Chaîne hebdomadaire « Dépendances » (ajoutée le 16/09)

**Quand :** tous les dimanches à 08h30 (Paris) — `Horloge hebdo (dim 08h30)`, cron `30 8 * * 0`.
La chaîne quotidienne « descriptions » (07h45) reste inchangée ; les deux déclencheurs vivent
dans le même workflow et exécutent chacun leur propre branche.

```
[Horloge hebdo (dim 08h30)]
   → [Dépendances — vérifie et crée les branches]   (nœud Code, toute la logique)
   → [Telegram — récap]
```

### Ce que fait le nœud « Dépendances »

1. Liste les repos actifs (non archivés, non fork).
2. Détecte à la racine : `package.json` (npm) et `requirements.txt` (PyPI) — via
   `GET /git/trees/{branche}?recursive=1` (1 appel/repo).
3. Télécharge les fichiers (raw.githubusercontent.com — hors quota API) et parse les versions
   épinglées (les deps **non épinglées** sont signalées « aucune version épinglée à vérifier »).
4. Compare aux dernières versions stables (registres npm et PyPI ; préversions ignorées).
5. Si mises à jour : crée une branche **`deps/maj-auto-<date>`** contenant **un commit** qui met
   à jour les fichiers (API Git : blob → tree avec `base_tree` → commit → ref). `main` n'est
   **jamais** modifié. Les préfixes `^`/`~`/`>=` sont préservés.
6. Si la branche du jour existe déjà (semaine précédente non fusionnée) : rien de créé, mention
   « branche déjà ouverte » dans le récap.
7. Récap Telegram par repo : 🌿 branche créée (majeures/mineures/corrections), ✅ à jour,
   ➖ sans fichier de deps, ↩️ branche déjà ouverte, ⚠️ erreur.

### Pièges corrigés le 16/09 (à ne pas refaire)

- `this.helpers.httpRequest({json:false})` **auto-parse les réponses JSON** (content-type) :
  `package.json` arrive en **objet**, pas en string → normaliser via `getTexte(raw)` sinon
  `JSON.parse('[object Object]')` échoue et le repo est skippé en silence.
- `encodeURIComponent()` sur un package npm scopé (`@capacitor/core`) casse l'URL du registre :
  appeler `https://registry.npmjs.org/${nom}/latest` **sans encodage**.

### Vérifier manuellement

```bash
for r in <repos>; do
  curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $PAT" \
    "https://api.github.com/repos/Ruaudel-Emmanuel/$r/branches/deps/maj-auto-$(date +%F)"
done   # 200 = branche créée
```
