#!/usr/bin/env bash
# PS4 Native Ports classic launcher (Tk): game folder, languages, video, Play.
exec python3 "$(dirname -- "$(readlink -f -- "$0")")/port/launcher/infamous_launcher.py" "$@"
