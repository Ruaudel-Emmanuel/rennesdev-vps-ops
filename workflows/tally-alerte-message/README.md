# Tally — alerte message Telegram

## État (17/09) — EN PRODUCTION, signature vérifiée ✅

- Workflow **actif**. Webhook Tally créé par l'utilisateur (formulaire « Contact freelance - Emmanuel Ruaudel »).
- `CONFIG.LIEN_CLIENT` renseigné (https://tally.so/r/WO26DL).
- Clé de signature Tally collée par l'utilisateur dans `CONFIG.webhookSecret` — **format Tally : commence par `tly-`** (pas `whsec_`).
- **Vérification de signature opérationnelle** (testée : payload signé valide → message propre ; signature falsifiée → 🚨).
- Note : ce formulaire est pour le **développeur** de Rennesdev.fr — une autre alerte sera créée pour le **photographe**.

## Fonctionnement

`Webhook POST /webhook/tally-alerte` → nœud Code (formatage) → **Telegram** (conversation Manu bot, chat `8634051625`).

Alerte **simple** à chaque réponse au formulaire Tally :

```
📩 Nouveau message via Tally — Contact site
Réponse : sub_xxxxx

Nom : Dupont
Message : Bonjour, je voudrais un devis
Reçu le 17/09/2026 14:30:00
```

Le texte détaillé du client est stocké dans une autre application — un lien (`CONFIG.LIEN_CLIENT` dans le nœud Code) sera ajouté plus tard et apparaîtra en fin de message (➡️).

## À faire par l'utilisateur (ordre 2026-09-16 19:35)

1. **Tally → formulaire `WO26DL` → Settings → Webhooks → Add webhook**
   - URL : `https://n8n.rennesdev.fr/webhook/tally-alerte`
2. Activer le workflow dans n8n.
3. Plus tard : renseigner `CONFIG.LIEN_CLIENT` dans le nœud « Formate l'alerte Tally ».

## Sécurité

- Aucun secret : le webhook Tally n'en demande pas ; l'URL est la seule « clé ».
- Le nœud Telegram utilise le credential n8n existant « Telegram account ».
