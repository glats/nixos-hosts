package romcatalog

import (
	"fmt"
	"html/template"
	"strings"
)

// templateFuncs are the helpers the page template uses.
var templateFuncs = template.FuncMap{
	"encode": encodeID,
	"size":   humanSize,
	"join":   strings.Join,
}

// humanSize renders a byte count for the gallery.
func humanSize(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for size := n / unit; size >= unit; size /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(n)/float64(div), "KMGTPE"[exp])
}

const pageTemplate = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Title}}</title>
<style>
:root { color-scheme: dark; --bg:#12141a; --card:#1b1f28; --line:#2a3040; --fg:#e8ecf4; --dim:#98a2b8; --accent:#7aa2f7; --ok:#7ddc9a; --bad:#f2777a; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.5 system-ui, sans-serif; }
header { display:flex; gap:1rem; align-items:baseline; padding:1rem 1.5rem; border-bottom:1px solid var(--line); }
header a { color:var(--accent); text-decoration:none; font-weight:600; }
main { padding:1.5rem; max-width:1400px; }
h1 { font-size:1.4rem; margin:0 0 .5rem; }
.sub { color:var(--dim); font-size:.9rem; margin:0 0 1.25rem; }
.steps { display:grid; gap:1rem; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); margin-bottom:1.5rem; }
.steps div { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:1rem; }
.steps b { display:block; color:var(--accent); margin-bottom:.3rem; }
.platforms { display:grid; gap:1rem; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); list-style:none; padding:0; }
.platforms a { display:block; padding:1rem; background:var(--card); border:1px solid var(--line); border-radius:10px; text-decoration:none; color:var(--fg); }
.platforms a:hover { border-color:var(--accent); }
.platforms small { display:block; color:var(--dim); margin-top:.35rem; }
form { display:flex; gap:.5rem; margin:0 0 1.5rem; }
input { flex:1; padding:.6rem .8rem; background:var(--card); border:1px solid var(--line); border-radius:8px; color:var(--fg); }
button { padding:.5rem .9rem; background:var(--accent); border:0; border-radius:8px; color:#0d1117; font-weight:600; cursor:pointer; }
button:disabled { opacity:.5; cursor:progress; }
.grid { display:grid; gap:1rem; grid-template-columns:repeat(auto-fill,minmax(180px,1fr)); }
.card { background:var(--card); border:1px solid var(--line); border-radius:10px; overflow:hidden; text-decoration:none; color:var(--fg); display:flex; flex-direction:column; }
.card:hover { border-color:var(--accent); }
.cover { aspect-ratio:3/4; width:100%; object-fit:cover; background:#0c0e13; display:block; }
.cover-missing { aspect-ratio:3/4; display:flex; align-items:center; justify-content:center; color:var(--dim); font-size:.8rem; padding:.5rem; text-align:center; }
.meta { padding:.5rem .6rem; font-size:.82rem; flex:1; }
.meta b { display:block; font-weight:600; line-height:1.25; }
.meta span { color:var(--dim); }
.card .actions { padding:0 .6rem .7rem; }
.status { color:var(--dim); font-size:.75rem; margin-top:.35rem; min-height:1em; }
.status.done { color:var(--ok); }
.status.failed { color:var(--bad); }
.detail { display:grid; gap:2rem; grid-template-columns:220px 1fr; align-items:start; }
.error { background:#3a1d22; border:1px solid #7a2b36; padding:.8rem 1rem; border-radius:8px; }
.jobs { margin-top:2rem; border-top:1px solid var(--line); padding-top:1rem; }
.jobs li { color:var(--dim); font-size:.85rem; }
table.files { width:100%; border-collapse:collapse; margin:1rem 0; }
table.files td { padding:.35rem .5rem; border-bottom:1px solid var(--line); font-size:.85rem; }
code { background:#0c0e13; padding:.1rem .35rem; border-radius:4px; }
.destination { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:.8rem 1rem; margin-bottom:1.5rem; font-size:.85rem; }
</style>
</head>
<body>
<header>
  <a href="/">ROM catalog</a>
  {{if .Platform}}<a href="/">/</a><span>{{.Platform.Name}}</span>{{end}}
</header>
<main>
{{if .Error}}<p class="error">{{.Error}}</p>{{end}}

{{if .Platforms}}
<h1>Download ROMs, organized by platform</h1>
<p class="sub">Every download lands in the library, one folder per platform, and RomM serves that library with covers and screenshots.</p>
<div class="steps">
  <div><b>1. Pick a platform</b>Each system has its own folder and its own emulator cores.</div>
  <div><b>2. Pick the game</b>Search the catalog, then read the detail page for checksums and screenshots.</div>
  <div><b>3. Download</b>The ROM is verified, extracted and installed in the platform folder. RomM picks it up on the next scan.</div>
</div>
<ul class="platforms">
{{range .Platforms}}
  <li><a href="/platform/{{.Slug}}">{{.Name}}<small>{{join .Cores ", "}}</small></a></li>
{{end}}
</ul>
{{end}}

{{if .Platform}}
<h1>{{.Platform.Name}}</h1>
<p class="sub">{{.Platform.Slug}} &middot; cores: {{join .Platform.Cores ", "}} &middot; {{.Total}} results</p>
<p class="destination">Downloads are installed in <code>{{.Destination}}</code></p>
<form method="get" action="/platform/{{.Platform.Slug}}">
  <input type="search" name="q" value="{{.Query}}" placeholder="Search in {{.Platform.Name}}">
  <button type="submit">Search</button>
</form>
{{end}}

{{if .Game}}
<div class="detail">
  <div>
    {{if .Cover}}<img class="cover" src="{{.Cover}}" alt="{{.Game.Title}}" onerror="this.style.display='none'">{{else}}<div class="cover-missing">{{.Game.Title}}</div>{{end}}
  </div>
  <div>
    <h1>{{.Game.Title}}</h1>
    <p class="sub">{{.Game.Platform}}{{if .Game.Region}} &middot; {{.Game.Region}}{{end}}{{if .Game.Size}} &middot; {{size .Game.Size}}{{end}} &middot; source: {{.Game.Source}}</p>
    <p class="destination">Installed in <code>{{.Destination}}</code></p>
    <table class="files">
      {{range .Game.Files}}<tr><td><code>{{.Name}}</code></td><td>{{if .Size}}{{size .Size}}{{end}}</td><td>{{if .MD5}}md5 {{.MD5}}{{end}}</td></tr>{{end}}
    </table>
    <button id="dl" data-id="{{.Game.ID}}">Download into the library</button>
    <p id="status" class="status"></p>
    {{if .Game.PageURL}}<p class="sub">Source page: <a href="{{.Game.PageURL}}" rel="noreferrer noopener" target="_blank">{{.Game.PageURL}}</a></p>{{end}}
  </div>
</div>
{{end}}

{{if .Games}}
<div class="grid">
{{range .Games}}
  <div class="card">
    <a href="/game/{{encode .ID}}">
      {{if .Cover}}<img class="cover" loading="lazy" src="{{.Cover}}" alt="{{.Title}}" onerror="this.style.display='none'">{{else}}<div class="cover-missing">{{.Title}}</div>{{end}}
      <div class="meta"><b>{{.Title}}</b><span>{{.Region}}{{if .Size}} &middot; {{size .Size}}{{end}}</span></div>
    </a>
    <div class="actions">
      <button class="dl" data-id="{{.ID}}" data-title="{{.Title}}">Download</button>
      <p class="status"></p>
    </div>
  </div>
{{end}}
</div>
{{end}}

{{if .Jobs}}
<div class="jobs">
  <h1>Downloads</h1>
  <ul>
  {{range .Jobs}}<li>#{{.ID}} {{.Title}} — {{.Status}}{{if .Error}}: {{.Error}}{{end}}{{if .Path}}: {{.Path}}{{end}}</li>{{end}}
  </ul>
</div>
{{end}}
</main>
<script>
function watch(button, job) {
  const status = button.parentElement.querySelector('.status');
  status.textContent = 'starting…';
  status.className = 'status';
  const timer = setInterval(async () => {
    const state = await (await fetch('/api/job?id=' + job.id)).json();
    status.textContent = state.status +
      (state.total ? ' ' + Math.round(state.downloaded / state.total * 100) + '%' : '');
    if (state.status === 'done') {
      clearInterval(timer);
      status.textContent = 'saved to ' + state.path;
      status.className = 'status done';
      button.disabled = false;
    } else if (state.status === 'failed') {
      clearInterval(timer);
      status.textContent = state.error;
      status.className = 'status failed';
      button.disabled = false;
    }
  }, 2000);
}

document.querySelectorAll('button.dl').forEach((button) => {
  button.addEventListener('click', async () => {
    button.disabled = true;
    const response = await fetch('/api/download', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({id: button.dataset.id})
    });
    const job = await response.json();
    watch(button, job);
  });
});

const detail = document.getElementById('dl');
if (detail) {
  detail.addEventListener('click', async () => {
    detail.disabled = true;
    const response = await fetch('/api/download', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({id: detail.dataset.id})
    });
    watch(detail, await response.json());
  });
}
</script>
</body>
</html>
`
