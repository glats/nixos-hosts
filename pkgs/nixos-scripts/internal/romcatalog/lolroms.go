package romcatalog

import (
	"context"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"strings"
)

// LolRoms serves games from the lolroms listing, which publishes No-Intro
// style archives per vendor and console. The search is a plain HTML query
// with a hard cap of about sixty results, and every link is a direct file.
type LolRoms struct {
	HTTPClient *http.Client
	BaseURL    string
}

// NewLolRoms returns the lolroms source.
func NewLolRoms(client *http.Client) *LolRoms {
	if client == nil {
		client = http.DefaultClient
	}
	return &LolRoms{HTTPClient: client, BaseURL: "https://lolroms.com"}
}

// Name identifies the source.
func (l *LolRoms) Name() string { return "lolroms" }

// Platforms lists the platforms the source can serve.
func (l *LolRoms) Platforms() []string {
	out := make([]string, 0, len(lolRomsConsoles))
	for slug := range lolRomsConsoles {
		out = append(out, slug)
	}
	return out
}

// lolRomsConsoles maps a platform slug to the console folder names the source
// uses.
var lolRomsConsoles = map[string][]string{
	"nes":       {"Nintendo Entertainment System"},
	"snes":      {"Super Nintendo Entertainment System"},
	"gb":        {"Game Boy"},
	"gbc":       {"Game Boy Color"},
	"gba":       {"Game Boy Advance"},
	"genesis":   {"Sega Mega Drive - Genesis", "Sega Mega Drive", "Genesis"},
	"n64":       {"Nintendo 64"},
	"nds":       {"Nintendo DS"},
	"psx":       {"Sony PlayStation"},
	"ps2":       {"Sony PlayStation 2"},
	"psp":       {"Sony PlayStation Portable"},
	"saturn":    {"Sega Saturn"},
	"dc":        {"Sega Dreamcast"},
	"ngc":       {"Nintendo GameCube"},
	"wii":       {"Nintendo Wii"},
	"atari2600": {"Atari 2600"},
}

// lolRomsConsolePlatform returns the platform of a console folder name.
func lolRomsConsolePlatform(console string) (string, bool) {
	lowered := strings.ToLower(console)
	for slug, names := range lolRomsConsoles {
		for _, name := range names {
			if strings.EqualFold(lowered, name) {
				return slug, true
			}
		}
	}
	return "", false
}

// lolRomsLink matches the anchors of the listing rows.
var lolRomsLink = regexp.MustCompile(`<a[^>]+href="([^"]+)"[^>]*>([^<]*)</a>`)

// lolRomsArchive matches the file extensions the source publishes.
var lolRomsArchive = regexp.MustCompile(`(?i)\.(7z|chd|zip|7Z)$`)

// readAll reads a response body with a bounded size.
func readAll(resp *http.Response) ([]byte, error) {
	return io.ReadAll(io.LimitReader(resp.Body, 8<<20))
}

// Search returns the games that match the query.
func (l *LolRoms) Search(ctx context.Context, q Query) ([]Game, error) {
	if q.Text == "" {
		return nil, fmt.Errorf("lolroms: a search term is required")
	}
	endpoint := l.BaseURL + "/?q=" + url.QueryEscape(q.Text)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) romcatalog/1.0")
	req.Header.Set("Accept", "text/html")
	resp, err := l.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("lolroms: %s", resp.Status)
	}
	body, err := readAll(resp)
	if err != nil {
		return nil, err
	}

	seen := map[string]bool{}
	var games []Game
	for _, match := range lolRomsLink.FindAllStringSubmatch(string(body), -1) {
		href := html.UnescapeString(match[1])
		if !lolRomsArchive.MatchString(href) {
			continue
		}
		segments := strings.Split(strings.Trim(href, "/"), "/")
		if len(segments) < 3 {
			continue
		}
		console, err := url.PathUnescape(segments[len(segments)-2])
		if err != nil {
			continue
		}
		slug, ok := lolRomsConsolePlatform(console)
		if !ok || (q.Platform != "" && slug != q.Platform) {
			continue
		}
		name, err := url.PathUnescape(path.Base(segments[len(segments)-1]))
		if err != nil {
			continue
		}
		if seen[href] {
			continue
		}
		seen[href] = true
		games = append(games, Game{
			ID:       "lolroms:" + href,
			Source:   "lolroms",
			Platform: slug,
			Title:    cleanTitle(name),
			Region:   regionOf(name),
			PageURL:  l.BaseURL + href,
			Files: []File{{
				Name:    name,
				URL:     l.BaseURL + href,
				Archive: true,
			}},
		})
	}
	return page(games, q.Offset, q.Limit), nil
}
