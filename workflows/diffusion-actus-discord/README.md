# 📰 Diffusion Actus Discord (n8n)

Workflow n8n qui **vérifie les flux RSS listés dans Airtable toutes les 30 minutes**, envoie les
**nouveaux articles** sur les salons Discord (webhook) et les **marque comme envoyés dans Airtable**
(le marquage = présence de l'article dans la table « Table RSS articles », clé unique = `Lien`).

```
[Horloge (30 min)] ──► [Diffusion Actus]  (nœud Code : toute la logique)
                         ├─ lit les flux       : Airtable « Table 1 » (Name, URL source rss, Salon discord)
                         ├─ télécharge + parse : RSS 2.0 et Atom (regex, CDATA/entités gérés)
                         ├─ déduplique         : GET filterByFormula {Lien} = ... sur « Table RSS articles »
                         ├─ envoie sur Discord : webhook POST, embed (titre, lien, sommaire, source, date)
                         └─ marque l'article   : POST dans « Table RSS articles »
```

## Base Airtable — `Base RSS Manu` (`appzFRnAeQHJENm11`)

| Table | Rôle | Champs utilisés |
|---|---|---|
| `Table 1` | Liste des flux | `Name`, `URL source rss`, `Salon discord` (URL webhook) |
| `Table RSS articles` | Marquage des envoyés | `Lien` (clé unique), `Sources`, `Titres`, `Sommaire`, `Date publication`, `Salon Discord` |

- **Ajouter un flux = ajouter une ligne dans « Table 1 »** (aucune modif du workflow).
- L'ancien contenu de « Table RSS articles » (créé avant l'automatisation) n'interfère pas.

## Comportements de sécurité intégrés

- **Anti-flood** : 5 nouveaux articles max par flux et par run (les autres passent au run suivant,
  triés du plus récent au plus ancien).
- **Image de l'article dans l'embed Discord** (ajouté 2026-09-14) : extraite du flux
  (`media:content`, `media:thumbnail`, `enclosure` image, ou 1re `<img>` du contenu) — sinon
  repli sur l'`og:image`/`twitter:image` de la page de l'article (1 requête par nouvel article).
  Validé localement : 100 % des items des flux n8n/Substack/BensBites, 50 % MIT + repli og:image
  (100 % couverts).
- **Rate limiting** : pauses 250-400 ms entre chaque appel Airtable/Discord (limites API respectées).
- **Flux en erreur** : loggués dans le rapport d'exécution, n'interrompent pas les autres flux.
- **Salon absent** sur un flux : l'article est marqué mais non envoyé sur Discord.

## Secrets (jamais dans ce repo)

Le token Airtable (fine-grained : `data.records:read/write`, `schema.bases:read`) et l'URL du
webhook Discord vivent **uniquement dans la base PostgreSQL de n8n** (volume `n8n_pg_data`,
inclus dans les backups Kopia chiffrés). Dans `workflow.json` ils sont remplacés par
`AIRTABLE_TOKEN_PLACEHOLDER` et `DISCORD_WEBHOOK_PLACEHOLDER`.

## Notes techniques

- Schedule : cron `*/30 * * * *`, timezone `Europe/Paris` (settings du workflow).
- Nœud unique « Diffusion Actus » (Code node) utilise `this.helpers.httpRequest` — suit les
  redirections (ex. `blog.n8n.io/rss` → `/rss/`).
- Testé en conditions réelles le 2026-09-14 : exécution id 42, succès, 20 articles envoyés
  (5/flux) et marqués.
- Désactiver temporairement : toggle « Active » dans l'éditeur n8n.
