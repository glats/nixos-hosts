package romcatalog

import (
	"context"
	"fmt"
	"sort"
)

// File is one downloadable artifact of a game.
type File struct {
	// Name is the file name as the source publishes it.
	Name string
	// Size is the size in bytes, zero when the source does not report it.
	Size int64
	// MD5 and SHA1 are the checksums the source publishes, when available.
	MD5  string
	SHA1 string
	// SHA256 is published by some sources that serve plain HTTP.
	SHA256 string
	// URL is the direct download URL.
	URL string
	// Archive reports whether the file is an archive that must be extracted
	// before the ROM inside it reaches the library.
	Archive bool
}

// Game is one entry of the catalog.
type Game struct {
	// ID is unique across sources and stable for the source's item.
	ID string
	// Source is the name of the source that produced the game.
	Source string
	// Platform is the RomM platform slug.
	Platform string
	// Title is the display title.
	Title string
	// Region is the region tag when the source reports one.
	Region string
	// Size is the size of the main file in bytes.
	Size int64
	// Cover is the cover image URL, empty when there is none.
	Cover string
	// Screenshots are additional images.
	Screenshots []string
	// PageURL is the human readable page of the game on the source.
	PageURL string
	// Files are the downloadable artifacts, the first one being the main file.
	Files []File
}

// Main returns the main file of the game.
func (g Game) Main() (File, bool) {
	if len(g.Files) == 0 {
		return File{}, false
	}
	return g.Files[0], true
}

// Query asks a source for games.
type Query struct {
	// Platform is the RomM platform slug, empty for every platform.
	Platform string
	// Text is the free text search, empty to list everything.
	Text string
	// Limit caps the number of results.
	Limit int
	// Offset skips the first results.
	Offset int
}

// Source is a place the catalog can search and download from.
type Source interface {
	// Name identifies the source in the catalog and in cache keys.
	Name() string
	// Platforms lists the platform slugs the source can serve. Empty means
	// every platform.
	Platforms() []string
	// Search returns the games matching the query.
	Search(ctx context.Context, q Query) ([]Game, error)
}

// Registry holds the enabled sources.
type Registry struct {
	sources []Source
}

// NewRegistry returns a registry with the given sources.
func NewRegistry(sources ...Source) *Registry {
	return &Registry{sources: sources}
}

// Names lists the source names in the registry.
func (r *Registry) Names() []string {
	out := make([]string, 0, len(r.sources))
	for _, s := range r.sources {
		out = append(out, s.Name())
	}
	sort.Strings(out)
	return out
}

// Search queries every source that serves the platform and merges the
// results, keeping the first occurrence of each game ID.
func (r *Registry) Search(ctx context.Context, q Query) ([]Game, error) {
	var (
		games []Game
		errs  []error
	)
	seen := map[string]bool{}
	for _, s := range r.sources {
		if !r.serves(s, q.Platform) {
			continue
		}
		found, err := s.Search(ctx, q)
		if err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", s.Name(), err))
			continue
		}
		for _, g := range found {
			if seen[g.ID] {
				continue
			}
			seen[g.ID] = true
			games = append(games, g)
		}
	}
	if len(games) == 0 && len(errs) > 0 {
		return nil, errs[0]
	}
	return games, nil
}

func (r *Registry) serves(s Source, platform string) bool {
	plats := s.Platforms()
	if len(plats) == 0 {
		return true
	}
	for _, p := range plats {
		if p == platform {
			return true
		}
	}
	return false
}
