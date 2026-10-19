"""The Qt launcher's Russian interface (launcher/qt/i18n/ru.json, logic.Translator): Russian is
looked up by the English text, so every (en, pt) pair the launcher shows can have one."""
import json
import re
import sys
import unittest
from unittest import mock

from paths import ROOT
sys.path.insert(0, str(ROOT / 'launcher'))
from qt import logic  # noqa: E402

QT = ROOT / 'launcher' / 'qt'
STRINGS = json.loads((QT / 'i18n' / 'strings.json').read_text(encoding='utf-8'))
RU_TEXT = json.loads((QT / 'i18n' / 'ru.json').read_text(encoding='utf-8'))
RU = {'ui_language': 'ru_RU'}
# Names and symbols that read the same in Russian.
SAME_IN_RUSSIAN = {'pad_btn_l1', 'pad_btn_r1', 'pad_btn_l2', 'pad_btn_r2', 'pad_btn_options', 'chip_gpu',
                   'chip_gpu_novk', 'rep_row_gpu', 'sup_discord', 'sup_youtube', 'sup_github', 'backups_line',
                   'brand'}


def placeholders(text):
    return set(re.findall(r'{(\w+)}', text))


class RussianTests(unittest.TestCase):
    def test_every_interface_string_has_russian(self):
        # A new key (also one merged from upstream) shows English until it gets a line in ru.json.
        missing = [key for key, entry in STRINGS.items() if entry['en'] not in RU_TEXT and key not in SAME_IN_RUSSIAN]
        self.assertEqual([], missing)

    def test_placeholders_match_the_english_text(self):
        for en, ru in RU_TEXT.items():
            self.assertEqual(placeholders(en), placeholders(ru), en)
            self.assertTrue(ru.strip(), en)

    def test_translator_speaks_russian_and_falls_back_to_english(self):
        t = logic.Translator(RU)
        self.assertEqual('Играть', t('nav_play'))
        self.assertEqual('Кеш шейдеров: 1 MB', t('chip_cache', size='1 MB'))
        self.assertEqual('Вкл.', t.pair(('On', 'Ligado')))
        self.assertEqual('Only in English', t.pick('Only in English', 'Só em português'))
        self.assertEqual('L1', t('pad_btn_l1'))
        self.assertEqual('%d.%m.%Y %H:%M', t.date_format())
        pt = logic.Translator({'ui_language': 'pt_BR'})
        self.assertEqual('Jogar', pt('nav_play'))
        self.assertFalse(pt.ru())

    def test_news_come_from_the_russian_section_of_the_readme(self):
        readme = "## Что нового\n- **Память без кода 25**: текст\n\n## What's new\n- **Memory without code 25**: text\n"
        self.assertEqual(['Память без кода 25'], logic.parse_news(readme, False, russian=True))
        self.assertEqual(['Memory without code 25'], logic.parse_news(readme, False))

    def test_automatic_language_follows_the_system(self):
        with mock.patch.dict('os.environ', {'LC_ALL': '', 'LC_MESSAGES': '', 'LANG': 'ru_RU.UTF-8'}):
            self.assertEqual('ru_RU', logic.ui_language({'ui_language': 'auto'}))
        with mock.patch.dict('os.environ', {'LC_ALL': '', 'LC_MESSAGES': '', 'LANG': ''}), \
                mock.patch('locale.getlocale', return_value=('Russian_Russia', '1251')):   # Windows
            self.assertEqual('ru_RU', logic.ui_language({}))
        with mock.patch.dict('os.environ', {'LC_ALL': '', 'LC_MESSAGES': '', 'LANG': 'de_DE.UTF-8'}):
            self.assertEqual('en_US', logic.ui_language({'ui_language': 'auto'}))
        self.assertEqual('en_US', logic.ui_language({'ui_language': 'xx_XX'}))
        self.assertFalse(logic.is_portuguese(RU))


if __name__ == '__main__':
    unittest.main()
