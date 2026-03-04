# Apprendys - Roadmap

Idées et fonctionnalités prévues, par priorité.
Ce fichier est une liste vivante — pas un engagement de date.

---

## En cours / Prochain sprint

- **V15 squashfs** — prochaine build VM
  - Vérifier `python3 -c 'import requests, vosk'` avant mksquashfs
  - `sudo /usr/bin/apt clean` avant build
  - Boot test Blackview obligatoire avant validation

---

## Priorité haute

### Gestion proxy réseau
- Fichier `DEVOIRS\.apprendys-proxy` déposé depuis Windows par l'IT
  - Format : `proxy=http://host:port` + `no_proxy=...`
  - Lu au boot (`apprendys-boot.sh`), appliqué system-wide (`/etc/environment`)
  - Session-init : gsettings XFCE + user.js Firefox + prefs Chromium
  - Fallback : pas de fichier = pas de proxy
- Shortcut menu XFCE "Configurer le proxy" (zenity dialog → écrit sur P5)
- Ciblé collèges/lycées sous Windows — zéro Linux côté IT

---

## Priorité moyenne

### App Windows de mise à jour clés (Apprendys Forge Windows)
- Télécharge le squashfs V15+ depuis un serveur de MAJ (CDN ou S3)
- Flashe P3 directement depuis Windows (dd équivalent, WinDD ou Rufus-like)
- Fallback sans connexion serveur : applique uniquement les patches git (léger)
- Mode bulk : MAJ plusieurs clés en parallèle (détection automatique USB)
- Signature/hash du squashfs avant flash (intégrité)
- Interface simple : une fenêtre, un bouton "Mettre à jour"
- Ciblé : revendeurs, écoles avec parc de clés, forge maison

### Serveur de MAJ centralisé
- Héberge les squashfs versionnés + patches
- API simple : `GET /latest?canal=main` → version + URL download
- Permet de forcer une MAJ sur toutes les clés d'un canal
- Dashboard basique : nb clés actives par canal (via ping anonyme au boot)

---

## Priorité basse / Idées

### App Apprendys (UI native)
- Interface principale pour l'enfant (remplace les 3 icônes bureau)
- Accès Devoirs, Leçons, Recherche depuis un seul endroit
- Potentiellement : gestion du profil enfant, stats d'utilisation pour parents
- Version 1.1.0 dans le versioning sémantique

### Canaux école automatisés
- Script `create-canal.sh` : crée un canal git + branch avec proxy + config école
- Déploiement clés école = flash + `canal=ecole-X` → proxy + settings pré-configurés

### GeoGebra hors-ligne
- PWA Chromium en mode offline (cache service worker)
- Pas de bake squashfs nécessaire

### Modèles IA upgradables P4
- STT : Whisper (`.bin`) via upgrade P4/models/stt — déjà prévu dans le code
- TTS : voix Piper alternative via P4/models/tts — déjà prévu dans le code
- Interface de sélection voix dans le futur app Apprendys

### Reset profil enfant
- Bouton dans future app Apprendys : `rm -rf P4/config/home/*`
- Repart sur le profil squashfs propre au prochain login

---

## Architecture — rappels clés

| Couche | Rôle |
|--------|------|
| P3 (squashfs) | OS de base, rebuilt pour les grosses MAJ (V15+) |
| P4 (ext4) | Persistance, patches légers, modèles IA, config |
| P5 (NTFS) | Devoirs, visible Windows, proxy config IT |
| GitHub `main` | Patches globaux toutes clés |
| GitHub `ecole-X` | Overlay patches spécifiques école |
| RAMDISK | nm-connections, bluetooth, patches en mémoire |
