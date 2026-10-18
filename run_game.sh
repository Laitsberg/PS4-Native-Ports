#!/usr/bin/env bash
# Runs the selected game from a terminal with the launcher settings: ./run_game.sh [seconds]
exec python3 "$(dirname -- "$(readlink -f -- "$0")")/port/launcher/infamous_run.py" "$@"
