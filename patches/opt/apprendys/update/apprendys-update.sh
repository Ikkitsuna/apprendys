#\!/bin/bash
# ==========================================================
# Apprendys - Mise a jour silencieuse depuis GitHub
# CF-Informatik974 - Fevrier 2026
# ==========================================================

set -u

LOG_TAG="apprendys-update"
# Le repo git vit dans .repo/ sur P4 (hors whitelist gnuramage = jamais ecrase)
REPO_DIR="/mnt/apprendys/.repo"
LOCKFILE="/run/apprendys-update.lock"

log() { logger -t "$LOG_TAG" "$1"; echo "[update] $1"; }

# Verifier l annee (pile CMOS morte = certificats SSL invalides)
YEAR=$(date +%Y)
if [ "$YEAR" -lt 2025 ]; then
    log "Annee $YEAR invalide, skip update"
    exit 0
fi

# Verifier que P4 est monte et que le repo est initialise
if ! mountpoint -q "/mnt/apprendys" 2>/dev/null; then
    log "P4 non monte, skip update"
    exit 0
fi
if [ ! -d "$REPO_DIR/.git" ]; then
    log "Repo non initialise (manque .repo/.git), skip update"
    log "Lancer /opt/apprendys/update/init-repo.sh pour initialiser"
    exit 0
fi

# Verifier internet reel (pas un portail captif)
if \! curl -fsSL --max-time 5 https://raw.githubusercontent.com/Ikkitsuna/apprendys/main/VERSION > /tmp/remote-version 2>/dev/null; then
    log "Pas d internet ou GitHub injoignable, skip update"
    exit 0
fi

# Comparer les versions
LOCAL_VERSION=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "0.0.0")
REMOTE_VERSION=$(cat /tmp/remote-version 2>/dev/null || echo "0.0.0")
rm -f /tmp/remote-version

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    log "Deja a jour (v$LOCAL_VERSION)"
    exit 0
fi

log "Mise a jour disponible : v$LOCAL_VERSION -> v$REMOTE_VERSION"

# Anti-double execution
if [ -f "$LOCKFILE" ]; then
    log "Update deja en cours, skip"
    exit 0
fi
touch "$LOCKFILE"

# Pull
cd "$REPO_DIR" || { rm -f "$LOCKFILE"; exit 1; }
if git pull origin main --ff-only 2>/dev/null; then
    log "Pull OK"
    # Appliquer les changements
    if [ -x "$REPO_DIR/apply.sh" ]; then
        bash "$REPO_DIR/apply.sh" 2>/dev/null
        log "apply.sh execute"
    fi
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        sudo -u apprendys notify-send -i dialog-information "Apprendys mis a jour" \
        "Version $REMOTE_VERSION installee." -t 5000 2>/dev/null
else
    log "ERREUR: git pull a echoue"
fi

rm -f "$LOCKFILE"
