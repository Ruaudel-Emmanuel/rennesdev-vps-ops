# Cadence de maintenance GitHub — règle des 3 niveaux

Établie le 2026-09-15 après inventaire des 97 dépôts du compte `Ruaudel-Emmanuel`
(79 archivés, 18 conservés).

## Les 3 niveaux

| Niveau | Projets | Fenêtre de commit | Revue |
|---|---|---|---|
| **1 — Vitrine & production** | `rennesdev`, `rennesdev-vps-ops`, `RuaudelEmmanuel.github.io`, `RuaudelPhoto` | **7 jours** | mensuelle |
| **2 — Outils métier** | `Rennesdev-api`, `Fiscale-vps`, `Trombi`, `construction-site-tracker`, `Besoin-visio`, `local_contextual_ai`, `ai_gemma_service`, `surveillance-tarifaire` | **14 jours** | mensuelle |
| **3 — Expérimentations** | tout le reste (archivés ou non suivis) | libre | archivage à 90 j sans commit |

## Radar automatique (implémenté)

Le workflow n8n **« Agent Telegram »** (déclencheur Horloge 07:00 Europe/Paris) calcule
chaque matin, dans le nœud « Prépare le résumé » :

- la liste des dépôts **non archivés** avec leur âge de dernier push ;
- les **dépassements de fenêtre** N1/N2 (lignes `⚠️ N1 — repo : X jours sans commit`) ;
- les signaux habituels (description manquante, dormants > 60 j hors cadence).

L'agent IA ajoute une section **« ⏳ À committer »** reprenant chaque dépassement avec une
suggestion d'avancement, puis ses **« 💡 Conseils »** (2-3 max).

Les fenêtres sont codées dans `NIVEAU1` / `NIVEAU2` (dictionnaires `nom → jours`) dans le
jsCode du nœud — à ajuster si la liste des projets suivis évolue.

## Règles d'hygiène

1. Micro-commit dès qu'on touche un projet (messages réels, pas « Add files via upload »).
2. Revue d'inventaire GitHub le 1er de chaque mois, couplée à la rotation de `ETAT-VPS.md`.
3. Projet abandonné → `archived: true` (visible mais honnête).
4. Doublons à ne pas recréer (leçons de l'inventaire 2026-09) : `Fiscale-vps`/`Fisclale-vps`/
   `Fiscale_vps`, `Devis-Python`/`Devis-Python-Steamlit`.

## Dépôts conservés au 2026-09-15

Actifs (2) : `rennesdev`, `rennesdev-vps-ops`
Top 10 dormants à garder actifs : `RuaudelEmmanuel.github.io`, `Rennesdev-api`, `Fiscale-vps`,
`Trombi`, `construction-site-tracker`, `Besoin-visio`, `RuaudelPhoto`, `local_contextual_ai`,
`ai_gemma_service`, `surveillance-tarifaire`
Actifs récents (≤ 30 j, non classés) : `test-architecture-openclaw`, `test-workflow-ollama-openclaw`,
`Ai-agent-prosgres`, `Session-conseil-stripe`, `Booking-Conseil---Stripe`, `ia-nano-google-local`
