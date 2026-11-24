import re
import subprocess
import sys
import unittest
from html import unescape
from html.parser import HTMLParser
from pathlib import Path


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.keys = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a":
            self.links.append(attrs["href"])
        if tag == "input":
            self.keys.append(attrs["value"])


class RenderTest(unittest.TestCase):
    def test_artist_slots_and_links_match_source(self):
        scripts = Path(__file__).resolve().parent
        source = (scripts.parent / "lolla-chile-2027.md").read_text(encoding="utf-8")
        html = subprocess.check_output(
            [sys.executable, scripts / "render-lolla.py"], text=True
        )
        page = Page()
        page.feed(html)
        keys = []
        for day, section in re.findall(r"^## ([^\n]+)\n(.*?)(?=^## |\Z)", source, re.M | re.S):
            keys.extend(f"{day}/{name}" for name in re.findall(r"^- \[ \] (.+?) — ", section, re.M))
        self.assertTrue(keys)
        self.assertEqual(page.keys, keys)
        self.assertEqual(len(set(page.keys)), len(keys))
        self.assertEqual(page.links, re.findall(r"\]\((https://[^\s()]+)\)", source))

    def test_qualifications_and_escaped_song_title(self):
        html = subprocess.check_output(
            [sys.executable, Path(__file__).with_name("render-lolla.py")], text=True
        )
        text = unescape(re.sub(r"<[^>]+>", "", html))
        for expected in (
            "El orden del cartel no indica el horario.",
            "no son el repertorio anunciado del festival.",
            "Top de Gondwana:",
            "Top de Alain Johannes:",
            "(sin top verificable)",
            'Sexy Bitch [Extended] (feat. Aliaune "Akon" Thiam & Akon)',
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, text)


if __name__ == "__main__":
    unittest.main()
