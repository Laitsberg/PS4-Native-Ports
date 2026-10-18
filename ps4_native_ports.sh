#!/usr/bin/env bash
# PS4 Native Ports launcher, Qt Quick edition (the default; ps4_native_ports_classic.sh is the Tk one, kept as a fallback).
# Usa o venv ~/.../.venv-qt ou o python do sistema com PySide6-Essentials instalado.
here="$(dirname -- "$(readlink -f -- "$0")")"
py=python3
[ -x "$here/.venv-qt/bin/python" ] && py="$here/.venv-qt/bin/python"
exec "$py" "$here/port/launcher/infamous_launcher_qt.py" "$@"
