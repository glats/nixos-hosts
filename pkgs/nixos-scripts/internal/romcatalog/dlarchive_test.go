package romcatalog

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDlArchiveSearch(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Query().Get("action") {
		case "list":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"ok": true,
				"items": []map[string]any{
					{
						"id":           "abc123",
						"filename":     "Super Mario World (U) [!].zip",
						"size":         347370,
						"mime":         "application/zip",
						"download_url": "https://example.invalid/smw.zip",
						"folder":       "Upload_Kazu/Beastrom/Super_Nintendo",
					},
					{
						"id":       "def456",
						"filename": "Some Game.nsp",
						"size":     1024,
						"folder":   "Upload_Kazu/Beastrom/Game_ROMS",
					},
				},
				"total": 2,
			})
		default:
			http.Error(w, "unknown action", http.StatusBadRequest)
		}
	}))
	defer server.Close()

	source := NewDlArchive(server.Client())
	source.BaseURL = server.URL

	games, err := source.Search(context.Background(), Query{Platform: "snes"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(games) != 1 {
		t.Fatalf("got %d games, want 1: %+v", len(games), games)
	}
	game := games[0]
	if game.Title != "Super Mario World (U) [!]" {
		t.Errorf("title = %q", game.Title)
	}
	if game.Platform != "snes" {
		t.Errorf("platform = %q", game.Platform)
	}
	if game.Files[0].URL != "https://example.invalid/smw.zip" {
		t.Errorf("url = %q", game.Files[0].URL)
	}
	if !game.Files[0].Archive {
		t.Error("zip must be marked as archive")
	}
}

func TestDlArchiveFolderPlatform(t *testing.T) {
	cases := map[string]string{
		"Upload_Kazu/Beastrom/Nintendo_DS":    "nds",
		"Upload_Kazu/Beastrom/Super_Nintendo": "snes",
		"Upload_Kazu/Beastrom/Game_ROMS":      "switch",
		"Upload_Kazu/Beastrom/2026/11/13":     "",
	}
	for folder, want := range cases {
		got, ok := dlArchiveFolderPlatform(folder)
		if want == "" {
			if ok {
				t.Errorf("folder %q must not match a platform, got %q", folder, got)
			}
			continue
		}
		if !ok || got != want {
			t.Errorf("folder %q = %q, want %q", folder, got, want)
		}
	}
}
