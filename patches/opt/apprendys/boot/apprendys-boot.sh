#!/bin/bash
# ==========================================================
# Apprendys - Script de demarrage principal
# CF-Informatik974 - Fevrier 2026
# ==========================================================

set -u

LOG_TAG="apprendys-boot"
log() { logger -t "$LOG_TAG" "$1"; echo "[boot] $1"; }

log "========== Demarrage Apprendys =========="

# Etape 1 : Montage partitions
# Normalement fait par apprendys-mount.service (sysinit, avant lightdm).
# Fallback : si le service est desactive (cles pre-1.0.8), on le fait ici.
if [ ! -f /run/apprendys-mount-done ]; then
    log "Etape 1/5 : Montage partitions (fallback - apprendys-mount.service inactif)"
    /opt/apprendys/boot/mount-partitions.sh
else
    log "Etape 1/5 : Montage partitions deja fait par apprendys-mount.service"
fi

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
            rm -f /home/apprendys/Devoirs
            ln -sf "$DEVOIRS" /home/apprendys/Devoirs
            chown -h 1000:1000 /home/apprendys/Devoirs
            mkdir -p /home/apprendys/Devoirs/autosave \
                     /home/apprendys/Devoirs/Images \
                     /home/apprendys/Devoirs/Musique 2>/dev/null
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
