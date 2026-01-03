#!/usr/bin/env bash
set -e

NORMAL_FONT="Noto Sans 10"
FALLBACK_FONT="DejaVu Sans 10"
DYS_FONT="OpenDyslexic 10"

current=$(xfconf-query -c xsettings -p /Gtk/FontName 2>/dev/null || echo "")

if echo "$current" | grep -qi "OpenDyslexic"; then
  xfconf-query -c xsettings -p /Gtk/FontName -s "$NORMAL_FONT" 2>/dev/null || \
  xfconf-query -c xsettings -p /Gtk/FontName -s "$FALLBACK_FONT"
  notify-send "Apprendys" "OpenDyslexic désactivée (police normale)."
else
  xfconf-query -c xsettings -p /Gtk/FontName -s "$DYS_FONT"
  notify-send "Apprendys" "OpenDyslexic activée (interface)."
fi
