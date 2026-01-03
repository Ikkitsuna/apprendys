#!/usr/bin/env bash
VERSION=$(cat "$HOME/apprendys/VERSION" 2>/dev/null || echo "dev")


CHOICE=$(zenity --list \
  --width=520 --height=360 \
  --title="Apprendys — Outils (v$VERSION)" \
  --text="Choisis une action :" \
  --column="Action" \
  "Mode lecture (OpenDyslexic) ON/OFF" \
  "Accessibilité (gros texte + curseur) ON/OFF" \
  "Mode concentration (son) ON/OFF" \
  "Ouvrir le cahier (Xournal++)" \
  "Ouvrir LibreOffice Writer" \
  "Mettre à jour Apprendys" \
  "Quitter")

case "$CHOICE" in
  "Mode lecture (OpenDyslexic) ON/OFF")
    bash "$HOME/apprendys/scripts/toggle-dyslexic-font.sh"
    ;;
  "Accessibilité (gros texte + curseur) ON/OFF")
    bash "$HOME/apprendys/scripts/toggle-accessibility.sh"
    ;;
  "Mode concentration (son) ON/OFF")
    bash "$HOME/apprendys/scripts/toggle-focus.sh"
    ;;
  "Ouvrir le cahier (Xournal++)")
    xournalpp >/dev/null 2>&1 &
    ;;
  "Ouvrir LibreOffice Writer")
    libreoffice --writer >/dev/null 2>&1 &
    ;;
  "Mettre à jour Apprendys")
  bash "$HOME/apprendys/update.sh"
  ;;
  *)
    exit 0
    ;;
esac
