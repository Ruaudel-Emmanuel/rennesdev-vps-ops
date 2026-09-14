# Push GitHub — workflow n8n « Push GitHub »

Automatisation créée le 2026-09-13 pour pousser un projet du VPS vers GitHub **sans jamais
transmettre le PAT en session** : le token est stocké une fois pour toutes dans le workflow n8n
(nœud « Config (PAT GitHub) »).

## Architecture

```
curl POST https://n8n.rennesdev.fr/webhook/github-push
  → Webhook (n8n)
  → Config (PAT GitHub) — PAT stocké ici
  → Token valide ? (comparaison header X-Auth-Token)
  → Prépare les arguments (Code: encodage base64 de chaque champ)
  → Push vers GitHub (Execute Command → /projects/scripts/github-push.sh)
  → Réponse webhook (stdout du script + code de sortie)
```

- **Script hôte** : `/home/ubuntu/projects/scripts/github-push.sh` (monté dans le conteneur
  n8n via `/home/ubuntu/projects:/projects`, voir `~/docker-compose.yml`).
- **Argument du script** : `ExecuteCommand` est désactivé par défaut dans n8n v2 → réactivé via
  `NODES_EXCLUDE=[]` dans le compose (conteneur limité au montage `/projects`).
- Le script : vérifie le token via l'API GitHub, **crée le repo s'il n'existe pas**
  (privé ou public selon `private`), clone dans `/projects/<path>` si besoin, commit et pousse.
  Le token ne quitte jamais l'argument de `git push` (jamais persisté dans `.git/config`),
  et toute sortie est nettoyée (`x-access-token:***@`).

## Appel (à utiliser depuis une session assistant ou tout client HTTP)

```bash
curl -s -X POST https://n8n.rennesdev.fr/webhook/github-push \
  -H 'Content-Type: application/json' \
  -H 'X-Auth-Token: <PAT ou token dédié>' \
  -d '{
    "repo": "mon-nouveau-repo",
    "path": "mon-projet",            # répertoire sous /home/ubuntu/projects (défaut = repo)
    "message": "Mon message de commit",
    "branch": "main",
    "private": true
  }'
```

Réponse : `{"exitCode":0,"stderr":"","stdout":"... ✅ Poussé vers <owner>/<repo> ... EXIT:0"}`
(`EXIT:0` = succès, autres codes = erreur décrite dans `stdout`).

⚠️ Le header `X-Auth-Token` doit contenir la **même valeur** que le champ `github_token`
du nœud Config. Le plus simple : utiliser le PAT lui-même comme authentifiant du webhook.

### ✅ Méthode validée le 2026-09-14 — PAT jamais en session

Le PAT est extrait de la base n8n **directement dans une variable shell**, utilisée par le
curl et jamais affichée ni écrite sur disque (le PAT ne transite donc jamais en session
ni dans le journal) :

```bash
TOKEN=$(docker exec n8n_db psql -U n8n -d n8n -t -A -c \
  "SELECT nodes FROM workflow_entity WHERE name = 'Push GitHub'" | python3 -c "
import json,sys
nodes=json.load(sys.stdin)
tok=''
for n in nodes:
    if n.get('name')=='Config (PAT GitHub)':
        for it in n['parameters']['assignments'].get('assignments',[]):
            v=it.get('value','')
            if isinstance(v,str) and len(v)>20: tok=v
print(tok)
")
curl -s -X POST https://n8n.rennesdev.fr/webhook/github-push \
  -H 'Content-Type: application/json' -H "X-Auth-Token: $TOKEN" \
  -d '{"repo":"...","path":"...","message":"...","branch":"main","private":true}'
```

(Le format n8n Set v3 : `parameters.assignments.assignments` = liste de
`{name, type, value}` — le token est la valeur de plus de 20 caractères.)

## Sécurité — à savoir

- Le PAT est stocké dans les **paramètres du workflow** (base PostgreSQL n8n, volume
  `n8n_pg_data`). Il est donc inclus dans les backups Kopia du volume (dépôt chiffré sur le PC,
  mot de passe connu de l'utilisateur seul).
- Ne **jamais** exporter/committers ce workflow avec le vrai token dans un fichier du repo.
- PAT recommandé : **fine-grained**, « Contents: Read and write » limité aux repos concernés.
- Révocation/régénération : se faire via l'UI n8n (nœud Config) + GitHub Settings.

## Import / modification

Le workflow a été importé par CLI puis activé (n8n v2 = modèle draft/published, il faut
`active=true` **et** `activeVersionId=versionId`) :

```bash
docker cp wf-push-github.json n8n_workflow:/tmp/wf.json
docker exec n8n_workflow n8n import:workflow --input=/tmp/wf.json
docker exec n8n_db psql -U n8n -c "UPDATE workflow_entity SET active=true, \"activeVersionId\"=\"versionId\" WHERE name='Push GitHub';"
docker restart n8n_workflow
```
