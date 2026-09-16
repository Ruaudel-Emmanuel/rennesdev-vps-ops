# 📸 Diffusion Photos Discord (n8n) — PHASE 1

Workflow **clé en main mais désactivé** : même architecture que « Diffusion Actus Discord »
(voir `../diffusion-actus-discord/`), décliné pour les flux photos de la base Airtable
**« rss photo »**. Couleur d'embed **violette** pour le distinguer des actus (vertes).

## ⚠️ Secrets (déjà remplacés par l'utilisateur dans n8n — phase 2 faite le 2026-09-14)

Le workflow est **actif et testé**. Ce repo contient l'export avec placeholders pour réimport.

## Base réelle utilisée

- Base « RSS Photo » (`appLn9VCOlsdLdp1U`), table des flux « Table 1 » (`tblHHzzA0AR8tHlZi`) :
  champs `Name`, `site web`, `rss` (URL du flux) — pas de champ salon → webhook par défaut du CONFIG
- Table de marquage « Photos envoyées » (`tblnovgnUfrGiK6zH`) créée par l'assistant
  (7 champs : Lien, Sources, Titres, Sommaire, Date publication, Salon Discord, Image) —
  a nécessité l'ajout du scope `schema.bases:write` au token
- 4 flux : phototrend.fr, argentique.net, danstacuve.org, benber.fr

💡 **Conseil** : remplir la colonne `Name` des 4 flux dans Airtable (vide actuellement →
« flux sans nom » apparaît en footer des embeds Discord).

## Fonctionnement (identique à Diffusion Actus)

1. Toutes les 30 min (cron `30 9,15,21 * * *`, Europe/Paris) : lecture des flux dans Airtable
2. Téléchargement + parsing RSS/Atom, tri du plus récent au plus ancien
3. Dédup : article déjà dans la table de marquage (clé = `Lien`) → ignoré
4. Image extraite du flux (`media:content`, `media:thumbnail`, `enclosure`, 1re `<img>`)
   avec repli `og:image`/`twitter:image` sur la page de l'article
5. Envoi sur le **salon du flux** (champ `Salon discord`, sinon le webhook par défaut du CONFIG)
6. Marquage dans la table de marquage
7. Anti-flood : 5 max/flux/run ; rate-limiting 250-400 ms ; flux en erreur n'interrompent pas les autres

## Phase 2 (fait le 2026-09-14)

1. ✅ Utilisateur : placeholders remplacés dans l'éditeur + workflow activé
2. ✅ Assistant : IDs réels découverts via le token (l'utilisateur avait mis des noms lisibles),
   table « Photos envoyées » créée via API (après ajout du scope `schema.bases:write`),
   corrections (virgule avalée par un commentaire → SyntaxError, décodage entités numériques,
   champ Image écrit dans Airtable), test réel : exécution #55 success, 15 photos envoyées + marquées
3. Anti-flood premier passage : 5 photos max/flux ; le run 19:11 UTC a envoyé les plus récentes
