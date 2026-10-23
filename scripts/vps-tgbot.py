#!/usr/bin/env python3
"""vps-tgbot.py — Bot Telegram de contrôle du VPS (long polling).
Commandes: /backup (sauvegarde complète), /status (état du VPS), /ordres (ordres
en attente), /ok (vider les ordres), /help.
Tout message NON-commande est enregistré comme « ordre » pour l'assistant
(lecture de /home/ubuntu/ORDRES.md au début de chaque session).
Photos et documents enregistrés dans /home/ubuntu/ORDRES-files/ (référencés dans ORDRES.md).
Répond UNIQUEMENT au chat_id configuré. Config: /etc/vps-watchdog-telegram.env
"""
import json, os, subprocess, sys, time, urllib.request

TOKEN = os.environ["TG_BOT_TOKEN"]
CHAT_ID = os.environ["TG_CHAT_ID"]
API = f"https://api.telegram.org/bot{TOKEN}"
ORDRES = "/home/ubuntu/ORDRES.md"
ORDRES_ARCHIVE = "/home/ubuntu/ORDRES-archive.md"
ORDRES_FILES = "/home/ubuntu/ORDRES-files"

ORDRES_HEADER = (
    "# 📥 Ordres en attente (envoyés par l'utilisateur via le bot Telegram)\n"
    "> À lire et TRAITER au début de chaque session assistant. Après traitement, "
    "marquer `✅ [date]` ou retirer l'entrée.\n\n"
)

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

def ordres_body():
    try:
        with open(ORDRES) as f:
            return f.read()
    except FileNotFoundError:
        return ""

def nb_ordres():
    return ordres_body().count("\n### [")

def add_ordre(text):
    ts = time.strftime("%Y-%m-%d %H:%M")
    header = "" if os.path.exists(ORDRES) else ORDRES_HEADER
    with open(ORDRES, "a") as f:
        f.write(f"{header}### [{ts}] {text}\n")
    os.chown(ORDRES, 1000, 1000)  # ubuntu:ubuntu — l'assistant le lit sans sudo
    os.chmod(ORDRES, 0o644)

def vider_ordres():
    body = ordres_body()
    if body:
        with open(ORDRES_ARCHIVE, "a") as f:
            f.write(f"\n--- archivé {time.strftime('%Y-%m-%d %H:%M')} ---\n{body}\n")
        os.chown(ORDRES_ARCHIVE, 1000, 1000)
    if os.path.exists(ORDRES):
        os.remove(ORDRES)

def telecharger(file_id, nom_suggere):
    """Télécharge un fichier Telegram dans ORDRES_FILES, retourne le chemin local."""
    info = api("getFile", file_id=file_id)
    chemin_telegram = info.get("result", {}).get("file_path")
    if not chemin_telegram:
        return None
    ext = os.path.splitext(chemin_telegram)[1] or ".bin"
    os.makedirs(ORDRES_FILES, exist_ok=True)
    nom = f"{time.strftime('%Y-%m-%d-%H%M%S')}-{nom_suggere}{ext}"
    dest = os.path.join(ORDRES_FILES, nom)
    url = f"{API}/file/{chemin_telegram}"
    urllib.request.urlretrieve(url, dest)
    os.chown(dest, 1000, 1000)
    os.chmod(dest, 0o644)
    return dest

def handle_fichier(msg, caption):
    """Retourne le texte d'ordre décrivant un fichier reçu, ou None."""
    photo = msg.get("photo")          # liste de tailles croissantes
    document = msg.get("document")
    if photo:
        file_id = photo[-1]["file_id"]
        label, ext = "photo", ".jpg"
    elif document:
        file_id = document["file_id"]
        label = "document"
        nom_orig = os.path.splitext(document.get("file_name", ""))[0]
        ext = os.path.splitext(document.get("file_name", ""))[1]
        if not nom_orig:
            nom_orig = "fichier"
    else:
        return None
    if document:
        dest = telecharger(file_id, nom_orig + ext)
    else:
        dest = telecharger(file_id, label)
    if not dest:
        return "⚠️ Fichier Telegram reçu mais TÉLÉCHARGEMENT ÉCHOUÉ" + (f" — légende : {caption}" if caption else "")
    taille = os.path.getsize(dest) // 1024
    note = f"📎 {label.capitalize()} reçue du bot Telegram : `{dest}` ({taille} Ko)"
    if caption:
        note += f"\n  Légende/utilisateur : {caption}"
    return note

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
    elif text.startswith("/ordres"):
        n = nb_ordres()
        if n == 0:
            send("📭 Aucun ordre en attente.")
        else:
            send(f"📥 {n} ordre(s) en attente :\n\n{ordres_body().split('---', 1)[-1][-2500:]}")
    elif text.startswith("/ok") or text.startswith("/clear"):
        n = nb_ordres()
        vider_ordres()
        send(f"🧹 {n} ordre(s) vidé(s) — archivés dans ORDRES-archive.md.")
    elif text.startswith("/help") or text == "/start":
        send("🤖 Bot VPS rennesdev.fr\n"
             "/backup — lancer la sauvegarde (démarre le serveur Kopia du PC puis sauvegarde)\n"
             "/status — état du VPS\n"
             "/ordres — lister les instructions en attente pour l'assistant\n"
             "/ok — vider les instructions (après traitement)\n"
             "📝 Écris simplement un message libre (sans /) pour laisser une instruction à l'assistant — il la lira à sa prochaine session.\n"
             "📸 Tu peux aussi envoyer des photos/documents : ils sont sauvegardés et signalés à l'assistant.\n"
             "/help — cette aide")
    elif text:
        n_avant = nb_ordres()
        add_ordre(text)
        send(f"✅ Instruction enregistrée ({n_avant + 1} en attente). "
             f"L'assistant la lira au début de sa prochaine session. "
             f"(/ordres pour la liste, /ok pour vider)")
    elif msg.get("photo") or msg.get("document"):
        caption = msg.get("caption", "").strip()
        note = handle_fichier(msg, caption)
        if note:
            n_avant = nb_ordres()
            add_ordre(note)
            send(f"📎 Fichier sauvegardé sur le VPS ({n_avant + 1} ordre en attente). "
                 f"L'assistant le verra à sa prochaine session.")

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
