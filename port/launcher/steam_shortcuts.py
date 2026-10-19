# SPDX-License-Identifier: GPL-2.0-or-later
"""Adds games to Steam as non-Steam shortcuts (Steam's userdata/<id>/config/shortcuts.vdf).
From Supermedo/bloodborne_pc (launcher/bbport_steam.py, GPL-2.0); here one shortcut per game,
all starting the same Play exe with a different --game, so an entry is found by exe + options.

shortcuts.vdf is Valve's binary KeyValues: a type byte (0 = map, 1 = string, 2 = int32,
7 = uint64), a NUL-terminated key, then the value; 8 ends a map. The file holds one map,
"shortcuts", whose entries are maps named "0", "1", ...
"""
import shutil
import struct
import subprocess
import zlib
from pathlib import Path

MAP, STRING, INT32, UINT64, END = 0, 1, 2, 7, 8


def _cstring(data, at):
    end = data.index(b'\0', at)
    return data[at:end].decode('utf-8', errors='replace'), end + 1


def parse(data, at=0):
    """A map as a list of (type, key, value); nested maps are lists too. Returns (items, next)."""
    items = []
    while at < len(data):
        kind = data[at]
        at += 1
        if kind == END:
            return items, at
        key, at = _cstring(data, at)
        if kind == MAP:
            value, at = parse(data, at)
        elif kind == STRING:
            value, at = _cstring(data, at)
        elif kind == INT32:
            value, at = struct.unpack_from('<i', data, at)[0], at + 4
        elif kind == UINT64:
            value, at = struct.unpack_from('<Q', data, at)[0], at + 8
        else:
            raise ValueError(f'unknown field type {kind} in shortcuts.vdf')
        items.append((kind, key, value))
    return items, at


def dump(items):
    out = bytearray()
    for kind, key, value in items:
        out += bytes([kind]) + key.encode('utf-8') + b'\0'
        if kind == MAP:
            out += dump(value) + bytes([END])
        elif kind == STRING:
            out += str(value).encode('utf-8') + b'\0'
        elif kind == INT32:
            out += struct.pack('<i', value)
        elif kind == UINT64:
            out += struct.pack('<Q', value)
    return bytes(out)


def shortcut_id(exe, name):
    """The id Steam gives a non-Steam game: CRC32 of the quoted exe and the name, top bit set."""
    return (zlib.crc32((exe + name).encode('utf-8')) & 0xffffffff) | 0x80000000


def entry(name, exe, start_dir, icon, options=''):
    quoted = f'"{exe}"'
    appid = shortcut_id(quoted, name)
    return [
        (INT32, 'appid', struct.unpack('<i', struct.pack('<I', appid))[0]),
        (STRING, 'AppName', name), (STRING, 'Exe', quoted), (STRING, 'StartDir', f'"{start_dir}"'),
        (STRING, 'icon', icon), (STRING, 'ShortcutPath', ''), (STRING, 'LaunchOptions', options),
        (INT32, 'IsHidden', 0), (INT32, 'AllowDesktopConfig', 1), (INT32, 'AllowOverlay', 1),
        (INT32, 'OpenVR', 0), (INT32, 'Devkit', 0), (STRING, 'DevkitGameID', ''),
        (INT32, 'DevkitOverrideAppID', 0), (INT32, 'LastPlayTime', 0), (STRING, 'FlatpakAppID', ''),
        (MAP, 'tags', []),
    ]


def add_shortcut(vdf_path, name, exe, start_dir, icon, options=''):
    """Adds the shortcut to one shortcuts.vdf, or updates the entry that starts the same exe with
    the same options. Returns the appid. A copy of the old file is kept as shortcuts.vdf.bak."""
    vdf_path = Path(vdf_path)
    data = vdf_path.read_bytes() if vdf_path.exists() else b''
    root = parse(data)[0] if data else []
    shortcuts = next((value for kind, key, value in root if kind == MAP and key.lower() == 'shortcuts'), None)
    if shortcuts is None:
        shortcuts = []
        root.append((MAP, 'shortcuts', shortcuts))
    new = entry(name, exe, start_dir, icon, options)
    target = (f'"{exe}"'.lower(), options)
    for index, (kind, key, value) in enumerate(shortcuts):
        fields = {k.lower(): v for _t, k, v in value} if kind == MAP else {}
        if (str(fields.get('exe', '')).lower(), fields.get('launchoptions', '')) == target:
            # Keep what Steam or the player added (play time, tags).
            kept = {'lastplaytime', 'tags'}
            old = {k.lower(): (t, k, v) for t, k, v in value}
            shortcuts[index] = (MAP, key, [old[k.lower()] if k.lower() in kept and k.lower() in old else (t, k, v)
                                            for t, k, v in new])
            break
    else:
        shortcuts.append((MAP, str(len(shortcuts)), new))
    if data:
        vdf_path.with_name(vdf_path.name + '.bak').write_bytes(data)
    vdf_path.parent.mkdir(parents=True, exist_ok=True)
    vdf_path.write_bytes(dump(root) + bytes([END]))
    return shortcut_id(f'"{exe}"', name)


def add_artwork(config, appid, art='', icon=''):
    """The library images Steam looks for in config/grid: the dump's own pic1.png as the wide
    capsule and the hero banner, icon0.png as the icon (the player's files, copied locally)."""
    grid = Path(config) / 'grid'
    for source, names in ((art, (f'{appid}.png', f'{appid}_hero.png')), (icon, (f'{appid}_icon.png',))):
        if source and Path(source).is_file():
            grid.mkdir(parents=True, exist_ok=True)
            for name in names:
                shutil.copyfile(source, grid / name)


def steam_folder():
    """Steam's install folder from the registry, or None (also on Linux)."""
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r'Software\Valve\Steam') as key:
            path = Path(winreg.QueryValueEx(key, 'SteamPath')[0])
    except (ImportError, OSError):
        return None
    return path if path.is_dir() else None


def user_configs(steam):
    """userdata/<account>/config folders of the accounts that used Steam on this PC."""
    users = Path(steam) / 'userdata'
    return [d / 'config' for d in sorted(users.iterdir()) if d.is_dir() and d.name.isdigit() and d.name != '0'] \
        if users.is_dir() else []


def steam_running():
    result = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq steam.exe', '/NH'], capture_output=True,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    return b'steam.exe' in result.stdout.lower()
