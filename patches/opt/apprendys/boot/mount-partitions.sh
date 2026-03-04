#!/bin/bash
# ==========================================================
# Apprendys - Montage des partitions USB
# CF-Informatik974 - Mars 2026
# ==========================================================

set -u

LOG_TAG="apprendys-mount"
log() { logger -t "$LOG_TAG" "$1"; echo "[mount] $1"; }

# --- P4 : ext4 APPRENDYS ---
mkdir -p /mnt/apprendys
if ! mountpoint -q /mnt/apprendys; then
    if mount -t ext4 -o noatime,commit=180 LABEL=APPRENDYS /mnt/apprendys 2>/dev/null; then
        log "P4 monte sur /mnt/apprendys"
    else
        log "ERREUR: P4 (APPRENDYS) non monte - cle USB absente ?"
        touch /run/apprendys-mount-done
        exit 1
    fi
fi

# --- WiFi : profils NM en RAMDISK (reduit les ecritures NAND) ---
# gnuramage sync RAMDISK->P4 toutes les 3min
mkdir -p /mnt/apprendys/nm-connections
chmod 700 /mnt/apprendys/nm-connections
mkdir -p /dev/shm/apprendys/nm-connections
chmod 700 /dev/shm/apprendys/nm-connections
cp -a /mnt/apprendys/nm-connections/. /dev/shm/apprendys/nm-connections/ 2>/dev/null || true
rm -rf /etc/NetworkManager/system-connections
ln -sf /dev/shm/apprendys/nm-connections /etc/NetworkManager/system-connections
log "WiFi : NM pointe sur RAMDISK"

# --- Bluetooth : pairages persistants sur P4 ---
mkdir -p /mnt/apprendys/bluetooth
rm -rf /var/lib/bluetooth
ln -sf /mnt/apprendys/bluetooth /var/lib/bluetooth
log "Bluetooth pointe sur P4"

# --- HOME sur P4 (bind mount) ---
# /home/apprendys -> P4/home/apprendys (ext4, POSIX complet)
# Remplace l'approche symlinks qui avait des problemes de timing
mkdir -p /mnt/apprendys/home/apprendys

if [ -z "$(ls -A /mnt/apprendys/home/apprendys 2>/dev/null)" ]; then
    # Premier boot : seeder home depuis squashfs
    cp -a /home/apprendys/. /mnt/apprendys/home/apprendys/ 2>/dev/null
    chown -R 1000:1000 /mnt/apprendys/home/apprendys
    log "Home : seede depuis squashfs (premier boot)"

    # Fix xfce4-desktop.xml : image-path vide -> wallpaper grise
    XFCE_DESKTOP="/mnt/apprendys/home/apprendys/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
    if [ -f "$XFCE_DESKTOP" ] && grep -q 'name="image-path" type="empty"' "$XFCE_DESKTOP" 2>/dev/null; then
        LAST_IMG=$(grep -o 'name="last-image"[^>]*value="[^"]*"' "$XFCE_DESKTOP" | head -1 | grep -o 'value="[^"]*"' | cut -d'"' -f2)
        if [ -n "$LAST_IMG" ]; then
            sed -i "s|name=\"image-path\" type=\"empty\"|name=\"image-path\" type=\"string\" value=\"$LAST_IMG\"|g" "$XFCE_DESKTOP"
            log "XFCE4 : fond d'ecran fixe -> $LAST_IMG"
        fi
    fi
fi

# Bind mount P4/home/apprendys -> /home/apprendys
mount --bind /mnt/apprendys/home/apprendys /home/apprendys
log "Home : /home/apprendys bind-monte depuis P4"

# --- SYSTEME DE PATCHES P4 ---
if [ -d /mnt/apprendys/patches ]; then
    rsync -a --ignore-errors /mnt/apprendys/patches/ / 2>/dev/null
    # Le rsync peut ecraser l'ownership de /home/apprendys avec root:root
    # (patches/home/apprendys/ est root:root sur P4 apres git clone)
    chown 1000:1000 /home/apprendys
    log "Patches P4 appliques"
fi

# --- MODELES IA ---
if [ -d /mnt/apprendys/models/stt ]; then
    export P4_MODELS_STT=/mnt/apprendys/models/stt
    log "STT : modele P4 detecte"
fi
if [ -d /mnt/apprendys/models/tts ]; then
    export P4_MODELS_TTS=/mnt/apprendys/models/tts
    log "TTS : modele P4 detecte"
fi

# Fallback NM : si NM a demarre avant ce service
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    nmcli connection reload 2>/dev/null && log "WiFi : NM connexions rechargees (fallback)"
fi

# --- Fix touchpad I2C (rebind apres warm boot) ---
# Certains touchpads I2C (ALPS, Elan) ne s'initialisent pas correctement apres warm boot.
# Un unbind/bind force le controleur a re-enumerer le peripherique.
for I2C_DEV in /sys/bus/i2c/devices/i2c-*; do
    DEV=$(basename "$I2C_DEV")
    DRIVER=$(cat "$I2C_DEV/driver/module/drivers/"*/name 2>/dev/null | head -1)
    # Appliquer sur tous les touchpads I2C HID (driver i2c_hid_acpi)
    if readlink "$I2C_DEV/driver" 2>/dev/null | grep -q 'i2c_hid'; then
        echo "$DEV" > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind 2>/dev/null || true
        sleep 0.3
        echo "$DEV" > /sys/bus/i2c/drivers/i2c_hid_acpi/bind 2>/dev/null || true
        log "Touchpad I2C rebind : $DEV"
    fi
done

# Flag : evite double appel depuis apprendys-boot.sh (cles pre-1.0.8)
touch /run/apprendys-mount-done

log "Montage termine"
