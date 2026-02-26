# Apprendys

Clé USB live scolaire pour enfants DYS — CF-Informatik974, La Réunion.

Ce dépôt est la **source de vérité** pour les mises à jour silencieuses des clés déployées.
Au démarrage de chaque clé Apprendys, `apprendys-update.sh` fait un `git pull` ici si internet est disponible.

## Structure

```
patches/          ← appliqué vers / au boot (rsync patches/ → /)
  usr/local/bin/  ← scripts TTS, STT, session-init
  opt/apprendys/  ← scripts de boot, mise à jour
  etc/systemd/    ← services systemd
config/           ← configs XFCE, lanceurs (appliqués par apply.sh)
icons/            ← icônes custom (appliquées par apply.sh)
VERSION           ← version courante (lue par apprendys-update.sh)
apply.sh          ← exécuté après git pull
```

## Versioning

`VERSION` contient la version courante (`MAJEUR.MINEUR.PATCH`).
`apprendys-update.sh` compare la version distante avec la locale avant de déclencher la mise à jour.

---
CF-Informatik974 — Février 2026
