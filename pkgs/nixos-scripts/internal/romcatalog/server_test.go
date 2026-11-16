package romcatalog

import (
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestPagesShowPlatformDownloadDirectory(t *testing.T) {
	root := t.TempDir()
	catalog := NewCatalog(NewRegistry(), t.TempDir(), time.Hour)
	for _, platform := range Platforms() {
		catalog.cache[platform.Slug] = &platformCache{Fetched: time.Now()}
	}
	server, err := NewServer(catalog, &Downloader{LibraryRoot: root}, NewJobs(), slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct{ slug, dir string }{{"snes", "snes"}, {"genesis", "megadrive"}} {
		t.Run(test.slug, func(t *testing.T) {
			game := Game{ID: "fixture:" + test.slug, Platform: test.slug, Title: "Fixture game"}
			catalog.cache[test.slug].Games = []Game{game}
			for _, route := range []string{"/platform/" + test.slug, "/game/" + encodeID(game.ID)} {
				recorder := httptest.NewRecorder()
				server.Handler().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, route, nil))
				if recorder.Code != http.StatusOK {
					t.Fatalf("%s status = %d", route, recorder.Code)
				}
				body := recorder.Body.String()
				want := "<code>" + filepath.Join(root, test.dir) + "</code>"
				if !strings.Contains(body, want) {
					t.Errorf("%s does not show destination %s", route, want)
				}
				if !strings.Contains(body, game.Title) {
					t.Errorf("%s lost the game title", route)
				}
			}
		})
	}
}
