#!/bin/bash
# ==========================================================
# Apprendys - Montage des partitions USB
# CF-Informatik974 - Fevrier 2026
# ==========================================================

set -u

LOG_TAG="apprendys-mount"

log() { logger -t "$LOG_TAG" "$1"; echo "[mount] $1"; }

# Creer les points de montage
mkdir -p /mnt/apprendys /mnt/devoirs

# --- P4 : ext4 APPRENDYS (config, scripts, polices) ---
if ! mountpoint -q /mnt/apprendys; then
    if mount -t ext4 -o noatime,commit=180 LABEL=APPRENDYS /mnt/apprendys 2>/dev/null; then
        log "P4 (APPRENDYS) monte sur /mnt/apprendys"
    else
        log "ERREUR: impossible de monter P4 (APPRENDYS)"
    fi
fi

# --- P5 : NTFS DEVOIRS (devoirs, visible Windows) ---
if ! mountpoint -q /mnt/devoirs; then
    if mount -t ntfs3 -o noatime,uid=1000,gid=1000,fmask=0022,dmask=0022 LABEL=DEVOIRS /mnt/devoirs 2>/dev/null; then
        log "P5 (DEVOIRS) monte sur /mnt/devoirs (RW)"
    elif mount -t ntfs3 -o ro,uid=1000,gid=1000 LABEL=DEVOIRS /mnt/devoirs 2>/dev/null; then
        log "P5 (DEVOIRS) monte en LECTURE SEULE (Windows Fast Startup ?)"
        DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
            sudo -u apprendys notify-send -i dialog-warning "Devoirs en lecture seule" \
            "Windows a verrouille la cle.\nRedemarrez Windows et choisissez Arreter (pas Veille)." -t 10000 2>/dev/null
    else
        # Fallback : casper a deja monte P5 sous /media/apprendys/DEVOIRS
        CASPER_DEVOIRS=$(findmnt -rn -o TARGET -S LABEL=DEVOIRS 2>/dev/null | head -1)
        if [ -n "$CASPER_DEVOIRS" ] && [ -d "$CASPER_DEVOIRS" ]; then
            rmdir /mnt/devoirs 2>/dev/null
            ln -sf "$CASPER_DEVOIRS" /mnt/devoirs
            log "P5 (DEVOIRS) : symlink /mnt/devoirs -> $CASPER_DEVOIRS (monte par casper)"
        else
            log "ERREUR: impossible de monter P5 (DEVOIRS) - casper pas encore pret"
        fi
    fi
fi

# Creer les sous-dossiers P5 necessaires
mkdir -p /mnt/devoirs/autosave /mnt/devoirs/Images /mnt/devoirs/Musique 2>/dev/null
chown -R 1000:1000 /mnt/devoirs/autosave /mnt/devoirs/Images /mnt/devoirs/Musique 2>/dev/null

