package romcatalog

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// ArchiveOrg serves games from Internet Archive items. The curated item list
// holds the per-game sets whose file listing is the catalog: every file in
// those items is one game with its own checksum and direct download URL.
type ArchiveOrg struct {
	HTTPClient *http.Client
	BaseURL    string
	// Sets maps a platform slug to the Internet Archive items that hold it.
	Sets map[string][]string
}

// NewArchiveOrg returns the Internet Archive source with the curated sets.
func NewArchiveOrg(client *http.Client) *ArchiveOrg {
	if client == nil {
		client = http.DefaultClient
	}
	return &ArchiveOrg{
		HTTPClient: client,
		BaseURL:    "https://archive.org",
		Sets: map[string][]string{
			"nes":     {"nes-collection-no-intro"},
			"snes":    {"nointro-snes"},
			"gb":      {"nointro-nintendo-gameboy"},
			"gbc":     {"ef_GBC_No-Intro"},
			"gba":     {"ef_gba_no-intro_2024-02-21"},
			"genesis": {"nointro.md"},
			"n64":     {"ef_nintendo_64_no-intro_2024-02-10"},
			"nds":     {"ni-n-ds-dec_202401"},
			"psx":     {"non-redump_sony_playstation"},
			"psp":     {"non-redump_sony_playstation_portable"},
			"arcade":  {"mame-merged"},
		},
	}
}

// Name identifies the source.
func (a *ArchiveOrg) Name() string { return "archive.org" }

// Platforms lists the platforms the curated sets cover.
func (a *ArchiveOrg) Platforms() []string {
	out := make([]string, 0, len(a.Sets))
	for slug := range a.Sets {
		out = append(out, slug)
	}
	sort.Strings(out)
	return out
}

// itemFile is one file of an Internet Archive item.
type itemFile struct {
	Name   string    `json:"name"`
	Size   sizeValue `json:"size"`
	Format string    `json:"format"`
	MD5    string    `json:"md5"`
	SHA1   string    `json:"sha1"`
	Source string    `json:"source"`
}

// sizeValue reads the file size, which Internet Archive publishes as a number
// for most files and as a string for some of them.
type sizeValue int64

// UnmarshalJSON decodes both the number and the string form.
func (s *sizeValue) UnmarshalJSON(data []byte) error {
	if len(data) == 0 || string(data) == "null" {
		return nil
	}
	if data[0] == '"' {
		var text string
		if err := json.Unmarshal(data, &text); err != nil {
			return err
		}
		if text == "" {
			return nil
		}
		number, err := strconv.ParseInt(text, 10, 64)
		if err != nil {
			return nil
		}
		*s = sizeValue(number)
		return nil
	}
	var number int64
	if err := json.Unmarshal(data, &number); err != nil {
		return err
	}
	*s = sizeValue(number)
	return nil
}

// itemMetadata is the response of the Internet Archive metadata endpoint.
type itemMetadata struct {
	Files []itemFile `json:"files"`
}

// Search returns the games of the curated sets that match the query.
func (a *ArchiveOrg) Search(ctx context.Context, q Query) ([]Game, error) {
	platforms := []string{q.Platform}
	if q.Platform == "" {
		platforms = a.Platforms()
	}

	var games []Game
	for _, slug := range platforms {
		for _, item := range a.Sets[slug] {
			found, err := a.gamesOfItem(ctx, slug, item)
			if err != nil {
				return nil, fmt.Errorf("archive.org %s: %w", item, err)
			}
			games = append(games, found...)
		}
	}

	if q.Text != "" {
		needle := strings.ToLower(q.Text)
		filtered := games[:0]
		for _, g := range games {
			if strings.Contains(strings.ToLower(g.Title), needle) {
				filtered = append(filtered, g)
			}
		}
		games = filtered
	}

	sort.Slice(games, func(i, j int) bool { return games[i].Title < games[j].Title })
	return page(games, q.Offset, q.Limit), nil
}

