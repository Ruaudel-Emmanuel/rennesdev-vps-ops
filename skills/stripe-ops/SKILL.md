---
name: stripe-ops
description: Tout ce qui concerne l'intégration Stripe sur le VPS — workflow n8n « Stripe — alerte paiement Telegram », endpoint webhook, vérification de signature (whsec_, HMAC-SHA256). Utiliser dès qu'on parle de Stripe, paiements, checkout ou signature webhook.
---

# Stripe — mémoire opérationnelle

## Workflow « Stripe — alerte paiement Telegram »
- **Endpoint** : `POST https://n8n.rennesdev.fr/webhook/stripe-paiement`
- Chaîne : Webhook → Code (filtre événements + formatage + **vérif signature**) → Telegram (chat 8634051625).
- Événements acceptés : `checkout.session.completed`, `payment_intent.succeeded`, `invoice.payment_succeeded`, `charge.succeeded`.

## Vérification de signature
- En-tête Stripe : `Stripe-Signature`, HMAC-SHA256 sur `<t>.<payload>` (**corps brut**, pas re-sérialisé — mais vérification multi-candidats : brut + re-sérialisé).
- Secret : format **`whsec_...`** (⚠️ PAS le format Tally — voir skill `tally`), stocké dans `CONFIG.webhookSecret` du nœud Code.
- Si `webhookSecret` vide → mention ⚠️ dans le message (signature non vérifiée).
- `require('crypto')` doit être possible : variable **`NODE_FUNCTION_ALLOW_BUILTIN=crypto`** dans le compose n8n (déjà fait le 17/09). Piège `Digest already called` : ne JAMAIS réutiliser un objet HMAC → 2 objets séparés si hexa + base64.

## Historique / état
- Créé le 17/09, activé, clés saisies par l'utilisateur, **testé en réel** : payload signé valide → aucune alerte ; signature falsifiée → 🚨 Telegram ; paiement réel (montant 0) → alerte reçue.

## Côté utilisateur (dashboard Stripe)
- Endpoint webhook dans le dashboard → copier la clé `whsec_...` → coller dans `CONFIG.webhookSecret`.
