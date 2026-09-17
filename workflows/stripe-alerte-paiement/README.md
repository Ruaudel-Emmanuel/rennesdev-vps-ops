# Stripe — alerte paiement Telegram

Workflow **désactivé** en attente des clés Stripe (à saisir par l'utilisateur).

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
