# Tally — alerte photographe Telegram

## État (17/09) — ACTIF, en attente de la clé Tally du photographe

- Workflow **actif**. Pour le formulaire Tally **« Contact photographe - Emmanuel Ruaudel »** (photographe de Rennesdev.fr).
- Test réel : alerte Telegram reçue (`📸 Nouveau message via Tally — Contact photographe`, aperçu des champs).
- ⚠️ **Reste à faire par l'utilisateur** :
  1. Dans Tally (formulaire photographe) → Settings → Webhooks → ajouter `https://n8n.rennesdev.fr/webhook/tally-photographe`
  2. Coller la clé de signature de **ce** webhook (elle commence par `tly-`) dans `CONFIG.webhookSecret` du nœud « Formate l'alerte photographe »
  3. Plus tard : renseigner `CONFIG.LIEN_CLIENT` (lien vers l'appli où est stocké le texte du client)

## Fonctionnement

`Webhook POST /webhook/tally-photographe` → nœud Code (formatage) → **Telegram** (conversation Manu bot, chat `8634051625`).

Message :

```
📸 Nouveau message via Tally — Contact photographe
Pour : le photographe de Rennesdev.fr
Réponse : sub_xxxxx

Nom : ...
Message : ...
➡️ (lien ajouté plus tard)
Reçu le 17/09/2026 15:00:00
```

La vérification de signature Tally est câblée (en-tête `Tally-Signature`, HMAC-SHA256 sur `<t>.<payload>`, hexa et base64 acceptés). Tant que `CONFIG.webhookSecret` est vide, la signature n'est pas vérifiée.

## Sécurité

- Aucun secret dans ce dépôt (placeholders vides).
- Le nœud Telegram utilise le credential n8n existant « Telegram account ».
