#!/bin/bash
# Apprendys - Raccourci ~/Devoirs vers P5 (DEVOIRS)
# Lance en autostart XFCE, apres casper/udisks2 ont monte la partition
# CF-Informatik974 - 2026

MAX_WAIT=60
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    DEVOIRS=$(findmnt -rn -o TARGET -S LABEL=DEVOIRS 2>/dev/null | head -1)
    if [ -n "$DEVOIRS" ] && [ -d "$DEVOIRS" ]; then
        # Creer le raccourci ~/Devoirs
        rm -f "$HOME/Devoirs"
        ln -sf "$DEVOIRS" "$HOME/Devoirs"
        # Creer les sous-dossiers standards
        mkdir -p "$HOME/Devoirs/autosave" "$HOME/Devoirs/Images" "$HOME/Devoirs/Musique" 2>/dev/null
        logger -t apprendys-devoirs "Raccourci ~/Devoirs -> $DEVOIRS OK"
        exit 0
    fi
    sleep 1
    WAITED=$((WAITED + 1))
done

logger -t apprendys-devoirs "TIMEOUT: DEVOIRS jamais monte apres ${MAX_WAIT}s"
