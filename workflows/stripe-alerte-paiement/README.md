# Stripe — alerte paiement Telegram

## État (17/09) — EN PRODUCTION ✅

- Workflow **actif**. Webhook Stripe créé par l'utilisateur (endpoint « Session conseil promo »).
- Clé de signature `whsec_...` saisie par l'utilisateur dans `CONFIG.webhookSecret`.
- **Vérification de signature Stripe opérationnelle** (testée : payload signé valide → pas d'alerte ; signature falsifiée → 🚨).
- Test réel : payload `checkout.session.completed` montant 0 → alerte Telegram reçue.

⚠️ Pour que `require('crypto')` fonctionne dans le nœud Code, le compose n8n contient
`NODE_FUNCTION_ALLOW_BUILTIN=crypto` (le task runner n8n 2.x utilise cette variable, PAS `NODES_ALLOW_BUILTIN`).

## Fonctionnement

`Webhook POST /webhook/stripe-paiement` → nœud Code (filtre + formatage) → **Telegram** (conversation Manu bot, chat `8634051625`).

Message envoyé pour chaque paiement :

```
💳 Paiement Stripe reçu — 49.00 EUR
Événement : checkout.session.completed
Client : client@exemple.fr
Reçu le 17/09/2026 14:30:00
```

Événements alertés : `checkout.session.completed`, `payment_intent.succeeded`, `invoice.payment_succeeded`, `charge.succeeded`. Les autres événements sont ignorés silencieusement.

## À faire par l'utilisateur (ordre 2026-09-16 19:31)

1. **Dashboard Stripe → Développeurs → Webhooks → Ajouter un endpoint**
   - URL : `https://n8n.rennesdev.fr/webhook/stripe-paiement`
   - Événements : `checkout.session.completed`, `payment_intent.succeeded`, `invoice.payment_succeeded`
2. Copier la **clé de signature du endpoint** (`whsec_...`) dans `CONFIG.webhookSecret` du nœud « Formate l'alerte paiement ».
3. Activer le workflow dans n8n.

> ⚠️ Tant que `CONFIG.webhookSecret` est vide, la signature Stripe n'est **pas** vérifiée (un ⚠️ est ajouté dans chaque message). Une signature invalide est signalée 🚨.

## Sécurité

- Aucune clé secrète Stripe n'est stockée dans ce dépôt (placeholders vides).
- Le nœud Telegram utilise le credential n8n existant « Telegram account ».
