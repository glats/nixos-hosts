package romcatalog

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestLolRomsSearch(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte(`<div class="row">
<a href="/Nintendo/Super%20Nintendo%20Entertainment%20System/Super%20Mario%20World%20(USA).7z">Super Mario World (USA).7z</a><span class="file-meta">2026-02-26</span>
</div>
<div class="row">
<a href="/Nintendo/Super%20Nintendo%20Entertainment%20System/Speed%20Hacks/Fast%20Game.7z">Fast Game.7z</a>
</div>
<div class="row">
<a href="/Nintendo/Game%20Boy%20Advance/Metroid%20Fusion%20(USA).7z">Metroid Fusion (USA).7z</a>
</div>`))
	}))
	defer server.Close()

	source := NewLolRoms(server.Client())
	source.BaseURL = server.URL

	games, err := source.Search(context.Background(), Query{Platform: "snes", Text: "super mario"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(games) != 1 {
		t.Fatalf("got %d games, want 1: %+v", len(games), games)
	}
	game := games[0]
	if game.Title != "Super Mario World (USA)" {
		t.Errorf("title = %q", game.Title)
	}
	if game.Platform != "snes" {
		t.Errorf("platform = %q", game.Platform)
	}
	if game.Files[0].URL == "" || !game.Files[0].Archive {
		t.Errorf("file = %+v", game.Files[0])
	}
}

func TestLolRomsConsolePlatform(t *testing.T) {
	cases := map[string]string{
		"Super Nintendo Entertainment System": "snes",
		"Game Boy Advance":                    "gba",
		"Nintendo Entertainment System":       "nes",
		"Unknown Console":                     "",
	}
	for console, want := range cases {
		got, ok := lolRomsConsolePlatform(console)
		if want == "" {
			if ok {
				t.Errorf("console %q must not match, got %q", console, got)
			}
			continue
		}
		if !ok || got != want {
			t.Errorf("console %q = %q, want %q", console, got, want)
		}
	}
}
