package romcatalog

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestArchiveOrgSearch(t *testing.T) {
	var server *httptest.Server
	server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/metadata/item-one") {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"files": []map[string]any{
				{"name": "NES/Super Mario Bros. (USA).zip", "size": 40960, "format": "ZIP", "md5": "abc123", "sha1": "def456"},
				{"name": "NES/Metroid (USA, Europe) (En).zip", "size": 20480, "format": "ZIP", "md5": "aaa111"},
				{"name": "BIOS/BIOS.zip", "size": 1024, "format": "ZIP", "md5": "bbb222"},
				{"name": "readme.txt", "size": 100, "format": "Text"},
			},
		})
	}))
	defer server.Close()

	source := NewArchiveOrg(server.Client())
	source.BaseURL = server.URL
	source.Sets = map[string][]string{"nes": {"item-one"}}

	games, err := source.Search(context.Background(), Query{Platform: "nes"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(games) != 2 {
		t.Fatalf("got %d games, want 2: %+v", len(games), games)
	}
	if games[0].Title != "Metroid (USA, Europe) (En)" {
		t.Errorf("title = %q", games[0].Title)
	}
	if games[0].Region != "usa" {
		t.Errorf("region = %q", games[0].Region)
	}
	if games[0].Size != 20480 {
		t.Errorf("size = %d", games[0].Size)
	}
	if !games[0].Files[0].Archive {
		t.Error("zip file must be marked as archive")
	}
	if !strings.HasSuffix(games[0].Files[0].URL, "/download/item-one/NES%2FMetroid%20%28USA%2C%20Europe%29%20%28En%29.zip") {
		t.Errorf("url = %q", games[0].Files[0].URL)
	}
	if games[0].Files[0].MD5 != "aaa111" {
		t.Errorf("md5 = %q", games[0].Files[0].MD5)
	}
}

func TestArchiveOrgSearchFiltersByText(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"files": []map[string]any{
				{"name": "Mario (USA).zip", "size": 1, "md5": "a"},
				{"name": "Zelda (USA).zip", "size": 2, "md5": "b"},
			},
		})
	}))
	defer server.Close()

	source := NewArchiveOrg(server.Client())
	source.BaseURL = server.URL
	source.Sets = map[string][]string{"nes": {"item-one"}}

	games, err := source.Search(context.Background(), Query{Platform: "nes", Text: "zelda"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(games) != 1 || games[0].Title != "Zelda (USA)" {
		t.Fatalf("got %+v", games)
	}
}

func TestCleanTitle(t *testing.T) {
	cases := []struct {
		name string
		want string
	}{
		{"No-Intro - Super Mario Bros. (USA).zip", "Super Mario Bros. (USA)"},
		{"007 - Everything or Nothing (Japan).zip", "007 - Everything or Nothing (Japan)"},
		{"Sonic The Hedgehog (USA, Europe).7z", "Sonic The Hedgehog (USA, Europe)"},
	}
	for _, tt := range cases {
		if got := cleanTitle(tt.name); got != tt.want {
			t.Errorf("cleanTitle(%q) = %q, want %q", tt.name, got, tt.want)
		}
	}
}

func TestPlatformAccepts(t *testing.T) {
	platform, ok := PlatformBySlug("snes")
	if !ok {
		t.Fatal("snes platform missing")
	}
	if !platform.Accepts("Super Mario World (USA).SFC") {
		t.Error("uppercase extension must be accepted")
	}
	if platform.Accepts("game.zip") {
		t.Error("zip is not a ROM")
	}
}

func TestRegistrySkipsSourcesWithoutPlatform(t *testing.T) {
	registry := NewRegistry(
		&fakeSource{name: "all", games: []Game{{ID: "a", Source: "all"}}},
		&fakeSource{name: "snes-only", platforms: []string{"snes"}, games: []Game{{ID: "b", Source: "snes-only"}}},
	)
	games, err := registry.Search(context.Background(), Query{Platform: "gb"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(games) != 1 || games[0].Source != "all" {
		t.Fatalf("got %+v", games)
	}
}

// fakeSource is a source that returns one fixed game.
type fakeSource struct {
	name      string
	platforms []string
	games     []Game
}

func (f *fakeSource) Name() string        { return f.name }
func (f *fakeSource) Platforms() []string { return f.platforms }
func (f *fakeSource) Search(context.Context, Query) ([]Game, error) {
	return f.games, nil
}
