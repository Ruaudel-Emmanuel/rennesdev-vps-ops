# Dépendances hebdo — branches + Pull Requests automatiques

Partie du workflow **« GitHub — descriptions auto »** (2 déclencheurs dans le même workflow).

- Déclencheur quotidien 07h45 (Europe/Paris) : génération auto des descriptions de dépôts (voir ci-dessous).
- **Déclencheur hebdo lundi 22h00 (Europe/Paris)** : nœud **« Dépendances — vérifie et crée les PR »**.

## Fonctionnement (chaîne Dépendances)

Pour chaque dépôt GitHub actif (non archivé, non fork) :

1. Détection de `package.json` / `requirements.txt` à la racine (tree API).
2. Comparaison aux dernières versions stables npm / PyPI (préversions ignorées, préfixes `^`/`~` préservés).
3. Création d'une branche `deps/maj-auto-<date>` avec 1 commit de mise à jour (API Git : blob → tree → commit → ref). **`main` jamais touché.**
4. **Ouverture automatique d'une Pull Request** branche → branche par défaut, avec liste à cocher des mises à jour dans le corps de PR.
5. Récap Telegram : 🌿 PR ouverte (avec URL) / ↩️ déjà ouverte / ➖ / ⚠️ par dépôt.

Cas particuliers :
- Branche déjà ouverte **avec** PR existante → rien de créé (URL rappelée).
- Branche déjà ouverte **sans** PR (ex. PR créée avant l'ajout de la permission GitHub) → la PR est ouverte au run suivant.
- Branche créée mais PR en échec (ex. PAT sans permission « Pull requests ») → signalé dans le récap, retenté au run suivant.

## ⚠️ Prérequis PAT (fine-grained)

Le PAT utilisé (dans le nœud Code) doit avoir, pour les dépôts concernés :
- **Contents : Read and write** (création des branches/commits)
- **Pull requests : Read and write** (création des PR) ← ajouté en 2026-09-17 après 403 constaté

## Historique

- 2026-09-16 : création (branches seules, dimanche 08h30).
- 2026-09-17 : cron déplacé à **lundi 22h00** + création de **PR automatique** (demande utilisateur).
