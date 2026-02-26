#!/bin/bash
# ==========================================================
# Apprendys - init-repo.sh
# Initialise le repo GitHub sur P4 (une seule fois au deploiement)
#
# A lancer apres le premier boot si internet disponible,
# ou depuis l'host pendant le build de la cle.
#
# Usage : sudo bash /opt/apprendys/update/init-repo.sh
# ==========================================================

GITHUB_REPO="https://github.com/Ikkitsuna/apprendys"
P4="/mnt/apprendys"
REPO_DIR="$P4/.repo"

log() { echo "[init-repo] $1"; logger -t "apprendys-init-repo" "$1"; }

# Verifier que P4 est monte
if ! mountpoint -q "$P4" 2>/dev/null; then
    log "ERREUR: P4 non monte sur $P4"
    exit 1
fi

# Deja initialise ?
if [ -d "$REPO_DIR/.git" ]; then
    log "Repo deja initialise dans $REPO_DIR"
    log "Pour forcer : rm -rf $REPO_DIR && bash $0"
    exit 0
fi

# Verifier internet
if ! curl -fsSL --max-time 10 https://raw.githubusercontent.com/Ikkitsuna/apprendys/main/VERSION > /dev/null 2>&1; then
    log "ERREUR: GitHub inaccessible (pas internet ou portail captif)"
    exit 1
fi

log "Clonage de $GITHUB_REPO dans $REPO_DIR ..."
git clone --depth=1 "$GITHUB_REPO" "$REPO_DIR" 2>&1 | while read -r line; do log "$line"; done

if [ -d "$REPO_DIR/.git" ]; then
    log "Repo initialise avec succes (v$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo '?'))"
    log "Le systeme de MAJ silencieuse est actif au prochain demarrage."
else
    log "ERREUR: git clone a echoue"
    exit 1
fi