func (a *ArchiveOrg) gamesOfItem(ctx context.Context, slug, item string) ([]Game, error) {
	meta, err := a.metadata(ctx, item)
	if err != nil {
		return nil, err
	}
	base, ok := PlatformBySlug(slug)
	if !ok {
		return nil, fmt.Errorf("unknown platform %q", slug)
	}

	var games []Game
	for _, f := range meta.Files {
		if !isGameFile(f.Name) {
			continue
		}
		name := path.Base(f.Name)
		if !isArchive(name) && !base.Accepts(name) {
			continue
		}
		title := cleanTitle(name)
		games = append(games, Game{
			ID:       "archive.org:" + item + "/" + f.Name,
			Source:   "archive.org",
			Platform: slug,
			Title:    title,
			Region:   regionOf(title),
			Size:     int64(f.Size),
			PageURL:  a.BaseURL + "/details/" + item,
			Files: []File{{
				Name:    f.Name,
				Size:    int64(f.Size),
				MD5:     f.MD5,
				SHA1:    f.SHA1,
				URL:     a.BaseURL + "/download/" + item + "/" + url.PathEscape(f.Name),
				Archive: isArchive(name),
			}},
		})
	}
	return games, nil
}

func (a *ArchiveOrg) metadata(ctx context.Context, item string) (*itemMetadata, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.BaseURL+"/metadata/"+url.PathEscape(item), nil)
	if err != nil {
		return nil, err
	}
	resp, err := a.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("metadata %s: %s", item, resp.Status)
	}
	var meta itemMetadata
	if err := json.NewDecoder(resp.Body).Decode(&meta); err != nil {
		return nil, fmt.Errorf("metadata %s: %w", item, err)
	}
	return &meta, nil
}

// archiveExtensions are the container formats the sources publish.
var archiveExtensions = []string{".zip", ".7z", ".rar"}

// romExtensions are the file extensions that hold a ROM.
var romExtensions = []string{
	".nes", ".fds", ".unf", ".unif", ".sfc", ".smc", ".smd", ".fig", ".swc",
	".gb", ".gbc", ".gba", ".nds", ".dsi", ".n64", ".z64", ".v64", ".u1", ".ndd",
	".md", ".gen", ".bin", ".smd", ".iso", ".chd", ".cue", ".pbp", ".gcm", ".rvz",
	".wbfs", ".3ds", ".cia", ".cci", ".a26", ".lnx", ".lyx", ".vpl", ".nsp", ".xci",
}

func isArchive(name string) bool {
	lower := strings.ToLower(name)
	for _, ext := range archiveExtensions {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}

// isGameFile reports whether a file of an item holds a game. Firmware and
// BIOS collections are not games.
func isGameFile(name string) bool {
	lower := strings.ToLower(name)
	for _, part := range strings.Split(lower, "/") {
		if part == "bios" || part == "firmware" || part == "system" {
			return false
		}
	}
	for _, ext := range archiveExtensions {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	for _, ext := range romExtensions {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}

var titleNoise = regexp.MustCompile(`(?i)^(no-intro\s*-\s*|redump\s*-\s*|mame\s*-\s*)`)

// cleanTitle turns a published file name into a readable game title.
func cleanTitle(name string) string {
	base := path.Base(name)
	for _, ext := range archiveExtensions {
		if strings.HasSuffix(strings.ToLower(base), ext) {
			base = base[:len(base)-len(ext)]
			break
		}
	}
	base = titleNoise.ReplaceAllString(base, "")
	base = strings.ReplaceAll(base, "'", "")
	base = strings.ReplaceAll(base, "_", " ")
	base = strings.TrimSpace(base)
	return base
}

// regionOf reads the region tag of a No-Intro or Redump title.
func regionOf(title string) string {
	lower := strings.ToLower(title)
	for _, region := range []string{
		"world", "usa", "europe", "japan", "asia", "australia", "brazil", "korea", "china",
	} {
		if strings.Contains(lower, "("+region+")") || strings.Contains(lower, "("+region[:3]) {
			return region
		}
	}
	return ""
}

// page returns the requested slice of results.
func page(games []Game, offset, limit int) []Game {
	if offset < 0 {
		offset = 0
	}
	if offset >= len(games) {
		return nil
	}
	games = games[offset:]
	if limit > 0 && len(games) > limit {
		games = games[:limit]
	}
	return games
}
