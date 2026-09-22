#!/bin/bash
# vps-sante.sh — contrôle de santé complet du VPS rennesdev.fr
# Sortie : tableau lisible ; code retour 0 = tout vert, 1 = au moins une anomalie.
set -u
ANOM=0
ok()   { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1"; ANOM=1; }
warn() { printf '  ⚠️  %s\n' "$1"; }

echo "== Conteneurs Docker =="
for c in n8n_workflow n8n_db umami_app umami_db ollama netdata filebrowser nav_rennesdev uptime_kuma browserless; do
    state=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)
    [ "$state" = "running" ] && ok "$c : $state" || bad "$c : ${state:-introuvable}"
done

echo "== HTTPS (edge Cloudflare + origine) =="
for d in umami n8n; do
    edge=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$d.rennesdev.fr")
    org=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 --resolve "$d.rennesdev.fr:443:162.19.246.165" "https://$d.rennesdev.fr")
    [ "$edge" = "200" ] && [ "$org" = "200" ] && ok "$d.rennesdev.fr : edge=$edge origine=$org" \
        || bad "$d.rennesdev.fr : edge=$edge origine=$org"
done

# Vhosts récents — 401 SANS auth = basic auth en place (nav, uptime, spectre) ; 200 = page login (fichiers)
echo "== HTTPS vhosts récents (nav / uptime / fichiers / spectre) =="
for entry in "nav:401" "uptime:401" "fichiers:200" "spectre:401"; do
    d=${entry%%:*}; exp=${entry##*:}
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$d.rennesdev.fr")
    [ "$code" = "$exp" ] && ok "$d.rennesdev.fr : $code (attendu $exp)" \
        || bad "$d.rennesdev.fr : $code (attendu $exp)"
done


echo "== Système =="
MEM=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
DISK=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
LOAD=$(cut -d' ' -f1 /proc/loadavg)
NCPU=$(nproc)
[ "$MEM" -lt 90 ] && ok "RAM : ${MEM}% utilisée" || bad "RAM : ${MEM}% utilisée"
[ "$DISK" -lt 85 ] && ok "Disque : ${DISK}% utilisé" || bad "Disque : ${DISK}% utilisé"
if awk "BEGIN{exit !($LOAD <= $NCPU * 1.5)}" 2>/dev/null; then
    ok "Load : $LOAD"
else
    bad "Load : $LOAD (> 1,5 × $NCPU vCPU) — investiguer : pidstat 5 2 -u | grep -E 'containerd$|dockerd$' (piège connu : collecteur Netdata docker trop rapide, voir docs/netdata.md)"
fi

echo "== Fail2ban =="
for j in sshd recidive; do
    banned=$(sudo fail2ban-client status "$j" 2>/dev/null | awk -F: '/Currently banned/{gsub(/[ \t]/,"",$2); print $2}')
    [ -n "${banned:-}" ] && ok "jail $j : $banned ban(s) actif(s)" || bad "jail $j : réponse absente"
done

echo "== Services critiques =="
for s in caddy fail2ban ufw vps-tgbot; do
    systemctl is-active --quiet "$s" && ok "$s : actif" || bad "$s : INACTIF"
done

echo "== Timers (6 attendus) =="
for t in vps-watchdog.timer vps-metrics-report.timer vps-backup.timer vps-backup-reminder.timer github-weekly.timer vps-daily-journal.timer; do
    systemctl is-active --quiet "$t" && ok "$t : actif" || bad "$t : INACTIF"
done

echo "== Netdata (local) =="
nd=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:19999)
[ "$nd" = "200" ] && ok "UI netdata : 200" || bad "UI netdata : $nd"

echo "== Kopia =="
if sudo kopia repository status >/dev/null 2>&1; then
    ok "dépôt connecté"
    LAST=$(sudo kopia snapshot list 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | sort | tail -1)
    if [ -n "$LAST" ]; then
        AGE=$(( ($(date +%s) - $(date -d "$LAST" +%s)) / 3600 ))
        [ "$AGE" -lt 200 ] && ok "dernier snapshot il y a ${AGE}h ($LAST)" \
            || warn "dernier snapshot il y a ${AGE}h ($LAST)"
    else
        bad "aucun snapshot dans le dépôt"
    fi
    if timeout 5 bash -c 'echo > /dev/tcp/100.118.76.30/51515' 2>/dev/null; then
        ok "PC:51515 ouvert"
    else
        warn "PC:51515 fermé (PC éteint — normal la nuit, cf. watchdog)"
    fi
else
    bad "dépôt Kopia NON connecté"
fi

echo "== Certificats origine (Caddy) =="
for d in umami n8n nav uptime fichiers; do
    END=$(echo | openssl s_client -connect 127.0.0.1:443 -servername "$d.rennesdev.fr" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$END" ]; then
        DAYS=$(( ($(date -d "$END" +%s) - $(date +%s)) / 86400 ))
        [ "$DAYS" -gt 14 ] && ok "$d.rennesdev.fr : expire dans ${DAYS}j" \
            || warn "$d.rennesdev.fr : expire dans ${DAYS}j"
    else
        bad "$d.rennesdev.fr : certificat illisible"
    fi
done

echo "== APT =="
APT=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
ok "$APT paquet(s) en attente"

echo "== Canal d'ordres =="
[ -f /home/ubuntu/ORDRES.md ] && { ok "ORDRES.md présent"; echo "     → LE LIRE ET TRAITER"; } \
    || ok "ORDRES.md absent (canal vide)"

echo
[ "$ANOM" -eq 0 ] && { echo "🎯 RÉSULTAT : TOUT EST VERT"; exit 0; } || { echo "🎯 RÉSULTAT : ANOMALIES DÉTECTÉES"; exit 1; }
