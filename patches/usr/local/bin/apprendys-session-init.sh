#!/bin/bash
# Apprendys - Init session : trust + wallpaper + panel + preload IA

# Fix 1 : .desktop trusted
# Attend que gvfs-daemon soit pret (max 15s)
for i in $(seq 1 15); do
    gio info /home/apprendys/Bureau/mes-devoirs.desktop >/dev/null 2>&1 && break
    sleep 1
done

# xfdesktop 4.18 exige trusted=true ET xfce-exe-checksum=SHA256(contenu)
for f in /home/apprendys/Bureau/mes-devoirs.desktop \
          /home/apprendys/Bureau/je-recherche.desktop \
          /home/apprendys/Bureau/mes-lecons.desktop; do
    CHKSUM=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
    gio set "$f" metadata::trusted true 2>/dev/null
    [ -n "$CHKSUM" ] && gio set "$f" metadata::xfce-exe-checksum "$CHKSUM" 2>/dev/null
done

# Fix 2 : wallpaper dynamique (detecte le vrai nom du moniteur)
WALLPAPER="/home/apprendys/.local/share/backgrounds/apprendys-wallpaper.png"
if [ -f "$WALLPAPER" ]; then
    for monitor in $(xrandr --listmonitors 2>/dev/null | tail -n +2 | awk '{print $NF}'); do
        for ws in 0 1 2 3; do
            xfconf-query -c xfce4-desktop \
                -p "/backdrop/screen0/monitor${monitor}/workspace${ws}/last-image" \
                -s "$WALLPAPER" --create -t string 2>/dev/null
            xfconf-query -c xfce4-desktop \
                -p "/backdrop/screen0/monitor${monitor}/workspace${ws}/image-path" \
                -s "$WALLPAPER" --create -t string 2>/dev/null
            xfconf-query -c xfce4-desktop \
                -p "/backdrop/screen0/monitor${monitor}/workspace${ws}/image-style" \
                -s 5 --create -t int 2>/dev/null
        done
    done
fi

# Redemarrage propre de xfdesktop pour appliquer trust + wallpaper
pkill xfdesktop 2>/dev/null
sleep 1
xfdesktop &

# Fix panel : ajouter Whisker Menu (plugin-1) si absent du panel
IDS=$(xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids 2>/dev/null)
if [ -n "$IDS" ] && ! echo "$IDS" | grep -qx "1"; then
    ARGS=""
    for id in 1 $IDS; do
        ARGS="$ARGS -t int -s $id"
    done
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids $ARGS 2>/dev/null
    xfce4-panel --restart 2>/dev/null &
fi

# Fix 6 : precharge modeles IA en arriere-plan
# STT : P4 upgrade prioritaire, fallback vosk squashfs
P4_STT="/mnt/apprendys/models/stt"
VOSK_DEFAULT="/opt/vosk/model-fr"

if [ -d "$P4_STT" ] && [ -n "$(ls -A "$P4_STT" 2>/dev/null)" ]; then
    MODEL_STT="$P4_STT"
    if ls "$P4_STT"/*.bin >/dev/null 2>&1; then
        MODEL_TYPE="whisper"
    else
        MODEL_TYPE="vosk"
    fi
elif [ -d "$VOSK_DEFAULT" ]; then
    MODEL_STT="$VOSK_DEFAULT"
    MODEL_TYPE="vosk"
else
    MODEL_TYPE="none"
fi

case "$MODEL_TYPE" in
    vosk)
        APPRENDYS_STT_MODEL="$MODEL_STT" python3 -c \
            "import vosk, os; vosk.Model(os.environ['APPRENDYS_STT_MODEL'])" \
            >/dev/null 2>&1 &
        ;;
    whisper)
        ;;
    none)
        ;;
esac

# TTS : piper binaire natif (<1s), pas de preload utile
# L'upgrade P4 est detecte directement par apprendys-tts.sh via /mnt/apprendys/models/tts/

# Fix panel launchers : /mnt/devoirs -> /home/apprendys/Devoirs
# Evite "Impossible d'ouvrir /mnt/devoirs" si P5 pas encore monte au premier clic
find /home/apprendys/.config/xfce4/panel -name "*.desktop" 2>/dev/null | while read f; do
    grep -q "/mnt/devoirs" "$f" 2>/dev/null && \
        sed -i 's|/mnt/devoirs|/home/apprendys/Devoirs|g' "$f" 2>/dev/null || true
done
# Fix icones bureau : meme correction
find /home/apprendys/Bureau -name "*.desktop" 2>/dev/null | while read f; do
    grep -q "/mnt/devoirs" "$f" 2>/dev/null && \
        sed -i 's|/mnt/devoirs|/home/apprendys/Devoirs|g' "$f" 2>/dev/null || true
done

# Fix LibreOffice : chemin autosave stale (/mnt/devoirs -> ~/Devoirs)
LO_REG="/home/apprendys/.config/libreoffice/4/user/registrymodifications.xcu"
if [ -f "$LO_REG" ]; then
    sed -i 's|file:///mnt/devoirs|file:///home/apprendys/Devoirs|g' "$LO_REG" 2>/dev/null || true
fi

# Fix GTK bookmarks : retirer entrees /mnt/devoirs stales
GTK_BOOKMARKS="/home/apprendys/.config/gtk-3.0/bookmarks"
if [ -f "$GTK_BOOKMARKS" ]; then
    sed -i '\|file:///mnt/devoirs|d' "$GTK_BOOKMARKS" 2>/dev/null || true
fi

# Fix Chromium : supprimer SingletonLock stale (laisse par reboot sans fermeture propre)
# Sans ca : Chromium refuse de demarrer avec "profil utilise par un autre processus"
CHROMIUM_DIR="/home/apprendys/.config/chromium"
if [ -d "$CHROMIUM_DIR" ]; then
    rm -f "$CHROMIUM_DIR/SingletonLock" \
          "$CHROMIUM_DIR/SingletonSocket" \
          "$CHROMIUM_DIR/SingletonCookie" 2>/dev/null || true
fi

# Fix Chromium : dossier "Enregistrer sous" -> ~/Devoirs
CHROMIUM_PREFS="/home/apprendys/.config/chromium/Default/Preferences"
if [ -f "$CHROMIUM_PREFS" ]; then
    python3 -c "
import json
with open('$CHROMIUM_PREFS') as f:
    p = json.load(f)
p.setdefault('savefile', {})['default_directory'] = '/home/apprendys/Devoirs'
with open('$CHROMIUM_PREFS', 'w') as f:
    json.dump(p, f)
" 2>/dev/null || true
fi
