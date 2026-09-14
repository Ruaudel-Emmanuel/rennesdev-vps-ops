---
name: vps-sante
description: Contrôle de santé complet du VPS rennesdev.fr (conteneurs, HTTPS, fail2ban, timers, Kopia, certificats, disque/RAM, APT, ordres Telegram). Utiliser quand l'utilisateur demande un contrôle de santé, un état du VPS, ou au début d'une session de maintenance.
---

# Contrôle de santé VPS rennesdev.fr

## Procédure

1. Lancer le script (le lire d'abord si la session est nouvelle — il référence la
   config du serveur) :

```bash
bash ~/.agents/skills/vps-sante/scripts/vps-sante.sh
```

2. **Interpréter** : le script affiche ✅/❌/⚠️ par check et renvoie
   `TOUT EST VERT` (exit 0) ou `ANOMALIES DÉTECTÉES` (exit 1).

3. **Rapport à l'utilisateur** : résumer en tableau (élément / état), un maximum
   de 10 lignes. Si anomalies :
   - diagnostiquer immédiatement (logs `journalctl -u <service>`, `docker logs`),
   - corriger si le correctif est sûr et dans la ligne des habitudes (voir
     préférences dans `/home/ubuntu/ETAT-VPS.md`),
   - notifier Telegram via `/usr/local/bin/vps-tg.sh` pour les anomalies
     visibles par l'utilisateur (service down, HTTPS KO).

4. **Canal d'ordres** : si le check `ORDRES.md` indique un fichier présent, le
   lire et traiter les ordres AVANT de continuer la session (règle permanente n°6).

## Points de repère

- Valeurs normales : RAM < 90 % (le bot IA ollama peut la faire monter à ~85 %
  temporairement — cf. ETAT-VPS.md), disque < 85 %, 6 conteneurs, 4 timers.
- Kopia : le PC peut être éteint la nuit (port 51515 fermé = ⚠️ et non ❌) ;
  le dépôt doit rester connectable et avoir un snapshot de moins de ~8 jours
  (backup hebdo le dimanche 19:30 Paris).
- Le watchdog (`vps-watchdog.timer`, toutes les 15 min) envoie déjà les alertes
  Telegram — ne pas doublonner ; ici on établit l'état complet pour l'utilisateur.

## Référence

- Journal d'état : `/home/ubuntu/ETAT-VPS.md` (état courant) + archives
  `ETAT-VPS-archive-*.md` (historique mensuel, committé sur GitHub).
- Docs ops : `/home/ubuntu/projects/rennesdev-vps-ops/` (repo GitHub
  `Ruaudel-Emmanuel/rennesdev-vps-ops`, push via webhook n8n — voir
  `docs/push-github.md`, méthode sans PAT en session).
