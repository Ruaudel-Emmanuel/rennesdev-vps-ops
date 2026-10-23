# Accès Mobile via Tailscale — Open WebUI & Twenty CRM

## Prérequis

1. **Tailscale** installé sur chaque appareil (PC, tablette, téléphone)
   - iOS : https://apps.apple.com/ → Tailscale
   - Android : https://play.google.com/ → Tailscale
   - Windows/macOS : https://tailscale.com/download

2. Tous les appareils doivent être connectés au **même compte Tailscale**
   (compte GitHub `Ruaudel-Emmanuel`)

## Connexion

### Depuis n'importe quel appareil (après Tailscale connecté)

| Service | URL |
|---|---|
| **Open WebUI** (chat IA) | `http://100.75.226.13:8088` |
| **Twenty CRM** | `http://100.75.226.13:8090` |
| *(alternative DNS)* | `http://vps-5532a57a.tail85f845.ts.net:PORT` |

### Premier accès à Open WebUI

1. Ouvrir `http://100.75.226.13:8088`
2. Créer un compte administrateur (première connexion uniquement)
3. Le modèle `qwen2.5:7b` est pré-sélectionné comme modèle par défaut

### Premier accès à Twenty CRM

1. Ouvrir `http://100.75.226.13:8090`
2. Créer un workspace
3. L'interface est responsive — fonctionne sur mobile et desktop

## Architecture de sécurité

```
📱 Appareil mobile (iOS/Android)
      │
      ▼ Tunnel Tailscale (chiffré de bout en bout)
      │
┌─ VPS rennesdev.fr ──────────────────────┐
│  ├─ open_webui      → port 8088         │
│  ├─ twenty_server   → port 8090         │
│  ├─ ollama          → port 11434 (interne) │
│  └─ n8n             → n8n.rennesdev.fr  │
└──────────────────────────────────────────┘
```

- Les services critiques **n'ont PAS de DNS public** (pas dans Cloudflare)
- L'accès est impossible sans Tailscale
- Le moteur de calcul (Ollama) tourne sur le VPS — le téléphone ne fait qu'afficher l'interface

## Dépannage

| Problème | Solution |
|---|---|
| `Connexion refusée` | Vérifier que Tailscale est **actif** sur les deux appareils |
| `Site introuvable` | Vérifier l'IP : `tailscale ip` sur le VPS |
| Interface lente | Le modèle `qwen2.5:3b` est plus léger pour le mobile |
| Redémarrage VPS | Attendre 30s, les services redémarrent automatiquement |

> **Note :** Le port 8088 (Open WebUI) et 8090 (Twenty) ne sont **pas** ouverts sur Cloudflare.
> Ils sont exclusivement accessibles via le tunnel Tailscale → Zero Trust.
