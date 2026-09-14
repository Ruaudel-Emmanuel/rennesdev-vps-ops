# 📸 Diffusion Photos Discord (n8n) — PHASE 1

Workflow **clé en main mais désactivé** : même architecture que « Diffusion Actus Discord »
(voir `../diffusion-actus-discord/`), décliné pour les flux photos de la base Airtable
**« rss photo »**. Couleur d'embed **violette** pour le distinguer des actus (vertes).

## ⚠️ Placeholders à remplacer (phase 2) — dans le nœud « Diffusion Photos »

| Placeholder | À remplacer par |
|---|---|
| `AIRTABLE_TOKEN_PLACEHOLDER` | Personal Access Token Airtable ayant accès à la base « rss photo » |
| `BASE_ID_PLACEHOLDER` | ID de la base « rss photo » (`app…`) |
| `FEEDS_TABLE_ID_PLACEHOLDER` | ID de la table des flux (`tbl…`) |
| `PHOTOS_TABLE_ID_PLACEHOLDER` | ID de la table de marquage (`tbl…`) |
| `DISCORD_WEBHOOK_PLACEHOLDER` | Webhook par défaut (utilisé si un flux n'a pas de salon) |

Le bloc `CONFIG.champsFlux` / `CONFIG.champsPhotos` contient les **noms de champs** Airtable
(`Name`, `URL source rss`, `Salon discord` / `Lien`, `Sources`, `Titres`, `Sommaire`,
`Date publication`, `Salon Discord`) — adapte-les si ta base « rss photo » utilise d'autres noms.

## Fonctionnement (identique à Diffusion Actus)

1. Toutes les 30 min (cron `*/30 * * * *`, Europe/Paris) : lecture des flux dans Airtable
2. Téléchargement + parsing RSS/Atom, tri du plus récent au plus ancien
3. Dédup : article déjà dans la table de marquage (clé = `Lien`) → ignoré
4. Image extraite du flux (`media:content`, `media:thumbnail`, `enclosure`, 1re `<img>`)
   avec repli `og:image`/`twitter:image` sur la page de l'article
5. Envoi sur le **salon du flux** (champ `Salon discord`, sinon le webhook par défaut du CONFIG)
6. Marquage dans la table de marquage
7. Anti-flood : 5 max/flux/run ; rate-limiting 250-400 ms ; flux en erreur n'interrompent pas les autres

## Phase 2 (à faire par l'utilisateur puis l'assistant)

1. L'utilisateur remplace les placeholders dans l'éditeur n8n et **active** le workflow
2. L'assistant teste (cron temporaire → vérification exécution + Discord + Airtable)
3. Le token Airtable doit avoir accès à la base « rss photo » (éditer le token sur
   airtable.com/create/tokens → Access → ajouter la base)
