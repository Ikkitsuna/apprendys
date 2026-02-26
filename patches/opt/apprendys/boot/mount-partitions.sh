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
        log "ERREUR: impossible de monter P5 (DEVOIRS)"
    fi
fi

# Creer les sous-dossiers P5 necessaires
mkdir -p /mnt/devoirs/autosave /mnt/devoirs/Images /mnt/devoirs/Vidéos /mnt/devoirs/Musique 2>/dev/null
chown -R 1000:1000 /mnt/devoirs/autosave /mnt/devoirs/Images /mnt/devoirs/Vidéos /mnt/devoirs/Musique 2>/dev/null

# --- PERSISTANCE WiFi + Bluetooth via P4 ---
# NetworkManager : profils WiFi persistants entre sessions
# Architecture : NM -> RAMDISK (/dev/shm/apprendys/nm-connections)
# gnuramage sync RAMDISK->P4 toutes les 3min => WiFi sauve sur P4
# Sans ca, gnuramage ecrase P4 avec l'ancien RAMDISK => WiFi perdu
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
fi

# --- SYSTEME DE PATCHES P4 ---
# Permet de patcher l'OS sans rebuild squashfs
# Deposer des fichiers dans P4/patches/ => appliques au prochain boot
if [ -d /mnt/apprendys/patches ]; then
    rsync -a --ignore-errors /mnt/apprendys/patches/ / 2>/dev/null
    log "Patches P4 appliques"
fi

# --- MODELES IA : P4 prime sur squashfs ---
# Si P4 contient des modeles IA plus recents, les scripts TTS/STT les utilisent
if [ -d /mnt/apprendys/models/stt ]; then
    export P4_MODELS_STT=/mnt/apprendys/models/stt
    log "STT : modele P4 detecte ($P4_MODELS_STT)"
fi
if [ -d /mnt/apprendys/models/tts ]; then
    export P4_MODELS_TTS=/mnt/apprendys/models/tts
    log "TTS : modele P4 detecte ($P4_MODELS_TTS)"
fi

# Fallback : si NM a demarre avant ce service, recharger les connexions
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    nmcli connection reload 2>/dev/null && log "WiFi : NM connexions rechargees (fallback)"
fi

log "Montage termine"
