package romcatalog

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// DefaultCacheTTL is how long a platform listing stays fresh on disk.
const DefaultCacheTTL = 24 * time.Hour

// platformCache is the on-disk cache of one platform listing.
type platformCache struct {
	Fetched time.Time `json:"fetched"`
	Games   []Game    `json:"games"`
}

// Catalog serves the game listings, caching them on disk so a restart does
// not re-download the source indexes.
type Catalog struct {
	registry *Registry
	dir      string
	ttl      time.Duration

	mu    sync.RWMutex
	cache map[string]*platformCache
}

// NewCatalog returns a catalog that caches listings under dir.
func NewCatalog(registry *Registry, dir string, ttl time.Duration) *Catalog {
	if ttl <= 0 {
		ttl = DefaultCacheTTL
	}
	return &Catalog{
		registry: registry,
		dir:      dir,
		ttl:      ttl,
		cache:    map[string]*platformCache{},
	}
}

// Games returns the games of a platform that match text.
func (c *Catalog) Games(ctx context.Context, platform, text string, offset, limit int) ([]Game, error) {
	listing, err := c.listing(ctx, platform)
	if err != nil {
		return nil, err
	}
	games := listing
	if text != "" {
		needle := strings.ToLower(text)
		filtered := make([]Game, 0, len(games))
		for _, g := range games {
			if strings.Contains(strings.ToLower(g.Title), needle) {
				filtered = append(filtered, g)
			}
		}
		games = filtered
	}
	return page(games, offset, limit), nil
}

// Count returns how many games a platform has.
func (c *Catalog) Count(ctx context.Context, platform string) (int, error) {
	listing, err := c.listing(ctx, platform)
	if err != nil {
		return 0, err
	}
	return len(listing), nil
}

// Game returns one game by its catalog ID.
func (c *Catalog) Game(ctx context.Context, id string) (Game, bool, error) {
	for _, p := range Platforms() {
		listing, err := c.listing(ctx, p.Slug)
		if err != nil {
			continue
		}
		for _, g := range listing {
			if g.ID == id {
				return g, true, nil
			}
		}
	}
	return Game{}, false, nil
}

// listing returns the cached listing of a platform, fetching it when it is
// missing or stale.
func (c *Catalog) listing(ctx context.Context, platform string) ([]Game, error) {
	c.mu.RLock()
	cached, ok := c.cache[platform]
	c.mu.RUnlock()
	if ok && time.Since(cached.Fetched) < c.ttl {
		return cached.Games, nil
	}
	if disk, err := c.readDisk(platform); err == nil && time.Since(disk.Fetched) < c.ttl {
		c.mu.Lock()
		c.cache[platform] = disk
		c.mu.Unlock()
		return disk.Games, nil
	}

	games, err := c.registry.Search(ctx, Query{Platform: platform})
	if err != nil {
		if ok {
			return cached.Games, nil
		}
		return nil, err
	}
	fresh := &platformCache{Fetched: time.Now(), Games: games}
	if p, ok := PlatformBySlug(platform); ok {
		for i := range fresh.Games {
			fresh.Games[i].Cover = p.CoverURL(fresh.Games[i].Title)
		}
	}
	c.mu.Lock()
	c.cache[platform] = fresh
	c.mu.Unlock()
	if err := c.writeDisk(platform, fresh); err != nil {
		return games, fmt.Errorf("write cache: %w", err)
	}
	return games, nil
}

func (c *Catalog) cachePath(platform string) string {
	return filepath.Join(c.dir, platform+".json")
}

func (c *Catalog) readDisk(platform string) (*platformCache, error) {
	data, err := os.ReadFile(c.cachePath(platform))
	if err != nil {
		return nil, err
	}
	var cached platformCache
	if err := json.Unmarshal(data, &cached); err != nil {
		return nil, err
	}
	return &cached, nil
}

func (c *Catalog) writeDisk(platform string, cached *platformCache) error {
	if err := os.MkdirAll(c.dir, 0o755); err != nil {
		return err
	}
	data, err := json.Marshal(cached)
	if err != nil {
		return err
	}
	tmp := c.cachePath(platform) + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, c.cachePath(platform))
}
