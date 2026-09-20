---
name: uptime-kuma
description: Uptime-Kuma EN PRODUCTION sur le VPS : monitoring 24/7 des services (8 moniteurs UP), alertes Telegram, dashboard https://uptime.rennesdev.fr, rapports de disponibilité. Utiliser pour la phase Résilience/Garantie : rassurer un client, justifier une maintenance ou prouver la disponibilité.
---

# 📡 Uptime-Kuma — Monitoring et Garantie de Disponibilité

## Objectif de ce Skill
Uptime-Kuma est la brique de **garantie de service** : un dashboard auto-hébergé qui vérifie en permanence que les services critiques (n8n, HTTPS, Ollama, File Browser…) répondent, et qui alerte immédiatement sur Telegram en cas de coupure. C'est l'outil qui permet de **promettre** une disponibilité au client — et de la prouver.

---

## 🎯 Pourquoi c'est un argument commercial (et pas juste de la technique)
- **Sans monitoring :** "On essaie de faire attention." → parole d'exécutant.
- **Avec monitoring :** "Chaque service critique est vérifié toutes les X minutes, 24/7. En cas de panne, je suis alerté avant vous. Je peux vous montrer l'historique de disponibilité de vos services à tout moment." → parole de **Directeur de la Transformation Numérique**.
- Le dashboard d'uptime devient un **livrable contractuel** : rapport mensuel de disponibilité envoyé au client.

---

## 🏗️ Déploiement sur le VPS (rennesdev.fr) — **EN PRODUCTION depuis le 20/09**
- **Conteneur :** `uptime_kuma` (`louislam/uptime-kuma:1`), `127.0.0.1:3001`, volume `kuma_data`, mem_limit 512m, réseau Docker `apps`, healthcheck actif.
- **Accès :** https://uptime.rennesdev.fr (basic auth Caddy + login Kuma `emmanuel`, creds `/etc/caddy/uptime-auth.txt` root 600). ⚠️ Record DNS Cloudflare à créer si 404.
- **8 moniteurs actifs (intervalle 60 s, maxretries 2) :** n8n `/healthz`, Umami, Nav, Fichiers, Netdata (basic auth — piège : `authMethod=HTTP_BASIC` requis), Browserless (`?token=`), Ollama, port PostgreSQL `n8n_db:5432`.
- **Notifications :** Telegram (même canal que les alertes existantes), avec `heartbeat retry` pour éviter les faux positifs (2-3 échecs avant alerte).

## 🤝 Complémentarité avec l'existant
- **Netdata** = santé de la *machine* (CPU, RAM, disque, réseau).
- **Uptime-Kuma** = disponibilité des *services* (ce que le client "voit").
- **post-mortem.md** = ce qu'on fait quand l'alerte a sonné.
- **vps-sante** (skill opérationnel) = le contrôle manuel hebdomadaire des mêmes points.

## 💬 Phrases clés pour le client
- "Vos services sont surveillés 24/7, toutes les minutes. Si quelque chose tombe, je suis prévenu en moins de 2 minutes."
- "Chaque mois, vous recevez le taux de disponibilité réel de vos outils — mesuré, pas promis."
- "La supervision fait partie du forfait. Vous n'avez rien à vérifier."

### 🔑 Résumé pour l'agent
Utiliser ce skill dans la phase **Résilience/Garantie** de la conversation : rassurer un client inquiet, justifier une maintenance mensuelle, ou valoriser l'offre face à un concurrent "bricoleur".
