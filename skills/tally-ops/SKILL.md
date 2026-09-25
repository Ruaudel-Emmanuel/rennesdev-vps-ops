---
name: tally-ops
description: Tout ce qui concerne l'intégration Tally (formulaires) sur le VPS — workflows n8n « Tally — alerte message » et « Tally — photographe », endpoints webhooks, vérification de signature (tly-, hexa/base64). Utiliser dès qu'on parle de Tally, formulaires, webhooks Tally ou signature.
---

# Tally — mémoire opérationnelle

## Workflows
| Workflow | Endpoint | Rôle |
|---|---|---|
| « Tally — alerte message Telegram » | `POST https://n8n.rennesdev.fr/webhook/tally-alerte` | alerte générique : nom du formulaire, id réponse, aperçu des champs ; `CONFIG.LIEN_CLIENT` = placeholder pour lien futur |
| « Tally — photographe » | `POST https://n8n.rennesdev.fr/webhook/tally-photographe` | message 📸 « Pour : le photographe de Rennesdev.fr » (formulaire « Contact photographe - Emmanuel Ruaudel ») |

Les deux : Code (formatage + vérif signature) → Telegram (chat 8634051625).

## Vérification de signature Tally
- En-tête : `Tally-Signature`, HMAC-SHA256 sur `<t>.<payload>`.
- **Format du secret : `tly-...`** — ⚠️ N'A PAS le format Stripe `whsec_` (piège du 17/09 : un script cherchant `whsec_` signait avec un secret vide → faux « INVALIDE »).
- **hexa ET base64 acceptés** (2 objets HMAC séparés — ne jamais réutiliser un objet Digest).
- Secret dans `CONFIG.webhookSecret` du nœud Code (formulaire photographe : clé collée par l'utilisateur le 17/09, testée OK).

## État
- Les deux workflows **actifs et testés en réel** (payload valide → pas d'alerte ; falsifié → 🚨).
- Formulaire photographe : webhook branché côté Tally, signature opérationnelle ; `LIEN_CLIENT` à remplir plus tard.

## Côté utilisateur (Tally)
- Settings du formulaire → Webhooks → ajouter l'URL du endpoint → copier la clé `tly-...` → coller dans `CONFIG.webhookSecret`.
