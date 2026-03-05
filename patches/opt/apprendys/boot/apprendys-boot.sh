#!/bin/bash
# ==========================================================
# Apprendys - Script de demarrage principal
# CF-Informatik974 - Fevrier 2026
# ==========================================================

set -u

LOG_TAG="apprendys-boot"
log() { logger -t "$LOG_TAG" "$1"; echo "[boot] $1"; }

log "========== Demarrage Apprendys =========="

# Fix ownership /home/apprendys : le rsync de patches (squashfs) ecrase en root:root.
# Ce script tourne depuis la version PATCHEE (apres rsync), donc le fix est effectif.
chown 1000:1000 /home/apprendys 2>/dev/null || true

# Etape 1 : Montage partitions
# Normalement fait par apprendys-mount.service (sysinit, avant lightdm).
# Fallback : si le service est desactive (cles pre-1.0.8), on le fait ici.
if [ ! -f /run/apprendys-mount-done ]; then
    log "Etape 1/5 : Montage partitions (fallback - apprendys-mount.service inactif)"
    /opt/apprendys/boot/mount-partitions.sh
else
    log "Etape 1/5 : Montage partitions deja fait par apprendys-mount.service"
fi

# Etape 1b : Montage P5 DEVOIRS (ntfs-3g, avant la session XFCE)
# udisks2 ne monte pas P5 auto au boot (cle deja presente = pas d'event udev "add")
# On monte ici en root avant que setup-devoirs-shortcut.sh (autostart XFCE) cherche la partition
mkdir -p /mnt/devoirs
if ! mountpoint -q /mnt/devoirs 2>/dev/null; then
    if mount -t ntfs-3g -o uid=1000,gid=1000,umask=0022,noatime LABEL=DEVOIRS /mnt/devoirs 2>/dev/null; then
        log "P5 DEVOIRS monte sur /mnt/devoirs"
    else
        log "P5 DEVOIRS non disponible (cle sans P5 ou ntfs-3g absent)"
    fi
fi

# Etape 1c : Rebind touchpad I2C (warm boot - BIOS ne reset pas le controleur I2C)
# ALPS, Elan : hid-generic recoit "unknown main item tag" apres warm boot -> touchpad mort
# Fait ici (version patchee, post-rsync patches) car mount-partitions.sh tourne depuis squashfs
for I2C_DEV in /sys/bus/i2c/devices/i2c-*; do
    if readlink "$I2C_DEV/driver" 2>/dev/null | grep -q 'i2c_hid'; then
        DEV=$(basename "$I2C_DEV")
        echo "$DEV" > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind 2>/dev/null || true
        sleep 0.3
        echo "$DEV" > /sys/bus/i2c/drivers/i2c_hid_acpi/bind 2>/dev/null || true
        log "Touchpad I2C rebind : $DEV"
    fi
done

systemd-notify READY=1 2>/dev/null || true

# Etape 2 : Nettoyage
log "Etape 2/5 : Nettoyage"
/opt/apprendys/boot/cleanup.sh

# Etape 3 : GnuRAMage (en arriere-plan, tourne en continu)
log "Etape 3/5 : GnuRAMage"
if mountpoint -q /mnt/apprendys; then
    /opt/apprendys/boot/gnuramage.sh &
    GNURAMAGE_PID=$!
    log "GnuRAMage lance (PID $GNURAMAGE_PID)"
else
    log "P4 non monte, GnuRAMage skip"
fi

# Etape 4 : Deployer le guard apt (bloque apt sur le live)
log "Etape 4/5 : Protection systeme"
if [ -f /opt/apprendys/boot/apt-guard.sh ]; then
    cp /opt/apprendys/boot/apt-guard.sh /usr/local/bin/apt 2>/dev/null
    chmod +x /usr/local/bin/apt 2>/dev/null
    log "apt guard deploye"
fi

# Etape 5 : Mise a jour (en arriere-plan, non bloquant)
log "Etape 5/5 : Verification MAJ"
/opt/apprendys/update/apprendys-update.sh &

# Watcher DEVOIRS : udisks2 monte P5 apres le boot (timing variable)
# Cree ~/Devoirs et fixe /mnt/devoirs des que la partition est disponible
(
    for i in $(seq 1 90); do
        DEVOIRS=$(findmnt -rn -o TARGET -S LABEL=DEVOIRS 2>/dev/null | head -1)
        if [ -n "$DEVOIRS" ] && [ -d "$DEVOIRS" ]; then
            # Si ~/Devoirs est un repertoire reel (cree par xdg avant que P5 soit dispo),
            # migrer le contenu vers P5 puis remplacer par symlink
            if [ -d /home/apprendys/Devoirs ] && [ ! -L /home/apprendys/Devoirs ]; then
                cp -a /home/apprendys/Devoirs/. "$DEVOIRS"/ 2>/dev/null || true
                rm -rf /home/apprendys/Devoirs
            else
                rm -f /home/apprendys/Devoirs
            fi
            ln -sf "$DEVOIRS" /home/apprendys/Devoirs
            chown -h 1000:1000 /home/apprendys/Devoirs
            mkdir -p "$DEVOIRS/Images" "$DEVOIRS/Musique" "$DEVOIRS/Videos" "$DEVOIRS/autosave" 2>/dev/null
            if ! mountpoint -q /mnt/devoirs && [ ! -L /mnt/devoirs ]; then
                rm -rf /mnt/devoirs
                ln -sf "$DEVOIRS" /mnt/devoirs
            fi
            logger -t apprendys-boot "DEVOIRS watcher: ~/Devoirs -> $DEVOIRS (iter=$i)"
            break
        fi
        sleep 2
    done
) &

log "========== Apprendys pret =========="

# Attendre GnuRAMage (ne termine jamais sauf a l arret)
if [ -n "${GNURAMAGE_PID:-}" ]; then
    wait "$GNURAMAGE_PID"
fi