# --- PERSISTANCE WiFi + Bluetooth via P4 ---
if mountpoint -q /mnt/apprendys; then
    mkdir -p /mnt/apprendys/nm-connections
    chmod 700 /mnt/apprendys/nm-connections
    # Copie P4/nm-connections -> RAMDISK AVANT que NM demarre
    mkdir -p /dev/shm/apprendys/nm-connections
    chmod 700 /dev/shm/apprendys/nm-connections
    cp -a /mnt/apprendys/nm-connections/. /dev/shm/apprendys/nm-connections/ 2>/dev/null || true
    # NM pointe sur RAMDISK (gnuramage sync RAMDISK->P4)
    rm -rf /etc/NetworkManager/system-connections
    ln -sf /dev/shm/apprendys/nm-connections /etc/NetworkManager/system-connections
    log "WiFi : profils NM pointes sur RAMDISK (sync gnuramage -> P4)"

    # Bluetooth : pairages persistants entre sessions
    mkdir -p /mnt/apprendys/bluetooth
    rm -rf /var/lib/bluetooth
    ln -sf /mnt/apprendys/bluetooth /var/lib/bluetooth
    log "Bluetooth : pairages pointes sur P4"

    # Persistance home : Firefox, Chromium, audio, XFCE config, WirePlumber
    # Symlink /home/apprendys/XXX -> P4/config/home/XXX
    HOME_PERSIST="/mnt/apprendys/config/home"
    HOME_USER="/home/apprendys"

    # Dirs simples (crees vides si absents sur P4)
    for dir in ".mozilla" ".config/chromium" ".config/pulse" ".config/libreoffice" ".local/state/wireplumber"; do
        mkdir -p "$HOME_PERSIST/$dir"
        chown -R 1000:1000 "$HOME_PERSIST/$dir"
        rm -rf "$HOME_USER/$dir"
        mkdir -p "$HOME_USER/$(dirname "$dir")"
        ln -sf "$HOME_PERSIST/$dir" "$HOME_USER/$dir"
        chown -h 1000:1000 "$HOME_USER/$dir"
    done

    # XFCE4 : seeder depuis squashfs si P4 vide
    XFCE_P4="$HOME_PERSIST/.config/xfce4"
    mkdir -p "$XFCE_P4"
    if [ -z "$(ls -A "$XFCE_P4" 2>/dev/null)" ]; then
        if [ -d "$HOME_USER/.config/xfce4" ]; then
            cp -a "$HOME_USER/.config/xfce4/." "$XFCE_P4/" 2>/dev/null
            log "XFCE4 : config initiale seedee depuis squashfs"
        fi
    fi

    # Fix xfce4-desktop.xml : image-path vide = fond grise
    # Si image-path est vide, le remplir avec last-image (chemin du fond actuel)
    XFCE_DESKTOP="$XFCE_P4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
    if [ -f "$XFCE_DESKTOP" ] && grep -q 'name="image-path" type="empty"' "$XFCE_DESKTOP" 2>/dev/null; then
        LAST_IMG=$(grep -o 'name="last-image"[^>]*value="[^"]*"' "$XFCE_DESKTOP" | head -1 | grep -o 'value="[^"]*"' | cut -d'"' -f2)
        if [ -n "$LAST_IMG" ]; then
            sed -i "s|name=\"image-path\" type=\"empty\"|name=\"image-path\" type=\"string\" value=\"$LAST_IMG\"|g" "$XFCE_DESKTOP"
            log "XFCE4 : fond d'ecran fixe -> $LAST_IMG"
        fi
    fi

    chown -R 1000:1000 "$XFCE_P4"
    rm -rf "$HOME_USER/.config/xfce4"
    ln -sf "$XFCE_P4" "$HOME_USER/.config/xfce4"
    chown -h 1000:1000 "$HOME_USER/.config/xfce4"

    log "Home persistance : Firefox, Chromium, audio, WirePlumber, XFCE -> P4/config/home"
fi

# --- SYSTEME DE PATCHES P4 ---
if [ -d /mnt/apprendys/patches ]; then
    rsync -a --ignore-errors /mnt/apprendys/patches/ / 2>/dev/null
    log "Patches P4 appliques"
fi

# --- MODELES IA ---
if [ -d /mnt/apprendys/models/stt ]; then
    export P4_MODELS_STT=/mnt/apprendys/models/stt
    log "STT : modele P4 detecte ($P4_MODELS_STT)"
fi
if [ -d /mnt/apprendys/models/tts ]; then
    export P4_MODELS_TTS=/mnt/apprendys/models/tts
    log "TTS : modele P4 detecte ($P4_MODELS_TTS)"
fi

# Fallback NM : si NM a demarre avant ce service, recharger les connexions
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    nmcli connection reload 2>/dev/null && log "WiFi : NM connexions rechargees (fallback)"
fi

# Flag : indique que ce script a deja tourne ce boot
# apprendys-boot.sh utilise ce flag pour eviter un double appel
touch /run/apprendys-mount-done

log "Montage termine"
