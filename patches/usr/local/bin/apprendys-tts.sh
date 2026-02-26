#!/bin/bash
# Apprendys - Lire a Voix Haute (Piper TTS)
# Ctrl+Espace : lit le texte selectionne avec une voix IA francaise

PIPER="/opt/piper/piper"
TMPWAV="/tmp/apprendys-tts-$$.wav"

# Detection voix TTS : P4 upgrade prioritaire, fallback squashfs
P4_TTS="/mnt/apprendys/models/tts"
PIPER_DEFAULT="/opt/piper/voices/fr-siwis-medium.onnx"

if [ -d "$P4_TTS" ] && ls "$P4_TTS"/*.onnx >/dev/null 2>&1; then
    # Prend la premiere voix .onnx disponible dans P4
    MODEL=$(ls "$P4_TTS"/*.onnx | head -1)
else
    MODEL="$PIPER_DEFAULT"
fi

# Recuperer le texte selectionne
TEXT=$(xsel -o 2>/dev/null || xclip -selection primary -o 2>/dev/null)

if [ -z "$TEXT" ]; then
    TEXT="Selectionne du texte, puis appuie sur le raccourci pour que je te le lise."
fi

# Tuer une lecture precedente en cours
pkill -f "paplay.*apprendys-tts" 2>/dev/null
pkill -f "espeak-ng.*-v fr" 2>/dev/null

# Piper (voix IA) avec fallback espeak-ng
if [ -x "$PIPER" ] && [ -f "$MODEL" ]; then
    echo "$TEXT" | "$PIPER" --model "$MODEL" --output_file "$TMPWAV" 2>/dev/null
    paplay "$TMPWAV" 2>/dev/null &
    (sleep 30 && rm -f "$TMPWAV") &
else
    espeak-ng -v fr -s 140 -p 50 "$TEXT" &
fi
