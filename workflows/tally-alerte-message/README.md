# Tally — alerte message Telegram

Workflow **désactivé** en attente de l'ajout du webhook côté Tally (à faire par l'utilisateur).

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
