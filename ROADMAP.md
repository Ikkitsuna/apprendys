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

### TurboWarp (Scratch offline)
- Fork communautaire de Scratch 3, maintenu activement (builds 2025)
- AppImage Linux ~150MB, 100% compatible projets Scratch officiels
- Fonctionne offline complet, plus rapide que Scratch original (compilateur intégré)
- **Implémentation via patch** : AppImage sur P4 + `.desktop` dans patches
- https://desktop.turbowarp.org/

### GeoGebra hors-ligne
- ⚠️ GeoGebra a abandonné Linux : v6+ = Windows/Mac/web uniquement
- Seul option Linux = Classic 5 portable bundle (non maintenu, non supporté)
- À reconsidérer si GeoGebra sort une version Linux officielle
- Alternative : chercher un équivalent (KmPlot, Desmos offline cache...)

### Modèles IA upgradables P4
- STT : Whisper (`.bin`) via upgrade P4/models/stt — déjà prévu dans le code
- TTS : voix Piper alternative via P4/models/tts — déjà prévu dans le code
- Interface de sélection voix dans le futur app Apprendys

### Reset profil enfant
- Bouton dans future app Apprendys : `rm -rf P4/config/home/*`
- Repart sur le profil squashfs propre au prochain login

### Onboarding premier démarrage
- Wizard guidé au premier boot : WiFi → test connexion → volume micro → prénom enfant
- Évite que le parent se retrouve sur un bureau vide sans savoir quoi faire
- Écrit le prénom dans P4/config pour personnaliser l'interface

### Gestion imprimante
- CUPS + driver générique IPP/AirPrint baked dans squashfs
- Ce sera la question n°1 des parents après le WiFi
- Interface simple : "Ajouter une imprimante" dans le menu

### Backup Devoirs vers Windows
- Script déclenché au branchement de la clé sur Windows (depuis l'app Windows Forge)
- Copie P5/Devoirs vers un dossier Windows automatiquement
- P5 est déjà NTFS donc accessible directement — juste besoin d'un script .bat ou .ps1

### Multi-profil enfant
- Deux enfants dans la famille = deux dossiers sur P4, sélecteur au login
- Chaque profil a son home, ses Devoirs sur P5, ses réglages IA

### Contrôle parental léger
- Plage horaire configurable (ex : pas après 21h)
- Liste blanche de sites dans Chromium/Firefox (pour les très jeunes)
- Désactivation du micro/webcam par plage horaire

### Mode kiosque
- Full screen pour les moins de 8 ans : pas de bureau XFCE visible, juste les 3 icônes
- Sortie du mode kiosque par combinaison touches (parents uniquement)

---

## Ops / Business

### Telemetry opt-in anonyme
- Juste : version active, canal, date dernière MAJ, hash matériel anonymisé
- Permet de savoir combien de clés sont en prod et sur quelle version
- Strictement opt-in, rien de personnel, RGPD compliant

### Auto-diagnostic au boot
- Vérifie : espace P4 restant, intégrité symlinks, version patches, dernière MAJ
- Écrit un rapport lisible sur P5 (`.apprendys-health.txt`) visible depuis Windows
- En cas de boot raté : log d'erreur sur P5 que le parent envoie au support

### Diagnostic depuis l'app Windows
- Lire `.apprendys-health.txt` sur P5 sans booter la clé
- Affiche version, espace, dernière MAJ, erreurs éventuelles
- Bouton "Envoyer au support" qui ouvre un mail pré-rempli

### Portail revendeur
- Interface pour créer un canal `revendeur-X` avec branding (wallpaper, nom affiché)
- Revendeur gère ses propres clés sans accès au repo principal

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
