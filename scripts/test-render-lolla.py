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
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        if tag == "input":
            self.keys.append(attrs["value"])


class RenderTest(unittest.TestCase):
    def test_schedule_notice_starts_hidden_without_replacing_checklist(self):
        html = subprocess.check_output(
            [sys.executable, Path(__file__).with_name("render-lolla.py")], text=True
        )
        self.assertIn('<p id="schedule-notice" hidden>', html)
        self.assertIn("Horarios publicados", html)
        self.assertIn("fetch('/schedule.json'", html)

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

    def test_spotify_track_follows_each_youtube_music_track(self):
        scripts = Path(__file__).resolve().parent
        html = subprocess.check_output([sys.executable, scripts / "render-lolla.py"], text=True)
        page = Page()
        page.feed(html)
        youtube_track = "https://music.youtube.com/watch?v="
        tracks = [url.removeprefix(youtube_track) for url in page.links if url.startswith(youtube_track)]
        self.assertEqual(len(tracks), 255)
        pairs = re.findall(
            re.escape(youtube_track) + r'([\w-]+)">[^<]+</a> \('
            r'(?:<a href="(https://open\.spotify\.com/track/[A-Za-z0-9]{22})">Spotify</a>'
            r'|grabación no verificada para el dúo chileno)\)',
            html,
        )
        self.assertEqual([video for video, _ in pairs], tracks)
        self.assertEqual([url for _, url in pairs if url],
                         [url for url in page.links if url.startswith("https://open.spotify.com/")])
        self.assertEqual([video for video, url in pairs if not url], ["RMk57fhi85I", "-GFnt0TodV4"])

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
