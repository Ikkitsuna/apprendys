#!/usr/bin/env bash
set -e

# toggle mute
pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || true

# optionnel: désactiver le beep
xset -b 2>/dev/null || true

notify-send "Apprendys" "Mode concentration : son en bascule (mute/unmute)."

