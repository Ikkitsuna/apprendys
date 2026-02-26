#!/bin/bash
# ==========================================================
# Apprendys - apply.sh
# Execute apres git pull par apprendys-update.sh
#
# Strategie : le repo git vit dans P4/.repo/ (hors gnuramage)
# apply.sh copie les changements vers RAMDISK
# gnuramage sync RAMDISK -> P4 toutes les 3min (persistance)
# Les patches sont appliques a / au prochain boot par mount-partitions.sh
# ==========================================================

LOG_TAG="apprendys-apply"
REPO="/mnt/apprendys/.repo"
RAMDISK="/dev/shm/apprendys"

log() { logger -t "$LOG_TAG" "$1"; echo "[apply] $1"; }

log "apply.sh debut (v$(cat "$REPO/VERSION" 2>/dev/null || echo '?'))"

# 1. Sync patches vers RAMDISK (autoritatif : --delete)
#    gnuramage persistera vers P4 au prochain cycle
if [ -d "$REPO/patches" ]; then
    mkdir -p "$RAMDISK/patches"
    rsync -a --delete "$REPO/patches/" "$RAMDISK/patches/" 2>/dev/null
    log "Patches synces vers RAMDISK"
fi

# 2. Sync config et icons (sans --delete : respecte les customisations locales)
for dir in config icons; do
    if [ -d "$REPO/$dir" ]; then
        mkdir -p "$RAMDISK/$dir"
        rsync -a "$REPO/$dir/" "$RAMDISK/$dir/" 2>/dev/null
    fi
done

# 3. Rendre les scripts executables
find "$RAMDISK/patches" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

# 4. Application immediate sur le systeme vivant (sans attendre reboot)
#    Scripts accessibilite
rsync -a --ignore-errors "$RAMDISK/patches/usr/local/bin/" /usr/local/bin/ 2>/dev/null
chmod +x /usr/local/bin/apprendys-*.sh 2>/dev/null

#    Scripts de boot (pris en compte au prochain boot via patches/)
#    Systemd : daemon-reload si les .service ont change
if [ -d "$RAMDISK/patches/etc/systemd/system" ]; then
    rsync -a --ignore-errors "$RAMDISK/patches/etc/systemd/system/" /etc/systemd/system/ 2>/dev/null
    systemctl daemon-reload 2>/dev/null
    log "systemd daemon-reload OK"
fi

log "apply.sh termine - patches actifs au prochain demarrage"
