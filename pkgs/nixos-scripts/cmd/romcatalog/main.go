// Command romcatalog serves a browsable catalog of ROM files and installs the
// selected games into the emulator library.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/glats/nixos-scripts/internal/romcatalog"
)

func main() {
	listen := flag.String("listen", "127.0.0.1:8082", "address the catalog listens on")
	library := flag.String("library", "/run/media/library/roms", "library root the ROMs are written to")
	cache := flag.String("cache", "/var/lib/romcatalog", "directory holding the cached catalog")
	sources := flag.String("sources", "archive.org,lolroms", "comma separated list of sources")
	ttl := flag.Duration("ttl", romcatalog.DefaultCacheTTL, "how long a catalog listing stays fresh")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo}))

	registry, err := buildRegistry(*sources)
	if err != nil {
		logger.Error("sources", "error", err)
		os.Exit(1)
	}
	logger.Info("sources ready", "names", registry.Names())

	catalog := romcatalog.NewCatalog(registry, *cache, *ttl)
	downloader := &romcatalog.Downloader{
		LibraryRoot: *library,
		HTTPClient:  &http.Client{},
	}
	jobs := romcatalog.NewJobs()

	server, err := romcatalog.NewServer(catalog, downloader, jobs, logger)
	if err != nil {
		logger.Error("server", "error", err)
		os.Exit(1)
	}

	httpServer := &http.Server{
		Addr:              *listen,
		Handler:           server.Handler(),
		ReadHeaderTimeout: 15 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("listening", "addr", *listen, "library", *library)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("listen", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdown); err != nil {
		logger.Error("shutdown", "error", err)
	}
}

// buildRegistry returns the enabled sources.
func buildRegistry(list string) (*romcatalog.Registry, error) {
	var sources []romcatalog.Source
	for _, name := range strings.Split(list, ",") {
		switch strings.TrimSpace(name) {
		case "":
			continue
		case "archive.org", "archiveorg":
			sources = append(sources, romcatalog.NewArchiveOrg(nil))
		case "dlarchive":
			sources = append(sources, romcatalog.NewDlArchive(nil))
		case "lolroms":
			sources = append(sources, romcatalog.NewLolRoms(nil))
		default:
			return nil, errors.New("unknown source: " + name)
		}
	}
	if len(sources) == 0 {
		return nil, errors.New("no sources enabled")
	}
	return romcatalog.NewRegistry(sources...), nil
}
