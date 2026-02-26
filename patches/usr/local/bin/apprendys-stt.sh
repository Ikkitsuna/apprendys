#!/bin/bash
# ==========================================================
# Apprendys - STT (Speech-to-Text) Dictee Vocale
# CF-Informatik974 - Fevrier 2026
# Vosk offline + xdotool pour taper le texte
# ==========================================================

PIDFILE="/tmp/apprendys-stt.pid"
RATE=16000

# Detection modele STT : P4 upgrade prioritaire, fallback squashfs
P4_STT="/mnt/apprendys/models/stt"
VOSK_DEFAULT="/opt/vosk/model-fr"

if [ -d "$P4_STT" ] && ! ls "$P4_STT"/*.bin >/dev/null 2>&1; then
    # P4 contient un modele Vosk (pas de .bin = pas Whisper)
    VOSK_MODEL="$P4_STT"
elif [ -d "$VOSK_DEFAULT" ]; then
    VOSK_MODEL="$VOSK_DEFAULT"
else
    notify-send -i dialog-error "Erreur Dictee" "Modele vocal non trouve." -t 3000
    exit 1
fi

# Toggle : si deja en cours, on arrete
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        rm -f "$PIDFILE"
        notify-send -i audio-input-microphone "Dictee terminee" "Le micro est eteint." -t 2000
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# Notification de demarrage
notify-send -i audio-input-microphone "Dictee activee !" "Parle, j ecris pour toi.\nAppuie encore pour arreter." -t 3000

# Lancer la dictee en arriere-plan
# Note : heredoc non quote => ${VOSK_MODEL} est expande par bash avant passage a Python
python3 -u << ENDPY &
import json
import subprocess
import sys
import os
import signal

from vosk import Model, KaldiRecognizer

model = Model("${VOSK_MODEL}")
rec = KaldiRecognizer(model, 16000)

proc = subprocess.Popen(
    ["arecord", "-f", "S16_LE", "-r", "16000", "-c", "1", "-t", "raw", "-q"],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL
)

def cleanup(sig, frame):
    proc.terminate()
    sys.exit(0)

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

while True:
    data = proc.stdout.read(4000)
    if len(data) == 0:
        break
    if rec.AcceptWaveform(data):
        result = json.loads(rec.Result())
        text = result.get("text", "").strip()
        if text:
            subprocess.run(["xdotool", "type", "--delay", "20", text + " "],
                           env={**os.environ, "DISPLAY": ":0"})
ENDPY

STT_PID=$!
echo "$STT_PID" > "$PIDFILE"

wait "$STT_PID" 2>/dev/null
rm -f "$PIDFILE"
