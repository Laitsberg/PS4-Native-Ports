"""Steam shortcuts (launcher/steam_shortcuts.py): one non-Steam entry per library game, all through
the same Play exe, and the --game flag those entries start the game with."""
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from paths import ROOT
sys.path.insert(0, str(ROOT / 'launcher'))
import infamous_run  # noqa: E402
import steam_shortcuts as steam  # noqa: E402

EXE = r'C:\Games\PS4 Native Ports\Play PS4 Native Ports.exe'


def entries(vdf):
    root = steam.parse(Path(vdf).read_bytes())[0]
    return [{k: v for _t, k, v in value} for _t, _k, value in root[0][2]]


class ShortcutsTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.vdf = Path(self.dir.name) / 'shortcuts.vdf'

    def tearDown(self):
        self.dir.cleanup()

    def test_one_entry_per_game_through_the_same_exe(self):
        steam.add_shortcut(self.vdf, 'inFAMOUS First Light', EXE, r'C:\Games', '', '--game "D:\\FL"')
        steam.add_shortcut(self.vdf, 'J-STARS Victory VS+', EXE, r'C:\Games', '', '--game "D:\\JS"')
        rows = entries(self.vdf)
        self.assertEqual(['inFAMOUS First Light', 'J-STARS Victory VS+'], [r['AppName'] for r in rows])
        self.assertEqual(['--game "D:\\FL"', '--game "D:\\JS"'], [r['LaunchOptions'] for r in rows])
        self.assertEqual(f'"{EXE}"', rows[0]['Exe'])

    def test_adding_again_updates_and_keeps_play_time(self):
        steam.add_shortcut(self.vdf, 'First Light', EXE, r'C:\Games', '', '--game "D:\\FL"')
        root = steam.parse(self.vdf.read_bytes())[0]
        game = root[0][2][0][2]
        game[[k for _t, k, _v in game].index('LastPlayTime')] = (steam.INT32, 'LastPlayTime', 1760000000)
        self.vdf.write_bytes(steam.dump(root) + bytes([steam.END]))   # as Steam would have saved it
        steam.add_shortcut(self.vdf, 'inFAMOUS First Light', EXE, r'C:\Games', 'icon0.png', '--game "D:\\FL"')
        rows = entries(self.vdf)
        self.assertEqual(1, len(rows))
        self.assertEqual(('inFAMOUS First Light', 'icon0.png', 1760000000),
                         (rows[0]['AppName'], rows[0]['icon'], rows[0]['LastPlayTime']))
        self.assertTrue(self.vdf.with_name('shortcuts.vdf.bak').is_file())

    def test_file_round_trips_byte_for_byte(self):
        steam.add_shortcut(self.vdf, 'A', EXE, r'C:\Games', '', '--game "D:\\A"')
        data = self.vdf.read_bytes()
        self.assertEqual(data, steam.dump(steam.parse(data)[0]) + bytes([steam.END]))

    def test_appid_is_steams_crc_with_the_top_bit(self):
        appid = steam.add_shortcut(self.vdf, 'A', EXE, r'C:\Games', '')
        self.assertTrue(appid & 0x80000000)
        self.assertEqual(appid & 0xffffffff, entries(self.vdf)[0]['appid'] & 0xffffffff)

    def test_artwork_goes_to_the_grid_folder(self):
        art, icon = Path(self.dir.name, 'pic1.png'), Path(self.dir.name, 'icon0.png')
        art.write_bytes(b'art')
        icon.write_bytes(b'icon')
        steam.add_artwork(self.dir.name, 123, str(art), str(icon))
        grid = Path(self.dir.name, 'grid')
        self.assertEqual(['123.png', '123_hero.png', '123_icon.png'], sorted(p.name for p in grid.iterdir()))
        steam.add_artwork(self.dir.name, 456, '', '')   # a dump without images: nothing, no error


class GameFlagTests(unittest.TestCase):
    def test_game_flag_picks_the_folder_for_this_start(self):
        with mock.patch.dict(os.environ, {}, clear=False), \
                mock.patch.object(infamous_run, 'attach_stdio'), \
                mock.patch.object(infamous_run, 'clear_shader_cache', return_value=(0, [])) as clear:
            os.environ.pop('ISS_GAME_DIR', None)
            self.assertEqual(0, infamous_run.main(['--game', '/games/first-light', '--clear-shader-cache']))
            self.assertEqual('/games/first-light', os.environ['ISS_GAME_DIR'])
            self.assertEqual('/games/first-light', clear.call_args[0][0]['game_dir'])


if __name__ == '__main__':
    unittest.main()
