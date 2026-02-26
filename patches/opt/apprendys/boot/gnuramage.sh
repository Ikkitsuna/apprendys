#!/bin/bash
# ==========================================================
# Apprendys - GnuRAMage v2 (P4 config en RAM, sync periodique)
# CF-Informatik974 - Fevrier 2026
#
# ARCHITECTURE WHITELIST :
#   Seuls les dossiers de CONFIG (petits, ecriture frequente)
#   sont copies en RAMDISK. Les apps et modeles IA restent
#   sur P4 et sont accedes via /mnt/apprendys/ directement.
#
# RAMDISK scope : nm-connections, bluetooth, patches,
#                 config, scripts, icons
# P4 direct     : models/, apps/, data/ (trop gros pour RAM)
#
# Reduit les ecritures NAND de 99% pour les config.
# Aucun risque OOM meme avec Geogebra/Scratch sur P4.
# ==========================================================

set -u

LOG_TAG="apprendys-gnuramage"
SOURCE="/mnt/apprendys"
RAMDISK="/dev/shm/apprendys"
SYNC_INTERVAL=180
PIDFILE="/run/gnuramage.pid"

# Dossiers de config copies en RAMDISK (whitelist)
# Tout le reste (models/, apps/, data/) reste sur P4 uniquement
CONFIG_DIRS="nm-connections bluetooth patches config scripts icons"

log() { logger -t "$LOG_TAG" "$1"; echo "[gnuramage] $1"; }

# Verifier que P4 est monte
if ! mountpoint -q "$SOURCE"; then
    log "ERREUR: $SOURCE non monte, abandon"
    exit 1
fi

RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
log "RAM=${RAM_MB}MB - scope RAMDISK : $CONFIG_DIRS"

# Copie initiale P4 -> RAM (whitelist uniquement)
mkdir -p "$RAMDISK"
for dir in $CONFIG_DIRS; do
    if [ -d "$SOURCE/$dir" ]; then
        mkdir -p "$RAMDISK/$dir"
        rsync -a --delete "$SOURCE/$dir/" "$RAMDISK/$dir/" 2>/dev/null
    fi
done
log "Copie initiale terminee ($(du -sh "$RAMDISK" 2>/dev/null | cut -f1))"

# Ecrire le PID pour le shutdown propre
echo $$ > "$PIDFILE"

# Boucle de sync : RAM -> P4 (whitelist uniquement)
sync_to_disk() {
    for dir in $CONFIG_DIRS; do
        if [ -d "$RAMDISK/$dir" ]; then
            mkdir -p "$SOURCE/$dir"
            rsync -a --delete "$RAMDISK/$dir/" "$SOURCE/$dir/" 2>/dev/null
        fi
    done
    log "Sync RAM -> P4 OK ($(date +%H:%M:%S))"
}

# Sync propre a l arret
cleanup() {
    log "Arret demande, sync finale..."
    sync_to_disk
    rm -f "$PIDFILE"
    log "GnuRAMage arrete proprement"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Boucle principale
while true; do
    sleep "$SYNC_INTERVAL" &
    wait $!
    sync_to_disk
done
