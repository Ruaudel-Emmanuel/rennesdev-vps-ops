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

## Incident résolu — collecteur Docker qui martelait l'API (2026-09-21)

**Symptôme** : load average ~5-6 en continu depuis le 10/09 (date du basculement
Docker sur le snapshotter containerd), sans processus visible en `ps` —
`containerd` et `dockerd` brûlaient chacun ~30-40 % CPU (≈ 40 h de CPU chacun
en 11 jours). Surveillance et rappels restent basés sur Netdata : aucun impact
utilisateur, mais ~2 cœurs gaspillés en permanence.

**Diagnostic** : arrêt temporaire de Netdata → containerd/dockerd tombent à
0,2 % CPU. Coupable : le collecteur go.d **docker** (job `local`, charts
`docker_local.*`), qui interroge l'API Docker **toutes les secondes**
(`/info`, `/images/json`, `/containers/json` avec filtres health).
`/images/json` est devenu très coûteux avec le snapshotter containerd
(store images 16 Go) → ~80 % de CPU combinés.

**Correctifs appliqués** :
1. `/var/lib/docker/volumes/netdata_netdataconfig/_data/go.d/docker.conf`
   (créé) : job `local` avec `update_every: 30` (au lieu de 1 s).
2. Healthcheck de **filebrowser** abaissé à 60 s (l'image impose 5 s par défaut
   → ~17 000 spawns runc/jour). Override dans `~/filebrowser/docker-compose.yml` :
   ```yaml
   healthcheck:
     test: ["CMD-SHELL", "/healthcheck.sh"]
     interval: 60s
     timeout: 5s
     retries: 3
   ```

**Résultat** : containerd/dockerd à 0,1 % CPU, load 5,9 → ~1,4. Chartes
`docker_local.*` toujours produites. ⚠️ Si l'image Netdata est mise à jour,
re-vérifier la charge (le nightly peut changer les défauts du collecteur) :
`pidstat 5 2 -u | grep -E 'containerd$|dockerd$'`.

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
