# 📰 Diffusion Actus Discord (n8n)

Workflow n8n qui **vérifie les flux RSS listés dans Airtable 3 fois par jour** (09:00, 15:00,
21:00 — Paris), envoie les **nouveaux articles** sur les salons Discord (webhook) et les
**marque comme envoyés dans Airtable** (clé unique = `Lien`).

> **Optimisé quota Airtable (16/09)** : le forfait gratuit Airtable = 1 000 appels API/mois.
> Ancien design (check par article, toutes les 30 min) = ~2 000-4 000 appels/mois → quota explosé.
> Nouveau design : **2-3 appels/run** au lieu de 30-100+.

```
[Horloge (3×/jour)] ──► [Diffusion Actus]  (nœud Code : toute la logique)
                         ├─ lit les flux       : Airtable « Table 1 », CACHE staticData 12 h (~2 appels/j)
                         ├─ télécharge + parse : RSS 2.0 et Atom (regex, CDATA/entités gérés)
                         │                       candidats = articles < 48 h, max 20, triés du + récent
                         ├─ déduplique         : 1 SEUL appel — filterByFormula OR({Lien}='…',…)
                         ├─ marque AVANT envoi : 1 SEUL appel — POST batch (≤ 10 enregistrements)
                         └─ envoie sur Discord : webhook POST, embed (titre, lien, sommaire, image, date)
```

### Économie d'appels Airtable (par run)

| Étape | Avant | Après |
|---|---|---|
| Liste des flux | 1 (chaque run = 48/j) | 1 tous les 12 h (~2/j) |
| Dédup | 1 appel **par article scanné** (× 4 flux) | 1 appel groupé (formule OR) |
| Marquage | 1 appel **par article envoyé** | 1 appel groupé (≤ 10 records) |
| Cron | toutes les 30 min (48 runs/j) | 3 runs/j (09:00, 15:00, 21:00 Paris) |

- **Pause auto 429** : si Airtable répond 429 (quota épuisé), le run s'arrête immédiatement et le
  workflow ne touche plus Airtable pendant 24 h (mémorisé dans le staticData) — zéro gaspillage.
- Marquage AVANT envoi Discord → jamais de doublon si le quota lâche entre les deux.

## Base Airtable — `Base RSS Manu` (`appzFRnAeQHJENm11`)

| Table | Rôle | Champs utilisés |
|---|---|---|
| `Table 1` | Liste des flux | `Name`, `URL source rss`, `Salon discord` (URL webhook) |
| `Table RSS articles` | Marquage des envoyés | `Lien` (clé unique), `Sources`, `Titres`, `Sommaire`, `Date publication`, `Salon Discord` |

- **Ajouter un flux = ajouter une ligne dans « Table 1 »** (aucune modif du workflow).
- L'ancien contenu de « Table RSS articles » (créé avant l'automatisation) n'interfère pas.

## Comportements de sécurité intégrés

- **Anti-flood** : 5 nouveaux articles max par flux et 10 par run (triés du plus récent au plus ancien).
- **Image de l'article dans l'embed Discord** (ajouté 2026-09-14) : extraite du flux
  (`media:content`, `media:thumbnail`, `enclosure` image, ou 1re `<img>` du contenu) — sinon
  repli sur l'`og:image`/`twitter:image` de la page de l'article (1 requête par nouvel article).
  Validé localement : 100 % des items des flux n8n/Substack/BensBites, 50 % MIT + repli og:image
  (100 % couverts).
- **Rate limiting** : pauses 250-400 ms entre chaque appel Airtable/Discord (limites API respectées).
- **Flux en erreur** : loggués dans le rapport d'exécution, n'interrompent pas les autres flux.
- **staticData** : le cache des flux n'est persisté que sur les exécutions « production » (trigger) — un test manuel le recharge à chaque fois.
- **Salon absent** sur un flux : l'article est marqué mais non envoyé sur Discord.

## Secrets (jamais dans ce repo)

Le token Airtable (fine-grained : `data.records:read/write`, `schema.bases:read`) et l'URL du
webhook Discord vivent **uniquement dans la base PostgreSQL de n8n** (volume `n8n_pg_data`,
inclus dans les backups Kopia chiffrés). Dans `workflow.json` ils sont remplacés par
`AIRTABLE_TOKEN_PLACEHOLDER` et `DISCORD_WEBHOOK_PLACEHOLDER`.

## Notes techniques

- Schedule : cron `0 9,15,21 * * *`, timezone `Europe/Paris` (settings du workflow).
- Nœud unique « Diffusion Actus » (Code node) utilise `this.helpers.httpRequest` — suit les
  redirections (ex. `blog.n8n.io/rss` → `/rss/`).
- Testé en conditions réelles le 2026-09-14 : exécution id 42, succès, 20 articles envoyés
  (5/flux) et marqués.
- Désactiver temporairement : toggle « Active » dans l'éditeur n8n.
