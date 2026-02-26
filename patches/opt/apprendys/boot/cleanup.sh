#!/bin/bash
# Hostname unique par machine
IFACE=$(ip route show default 2>/dev/null | awk "/default/ {print $5}" | head -1)
if [ -n "$IFACE" ]; then
    SUFFIX=$(cat /sys/class/net/$IFACE/address 2>/dev/null | tr -d ":" | tail -c 6)
    NEW_HOST="apprendys-${SUFFIX}"
    hostnamectl set-hostname "$NEW_HOST" 2>/dev/null || echo "$NEW_HOST" > /etc/hostname
    logger -t apprendys-boot "Hostname: $NEW_HOST"
fi

# ==========================================================
# Apprendys - Nettoyage au demarrage
# CF-Informatik974 - Fevrier 2026
# ==========================================================

LOG_TAG="apprendys-cleanup"
log() { logger -t "$LOG_TAG" "$1"; echo "[cleanup] $1"; }

USER_HOME="/home/apprendys"

# Firefox : supprimer les locks (crash precedent / arrachage clef)
find "$USER_HOME/.mozilla" -name ".parentlock" -delete 2>/dev/null
find "$USER_HOME/.mozilla" -name "lock" -delete 2>/dev/null
find "$USER_HOME/.mozilla" -name ".lock" -delete 2>/dev/null
log "Firefox locks nettoyes"

# LibreOffice : supprimer les locks
find "$USER_HOME" -name ".~lock.*" -delete 2>/dev/null
log "LibreOffice locks nettoyes"

# Xournal++ : supprimer les fichiers recovery corrompus
find /tmp -name "xournalpp-*" -mmin +60 -delete 2>/dev/null

# Supprimer les fichiers temporaires ages
find /tmp -maxdepth 1 -name "apprendys-*" -mmin +60 -delete 2>/dev/null

# Verifier l annee systeme (pile CMOS morte)
YEAR=$(date +%Y)
if [ "$YEAR" -lt 2025 ]; then
    log "ATTENTION: annee systeme $YEAR, pile CMOS morte probable"
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        sudo -u apprendys notify-send -i dialog-warning "Horloge incorrecte" \
        "L annee affichee est $YEAR. La date sera corrigee automatiquement si internet est disponible." -t 10000 2>/dev/null
fi

log "Nettoyage termine"
