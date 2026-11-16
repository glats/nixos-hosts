package romcatalog

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"strings"
	"sync"
	"time"
)

// DlArchive serves games from the dlarchive index, a JSON listing of a
// personal file host that groups ROMs by platform folder.
type DlArchive struct {
	HTTPClient *http.Client
	BaseURL    string
	// TTL is how long the index stays cached in memory.
	TTL time.Duration

	mu      sync.Mutex
	index   []dlArchiveItem
	fetched time.Time
}

// dlArchiveItem is one entry of the dlarchive index.
type dlArchiveItem struct {
	ID          string `json:"id"`
	Filename    string `json:"filename"`
	Size        int64  `json:"size"`
	Mime        string `json:"mime"`
	DownloadURL string `json:"download_url"`
	Folder      string `json:"folder"`
}

// NewDlArchive returns the dlarchive source.
func NewDlArchive(client *http.Client) *DlArchive {
	if client == nil {
		client = http.DefaultClient
	}
	return &DlArchive{
		HTTPClient: client,
		BaseURL:    "https://uptobox.dlarchive.my.id",
		TTL:        12 * time.Hour,
	}
}

// Name identifies the source.
func (d *DlArchive) Name() string { return "dlarchive" }

// Platforms lists the platforms the index folders cover.
func (d *DlArchive) Platforms() []string {
	out := make([]string, 0, len(dlArchiveFolders))
	for slug := range dlArchiveFolders {
		out = append(out, slug)
	}
	return out
}

// dlArchiveFolders maps a platform slug to the folder tokens that hold it.
var dlArchiveFolders = map[string][]string{
	"nes":     {"Nintendo_Nes", "Nintendo_Entertainment_System", "Nes"},
	"snes":    {"Super_Nintendo", "Super_Nintendo_Entertainment_System", "Snes"},
	"gb":      {"Gameboy", "Game_Boy"},
	"gbc":     {"Gameboy_Color", "Game_Boy_Color"},
	"gba":     {"Gameboy_Advance", "Game_Boy_Advance"},
	"genesis": {"Sega_Mega_Drive", "Mega_Drive", "Genesis", "Sega_Genesis"},
	"n64":     {"Nintendo_64", "Nintend_64"},
	"nds":     {"Nintendo_DS", "Nds", "Nintendo_DS_Lite"},
	"psx":     {"Playstation", "Playstation_1"},
	"ps2":     {"Playstation_2", "Ps2"},
	"psp":     {"Playstation_Portable", "Psp"},
	"switch":  {"Game_ROMS", "Nintendo_Switch", "Switch"},
}

// dlArchiveFolderPlatform returns the platform of a folder, by its last
// segment, and whether the folder holds a game at all.
func dlArchiveFolderPlatform(folder string) (string, bool) {
	segments := strings.Split(folder, "/")
	last := strings.ToLower(segments[len(segments)-1])
	for slug, tokens := range dlArchiveFolders {
		for _, token := range tokens {
			if strings.EqualFold(last, token) {
				return slug, true
			}
		}
	}
	return "", false
}

// Search returns the games of a platform that match the query.
func (d *DlArchive) Search(ctx context.Context, q Query) ([]Game, error) {
	index, err := d.items(ctx)
	if err != nil {
		return nil, err
	}
	needle := strings.ToLower(q.Text)

	var games []Game
	for _, item := range index {
		slug, ok := dlArchiveFolderPlatform(item.Folder)
		if !ok || (q.Platform != "" && slug != q.Platform) {
			continue
		}
		title := cleanTitle(item.Filename)
		if needle != "" && !strings.Contains(strings.ToLower(title), needle) {
			continue
		}
		games = append(games, Game{
			ID:       "dlarchive:" + item.ID,
			Source:   "dlarchive",
			Platform: slug,
			Title:    title,
			Region:   regionOf(title),
			Size:     item.Size,
			PageURL:  d.BaseURL + "/?id=" + url.QueryEscape(item.ID),
			Files: []File{{
				Name:    item.Filename,
				Size:    item.Size,
				URL:     item.DownloadURL,
				Archive: isArchive(item.Filename),
			}},
		})
	}
	return page(games, q.Offset, q.Limit), nil
}

// items returns the index, fetching it when it is missing or stale.
func (d *DlArchive) items(ctx context.Context) ([]dlArchiveItem, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.index != nil && time.Since(d.fetched) < d.TTL {
		return d.index, nil
	}

	var (
		items  []dlArchiveItem
		offset int
	)
	for {
		var page struct {
			OK    bool            `json:"ok"`
			Items []dlArchiveItem `json:"items"`
			Total int             `json:"total"`
		}
		endpoint := fmt.Sprintf("%s/files_api.php?action=list&limit=200&offset=%d", d.BaseURL, offset)
		if err := d.getJSON(ctx, endpoint, &page); err != nil {
			return nil, err
		}
		items = append(items, page.Items...)
		offset += len(page.Items)
		if len(page.Items) == 0 || offset >= page.Total {
			break
		}
	}
	d.index = items
	d.fetched = time.Now()
	return items, nil
}

// FileURL resolves the direct download URL of an item.
func (d *DlArchive) FileURL(ctx context.Context, id string) (string, error) {
	var answer struct {
		OK  bool   `json:"ok"`
		URL string `json:"url"`
	}
	endpoint := fmt.Sprintf("%s/files_api.php?action=file-url&id=%s", d.BaseURL, url.QueryEscape(id))
	if err := d.getJSON(ctx, endpoint, &answer); err != nil {
		return "", err
	}
	if !answer.OK || answer.URL == "" {
		return "", fmt.Errorf("dlarchive: no download URL for %s", id)
	}
	return answer.URL, nil
}

func (d *DlArchive) getJSON(ctx context.Context, endpoint string, target any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	resp, err := d.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("dlarchive: %s: %s", path.Base(endpoint), resp.Status)
	}
	return json.NewDecoder(resp.Body).Decode(target)
}
