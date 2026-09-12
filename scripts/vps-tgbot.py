#!/usr/bin/env python3
"""vps-tgbot.py — Bot Telegram de contrôle du VPS (long polling).
Commandes: /backup (sauvegarde complète), /status (état du VPS), /help.
Répond UNIQUEMENT au chat_id configuré. Config: /etc/vps-watchdog-telegram.env
"""
import json, os, subprocess, sys, time, urllib.parse, urllib.request

TOKEN = os.environ["TG_BOT_TOKEN"]
CHAT_ID = os.environ["TG_CHAT_ID"]
API = f"https://api.telegram.org/bot{TOKEN}"

def api(method, **params):
    data = json.dumps(params).encode()
    req = urllib.request.Request(f"{API}/{method}", data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read())

def send(text):
    try:
        api("sendMessage", chat_id=CHAT_ID, text=text[:4000])
    except Exception as e:
        print(f"send error: {e}", flush=True)

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120).stdout.strip()
    except Exception:
        return ""

def cmd_status():
    disk = sh("df --output=pcent / | tail -1").strip()
    mem = sh("free | awk '/Mem:/{printf \"%d\", $3/$2*100}'").strip()
    ct = sh("docker ps --format '{{.Names}}: {{.Status}}'")
    kopia = "✅ connecté" if sh("kopia repository status").strip() else "❌ NON CONNECTÉ"
    snap = sh("kopia snapshot list --all | tail -1") or "aucun"
    pc = "ouvert ✅" if sh("timeout 3 bash -c 'echo > /dev/tcp/100.118.76.30/51515'").strip() else "fermé ❌"
    nxt = sh("systemctl list-timers vps-backup.timer --no-pager | tail -1 | awk '{print $1, $2, $3}'")
    return (f"📊 État VPS\n💾 Disque : {disk}\n🧠 RAM : {mem}%\n"
            f"🐳 Conteneurs :\n{ct}\n"
            f"💾 Kopia : {kopia} | PC 51515 : {pc}\n"
            f"📸 Dernier snapshot : {snap}\n⏰ Prochain backup planifié : {nxt}")

def handle(msg):
    chat = str(msg.get("chat", {}).get("id", ""))
    if chat != CHAT_ID:
        return  # ignore tout autre chat
    text = msg.get("text", "").strip()
    if text.startswith("/backup"):
        send("⏳ Reçu — lancement de la sauvegarde, je te tiens au courant.")
        subprocess.Popen(["/usr/local/bin/vps-backup-on-demand.sh"])
    elif text.startswith("/status"):
        send(cmd_status())
    elif text.startswith("/help") or text == "/start":
        send("🤖 Bot VPS rennesdev.fr\n/backup — lancer la sauvegarde (démarre le serveur Kopia du PC puis sauvegarde)\n/status — état du VPS\n/help — cette aide")
    # texte quelconque: réponse discrète
    elif text:
        send("Commande inconnue. /help pour l'aide.")

def main():
    offset = 0
    print("bot démarré", flush=True)
    while True:
        try:
            r = api("getUpdates", timeout=30, offset=offset)
            for u in r.get("result", []):
                offset = u["update_id"] + 1
                msg = u.get("message") or u.get("edited_message")
                if msg:
                    try:
                        handle(msg)
                    except Exception as e:
                        print(f"handle error: {e}", flush=True)
        except Exception as e:
            print(f"poll error: {e}", flush=True)
            time.sleep(5)

if __name__ == "__main__":
    main()
