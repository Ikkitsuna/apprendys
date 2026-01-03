#!/usr/bin/env bash
set -e

FONT=$(xfconf-query -c xsettings -p /Gtk/FontName)

if echo "$FONT" | grep -q "12"; then
  xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 10"
  xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 24
  notify-send "Apprendys" "Accessibilité désactivée."
else
  xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 12"
  xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 48
  notify-send "Apprendys" "Accessibilité activée : texte + curseur agrandis."
fi

pkill -HUP xfsettingsd
