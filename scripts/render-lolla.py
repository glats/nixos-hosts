import re
import sys
from html import escape
from pathlib import Path


def inline(text):
    parts = re.split(r"\[((?:\\.|[^\]\\])+)\]\((https://[^()\s]+)\)", text)
    result = [escape(parts[0])]
    for title, url, tail in zip(parts[1::3], parts[2::3], parts[3::3]):
        title = title.replace(r"\[", "[").replace(r"\]", "]")
        result.append(f'<a href="{escape(url)}">{escape(title)}</a>')
        result.append(escape(tail))
    return "".join(result)


def render(source):
    rows = []
    day = ""
    for line in source.splitlines():
        if line.startswith("- [ ] "):
            artist, links = line[6:].split(" — ", 1)
            key = escape(f"{day}/{artist}")
            rows.append(
                f'<li><label><input type="checkbox" value="{key}"> '
                f'{escape(artist)}</label><div>{inline(links)}</div></li>'
            )
        elif line.startswith("## "):
            if day:
                rows.append("</ul>")
            day = line[3:]
            rows.append(f"<h2>{escape(day)}</h2><ul>")
        elif line.startswith("# "):
            rows.append(f"<h1>{escape(line[2:])}</h1>")
        elif line:
            rows.append(f"<p>{inline(line)}</p>")
    if day:
        rows.append("</ul>")
    return """<!doctype html>
<html lang="es">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lollapalooza Chile 2027 — Artistas por día</title>
<style>
:root { color-scheme: light dark; font: 1rem/1.55 system-ui, sans-serif }
body { max-width: 48rem; margin: auto; padding: 1.25rem }
ul { list-style: none; padding: 0 }
li { padding: .65rem 0; border-bottom: 1px solid GrayText }
label { display: inline-flex; align-items: center; min-height: 2rem; gap: .35rem; font-weight: 650 }
a { text-underline-offset: .15em }
</style>
<main>
<p id="schedule-notice" hidden><strong>Horarios publicados.</strong> <a>Ver programación oficial</a></p>
""" + "\n".join(rows) + """
</main>
<script>
for (const box of document.querySelectorAll('input[type="checkbox"]')) {
  const key = 'lolla-2027/' + box.value;
  try {
    box.checked = localStorage.getItem(key) === '1';
    box.addEventListener('change', () => {
      try {
        if (box.checked) localStorage.setItem(key, '1');
        else localStorage.removeItem(key);
      } catch {}
    });
  } catch {}
}
fetch('/schedule.json', { cache: 'no-store' })
  .then(response => response.ok ? response.json() : null)
  .then(schedule => {
    if (!schedule || typeof schedule.url !== 'string') return;
    const url = new URL(schedule.url);
    if (url.origin !== 'https://lollapaloozacl.com' || url.username || url.password ||
        !url.pathname.startsWith('/wp-content/uploads/')) return;
    const notice = document.getElementById('schedule-notice');
    notice.querySelector('a').href = url.href;
    notice.hidden = false;
  })
  .catch(() => {});
</script>
</html>
"""


if __name__ == "__main__":
    source = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path(__file__).resolve().parents[1] / "lolla-chile-2027.md"
    )
    sys.stdout.write(render(source.read_text(encoding="utf-8")))
