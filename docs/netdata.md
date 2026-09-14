# Netdata — supervision temps réel du VPS

Installé le 2026-09-14 à la demande de l'utilisateur (choix retenu face à
Prometheus : stack mono-conteneur, ~200-300 Mo RAM, dashboards sans configuration).

## Stack

- Fichier : `~/netdata/docker-compose.yml` (conteneur `netdata`, réseau Docker par défaut)
- Image : `netdata/netdata:latest`
- **UI : `http://127.0.0.1:19999`** — bind localhost uniquement, **jamais exposé** (rien
  dans UFW, pas de vhost Caddy). Accès depuis le PC via tunnel SSH :

  ```powershell
  # PowerShell Windows :
  ssh -L 19999:127.0.0.1:19999 ubuntu@162.19.246.165
  # puis ouvrir http://localhost:19999 dans le navigateur (laisser le terminal ouvert)
  ```

## Ce que le conteneur voit

- `pid: host` + `/proc` et `/sys` hôtes (ro) : CPU, RAM, disques, réseau, processus du VPS
- `/:/host/root:ro` : espace disque de tous les points de montage hôtes
- `/var/run/docker.sock` (ro) : métriques de **tous les conteneurs** (n8n, umami, ollama, netdata lui-même)
- `DISABLE_TELEMETRY=1` : télémétrie désactivée

## Coût mesuré au 2026-09-14

- RAM : ~200 Mo (1,3 → 1,5 Go utilisée sur 7,6 Go)
- Disque : cache 14 Mo au démarrage (croissance lente, rétention par défaut)

## Maintenance

```bash
cd ~/netdata && docker compose pull && docker compose up -d   # mise à jour
docker exec netdata netdata-admin ...                          # (si besoin)
```

- Le conteneur `netdata` est surveillé par le watchdog (`/usr/local/bin/vps-watchdog.sh`,
  liste mise à jour le 2026-09-14 : n8n_workflow, n8n_db, umami_app, umami_db, ollama, netdata).
- Alerte RAM du watchdog inchangée (seuil 90 %) — netdata ne la fait pas bouger.
- Pas d'alerting Netdata actif (les alertes restent assurées par le watchdog → Telegram),
  pour éviter les doublons.

## Décision Prometheus (2026-09-14)

Prometheus + Grafana écarté pour ce VPS : ~500 Mo RAM permanents + maintenance,
alors que ollama (qwen2.5:7b, ~5 Go) et le backup Kopia (pic 3,9 Go) occupent déjà
la machine. À reconsidérer si plusieurs serveurs à superviser (Prometheus central
sur une autre machine, qui viendrait scraper le VPS).
