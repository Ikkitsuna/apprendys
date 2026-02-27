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

# Canal de mise a jour (par defaut : main)
# Modifier /mnt/apprendys/.channel pour cibler une branche specifique
# Exemples : main, ecole-X, premium, beta
CHANNEL=$(cat /mnt/apprendys/.channel 2>/dev/null | tr -d '[:space:]')
CHANNEL=${CHANNEL:-main}
log "Canal : $CHANNEL"

# Verifier internet reel via VERSION de main (reference commune pour tous les canaux)
# Quand tu veux declencher une MAJ (main OU canal), tu bumpes toujours main/VERSION
if ! curl -fsSL --max-time 5 \
    "https://raw.githubusercontent.com/Ikkitsuna/apprendys/main/VERSION" \
    > /tmp/remote-version 2>/dev/null; then
    log "Pas d internet ou GitHub injoignable, skip update"
    exit 0
fi

# Comparer les versions (reference : main)
LOCAL_VERSION=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "0.0.0")
REMOTE_VERSION=$(cat /tmp/remote-version 2>/dev/null || echo "0.0.0")
rm -f /tmp/remote-version

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    log "Deja a jour (v$LOCAL_VERSION, canal=$CHANNEL)"
    exit 0
fi

log "Mise a jour disponible : v$LOCAL_VERSION -> v$REMOTE_VERSION (canal=$CHANNEL)"

# Anti-double execution
if [ -f "$LOCKFILE" ]; then
    log "Update deja en cours, skip"
    exit 0
fi
touch "$LOCKFILE"

cd "$REPO_DIR" || { rm -f "$LOCKFILE"; exit 1; }

# Systeme a deux couches :
# - Couche 1 (main)  : patches communs a TOUS les canaux (rsync --delete)
# - Couche 2 (canal) : patches specifiques a cette ecole/groupe (rsync sans --delete)
# Si canal == main : une seule couche, comportement normal.

# Couche 1 : toujours appliquer main en premier
# reset --hard garantit que le working tree correspond exactement a origin/main
# (git pull --ff-only ne corrige pas un working tree sale)
if git fetch origin main 2>/dev/null && \
   git checkout main 2>/dev/null && \
   git reset --hard origin/main 2>/dev/null; then
    log "Pull main OK (base commune v$REMOTE_VERSION)"
    if [ -x "$REPO_DIR/apply.sh" ]; then
        bash "$REPO_DIR/apply.sh" 2>/dev/null
    fi
else
    log "ERREUR: git fetch/reset main a echoue"
    rm -f "$LOCKFILE"; exit 1
fi

# Couche 2 : si canal specifique, appliquer par-dessus (overlay, sans effacer main)
if [ "$CHANNEL" != "main" ]; then
    if git fetch origin "$CHANNEL" 2>/dev/null && \
       git checkout "$CHANNEL" 2>/dev/null && \
       git reset --hard origin/"$CHANNEL" 2>/dev/null; then
        log "Pull $CHANNEL OK (overlay specifique)"
        if [ -x "$REPO_DIR/apply.sh" ]; then
            bash "$REPO_DIR/apply.sh" --overlay 2>/dev/null
        fi
        log "apply.sh execute (2 couches : main + $CHANNEL)"
    else
        log "Canal '$CHANNEL' introuvable ou pull echoue - patches main appliques uniquement"
    fi
fi

DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    sudo -u apprendys notify-send -i dialog-information "Apprendys mis a jour" \
    "Version $REMOTE_VERSION installee." -t 5000 2>/dev/null

rm -f "$LOCKFILE"
