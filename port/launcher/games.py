"""The games this port runs, recognized from the player's own game folder (sce_sys/param.sfo).

Every game shares the same runtime (tlg-probe) and the same preparation steps; a profile only
carries what differs between them: names shown by the launcher and the game window, the eboot
build the port was tested with, the save-data folder name and whether the Second Son-only extras
(shader job generator, built-in mods) apply. Nothing here comes from the games themselves except
numbers: the entry point and memory image size the ELF headers of a tested eboot.bin declare.

An unknown folder still gets a profile (named after its param.sfo), so another PS4 game can be
tried with the same launcher; it is reported as untested, never blocked.
"""
from dataclasses import dataclass, field
from pathlib import Path
import re


@dataclass(frozen=True)
class Game:
    key: str                     # stable id (settings, app id)
    title: str                   # full name: window title, game window name
    rail: tuple                  # launcher sidebar: (big line, small line)
    title_ids: frozenset         # TITLE_ID values of the regions/versions known to work
    save_serial: str             # folder under savedata/<user>/ (the game's INSTALL_DIR_SAVEDATA)
    names: tuple = ()            # lowercase parts of param.sfo TITLE that identify other regions
    tested: dict = field(default_factory=dict)   # {(entry, image size): 'region version'} of tested eboots
    xpps_jobs: bool = False      # tools/xpps shader job generator (built from the Second Son 1.07 engine)
    note: str = ''               # what the player should know (en)


SECOND_SON = Game(
    key='infamous-ss', title='inFAMOUS Second Son', rail=('inFAMOUS', 'Second Son · PC'),
    title_ids=frozenset({'CUSA00223', 'CUSA00004'}), names=('second son',),
    save_serial='CUSA00223',
    tested={(0x61dfd0, 133_846_143): '1.07'},
    xpps_jobs=True)

FIRST_LIGHT = Game(
    key='infamous-fl', title='inFAMOUS First Light', rail=('inFAMOUS', 'First Light · PC'),
    title_ids=frozenset({'CUSA00897'}), names=('first light',),
    save_serial='CUSA00897',
    tested={(0x6ffd70, 136_535_375): 'EU 1.00 (APP_VER 01.04)'},
    note='Same engine as Second Son. Leaderboards (Score Attack) are offline.')

J_STARS = Game(
    key='jstars-vs', title='J-STARS Victory VS+', rail=('J-STARS', 'Victory VS+ · PC'),
    title_ids=frozenset({'CUSA01661'}), names=('j-stars', 'j stars'),
    save_serial='CUSA01661',
    tested={(0x305890, 8_583_040): 'EU 1.00'},
    note='Online battles, PSN dialogs and Share Play are offline.')

KNOWN = (SECOND_SON, FIRST_LIGHT, J_STARS)
DEFAULT = SECOND_SON


def _sfo(game_dir):
    try:
        from prepare import read_sfo
    except ImportError:
        return None
    return read_sfo(Path(game_dir) / 'sce_sys' / 'param.sfo') if game_dir else None


def detect(game_dir):
    """The profile of the game in game_dir (DEFAULT when the folder has no readable param.sfo)."""
    values = _sfo(game_dir)
    if not values:
        return DEFAULT
    title_id = str(values.get('TITLE_ID') or '')
    title = str(values.get('TITLE') or '').lower()
    for game in KNOWN:
        if title_id in game.title_ids:
            return game
    for game in KNOWN:   # another region of a known game: same code, other title id
        if any(part in title for part in game.names):
            return game
    name = str(values.get('TITLE') or title_id or 'PS4 game').replace('™', '').replace('®', '').strip()
    save = str(values.get('INSTALL_DIR_SAVEDATA') or title_id or 'UNKNOWN')
    key = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-') or 'ps4-game'
    return Game(key=key, title=name, rail=(name.split(' ')[0], 'PC (untested)'),
                title_ids=frozenset({title_id}), save_serial=save,
                note='Not tested with this port: it may stop at an unsupported system function.')


def eboot_status(game, layout):
    """(tested, label): whether this eboot layout (entry, image size) is a tested build."""
    label = game.tested.get(tuple(layout))
    return (label is not None, label or '')


def info(game_dir):
    """What the library shows about a game folder: {path, title, title_id, version, cover, art, key}.
    cover/art are the dump's own sce_sys/icon0.png and pic1.png (never shipped), '' when absent."""
    game = Path(game_dir)
    values = _sfo(game_dir) or {}
    profile = detect(game_dir)
    def image(*names):
        for name in names:
            if (game / 'sce_sys' / name).is_file():
                return str(game / 'sce_sys' / name)
        return ''
    return {'path': str(game), 'title': profile.title, 'key': profile.key,
            'title_id': str(values.get('TITLE_ID') or ''),
            'version': str(values.get('APP_VER') or values.get('VERSION') or '').lstrip('0') or '',
            'cover': image('icon0.png'), 'art': image('pic1.png', 'pic0.png'),
            'known': profile in KNOWN, 'second_son': profile is SECOND_SON}
