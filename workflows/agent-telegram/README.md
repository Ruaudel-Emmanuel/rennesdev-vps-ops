# 🤖 Agent Telegram (n8n + Ollama)

Assistant IA conversationnel sur Telegram, **100 % auto-hébergé** : n8n orchestre, Ollama fait l'inférence en local sur le VPS, la mémoire de conversation est persistée en PostgreSQL.

```
Telegram (bot dédié) ──► [Chat autorisé ?] ──► AI Agent ──► Telegram (réponse)
                                              │
                          Ollama qwen2.5:7b ──┤
                          Postgres Chat Memory┘
```

## Architecture

| Composant | Rôle | Détail |
|---|---|---|
| **Telegram Trigger** | Reçoit les messages | Bot dédié créé via BotFather (⚠️ ne pas réutiliser le bot watchdog : Telegram = 1 consommateur par bot) |
| **Chat autorisé ?** (Filter) | Sécurité | N'accepte que `chat.id = 8634051625` — tout autre expéditeur est ignoré silencieusement |
| **AI Agent** | Orchestraton | Prompt = `{{ $json.message.text }}`, persona en systemMessage (assistant personnel d'Emmanuel, réponses en français) |
| **Ollama Chat Model** | LLM | `qwen2.5:7b` (4,7 Go) via `http://ollama:11434` (réseau Docker `apps`) |
| **Postgres Chat Memory** | Mémoire | Historique persistant en base `n8n` (table `n8n_chat_histories`), clé de session = `chat.id` |
| **Send a text message** | Réponse | `{{ $json.output }}` vers le chat autorisé |

## Installation

1. **Prérequis** : n8n (PostgreSQL), conteneur Ollama sur le même réseau Docker (`apps`).
2. **Modèle** : `docker exec ollama ollama pull qwen2.5:7b`
3. **Bot Telegram** : créer un bot via [@BotFather](https://t.me/BotFather), récupérer le token.
4. **Import** : dans n8n → Workflows → Import from File → `workflow.json`.
5. **Credentials à recréer** (non inclus dans le JSON, volontairement) :
   - `Telegram account` : token du bot dédié
   - `Ollama account` : base URL `http://ollama:11434`
   - `Postgres account` : host `n8n_db`, base `n8n`, user `n8n`
6. **Filtre** : dans le nœud « Chat autorisé ? », remplacer `8634051625` par votre propre `chat.id`.
7. **Activer** le workflow (le webhook Telegram s'enregistre via l'URL publique de n8n, ici `https://n8n.rennesdev.fr`).

## Notes techniques

- **RAM** : le modèle 7B utilise ~5 Go une fois chargé (VPS 7,6 Go) ; Ollama le décharge après `OLLAMA_KEEP_ALIVE` (30 min ici).
- **1 consommateur par bot** : le polling/webhook Telegram ne supporte qu'un seul client — d'où un bot dédié, distinct du bot de supervision.
- **Mémoire persistante** : contrairement au buffer window en RAM, l'historique survit aux redémarrages de n8n.
- Le VPS n'expose qu'Ollama en `127.0.0.1:11434` et n8n en `127.0.0.1:5678` — tout passe par le reverse proxy Caddy + Cloudflare.
