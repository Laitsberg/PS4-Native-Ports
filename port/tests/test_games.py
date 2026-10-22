# SPDX-License-Identifier: GPL-2.0-or-later
"""games.py: the launcher recognizes each supported game from its param.sfo."""
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(ROOT / 'launcher'), str(ROOT / 'scripts')]
import games  # noqa: E402
import userdata  # noqa: E402


def write_sfo(folder, values):
    """A minimal param.sfo with string values (format 0x204)."""
    keys = b''.join(k.encode() + b'\0' for k in values)
    keys += b'\0' * (-len(keys) % 4)
    data, entries, key_off, data_off = b'', b'', 0, 0
    for k, v in values.items():
        raw = v.encode() + b'\0'
        size = len(raw) + (-len(raw) % 4)
        entries += struct.pack('<HHIII', key_off, 0x204, len(raw), size, data_off)
        data += raw.ljust(size, b'\0')
        key_off += len(k) + 1
        data_off += size
    key_table = 20 + len(entries)
    blob = struct.pack('<4sIIII', b'\0PSF', 0x101, key_table, key_table + len(keys), len(values))
    (folder / 'sce_sys').mkdir(parents=True)
    (folder / 'sce_sys' / 'param.sfo').write_bytes(blob + entries + keys + data)


class GamesTests(unittest.TestCase):
    def detect(self, values):
        with tempfile.TemporaryDirectory() as tmp:
            write_sfo(Path(tmp), values)
            return games.detect(tmp)

    def test_known_title_ids(self):
        self.assertIs(self.detect({'TITLE_ID': 'CUSA00223', 'TITLE': 'inFAMOUS Second Son'}), games.SECOND_SON)
        self.assertIs(self.detect({'TITLE_ID': 'CUSA00897', 'TITLE': 'inFAMOUS First Light'}), games.FIRST_LIGHT)
        self.assertIs(self.detect({'TITLE_ID': 'CUSA01661', 'TITLE': 'J-STARS Victory VS+'}), games.J_STARS)
        self.assertIs(self.detect({'TITLE_ID': 'CUSA01113', 'TITLE': 'Gravity Rush™ Remastered'}), games.GRAVITY_RUSH)

    def test_other_region_by_title(self):
        self.assertIs(self.detect({'TITLE_ID': 'CUSA99999', 'TITLE': 'inFAMOUS™ First Light'}), games.FIRST_LIGHT)

    def test_unknown_game_gets_a_profile(self):
        game = self.detect({'TITLE_ID': 'CUSA12345', 'TITLE': 'Some Game', 'INSTALL_DIR_SAVEDATA': 'CUSA12345'})
        self.assertEqual((game.title, game.save_serial, game.xpps_jobs), ('Some Game', 'CUSA12345', False))

    def test_sensor_mode_toggle(self):
        self.assertEqual([g.motion_toggle for g in games.KNOWN], [True, True, False, False])
        self.assertFalse(self.detect({'TITLE_ID': 'CUSA12345', 'TITLE': 'Some Game'}).motion_toggle)

    def test_no_folder_is_second_son(self):
        self.assertIs(games.detect(''), games.SECOND_SON)

    def test_tested_eboots(self):
        self.assertTrue(games.eboot_status(games.FIRST_LIGHT, (0x6ffd70, 136_535_375))[0])
        self.assertFalse(games.eboot_status(games.J_STARS, (0x6ffd70, 136_535_375))[0])
        self.assertTrue(games.eboot_status(games.GRAVITY_RUSH, (0x2f0, 37_451_368))[0])

    def test_set_serial(self):
        old = userdata.SERIAL
        try:
            userdata.set_serial('CUSA00897')
            self.assertEqual(userdata.SERIAL, 'CUSA00897')
        finally:
            userdata.set_serial(old)


if __name__ == '__main__':
    unittest.main()
