package romcatalog

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"strconv"
	"sync"
	"time"
)

// Job is one running or finished download.
type Job struct {
	ID         string    `json:"id"`
	GameID     string    `json:"game_id"`
	Title      string    `json:"title"`
	Status     string    `json:"status"`
	Downloaded int64     `json:"downloaded"`
	Total      int64     `json:"total"`
	Error      string    `json:"error,omitempty"`
	Path       string    `json:"path,omitempty"`
	Started    time.Time `json:"started"`
	Finished   time.Time `json:"finished,omitempty"`
}

// Jobs keeps the download jobs of the service.
type Jobs struct {
	mu   sync.Mutex
	jobs map[string]*Job
	seq  int
}

// NewJobs returns an empty job registry.
func NewJobs() *Jobs {
	return &Jobs{jobs: map[string]*Job{}}
}

// Add registers a job and returns it.
func (j *Jobs) Add(job *Job) *Job {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.seq++
	job.ID = strconv.Itoa(j.seq)
	job.Status = "queued"
	job.Started = time.Now()
	j.jobs[job.ID] = job
	return job
}

// Get returns one job.
func (j *Jobs) Get(id string) (Job, bool) {
	j.mu.Lock()
	defer j.mu.Unlock()
	job, ok := j.jobs[id]
	if !ok {
		return Job{}, false
	}
	return *job, true
}

// Update applies a change to a job.
func (j *Jobs) Update(id string, change func(*Job)) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if job, ok := j.jobs[id]; ok {
		change(job)
	}
}

// List returns every job, newest last.
func (j *Jobs) List() []Job {
	j.mu.Lock()
	defer j.mu.Unlock()
	out := make([]Job, 0, len(j.jobs))
	for _, job := range j.jobs {
		out = append(out, *job)
	}
	return out
}

// Server serves the catalog web interface and the JSON API.
type Server struct {
	catalog    *Catalog
	downloader *Downloader
	jobs       *Jobs
	log        *slog.Logger
	tmpl       *template.Template
}

// NewServer builds the HTTP handler.
func NewServer(catalog *Catalog, downloader *Downloader, jobs *Jobs, log *slog.Logger) (*Server, error) {
	tmpl, err := template.New("catalog").Funcs(templateFuncs).Parse(pageTemplate)
	if err != nil {
		return nil, err
	}
	return &Server{catalog: catalog, downloader: downloader, jobs: jobs, log: log, tmpl: tmpl}, nil
}

// Handler returns the routes of the service.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.handleHome)
	mux.HandleFunc("GET /platform/{slug}", s.handlePlatform)
	mux.HandleFunc("GET /game/{id}", s.handleGame)
	mux.HandleFunc("GET /api/platforms", s.handleAPIPlatforms)
	mux.HandleFunc("GET /api/games", s.handleAPIGames)
	mux.HandleFunc("GET /api/game", s.handleAPIGame)
	mux.HandleFunc("GET /api/jobs", s.handleAPIJobs)
	mux.HandleFunc("GET /api/job", s.handleAPIJob)
	mux.HandleFunc("POST /api/download", s.handleAPIDownload)
	return mux
}

type pageData struct {
	Title       string
	Platforms   []Platform
	Platform    Platform
	Games       []Game
	Cover       string
	Total       int
	Query       string
	Game        *Game
	Jobs        []Job
	Error       string
	Destination string
}

func (s *Server) render(w http.ResponseWriter, status int, data pageData) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if err := s.tmpl.Execute(w, data); err != nil {
		s.log.Error("render", "error", err)
	}
}

func (s *Server) handleHome(w http.ResponseWriter, r *http.Request) {
	data := pageData{Title: "ROM catalog", Platforms: Platforms()}
	for _, p := range data.Platforms {
		if count, err := s.catalog.Count(r.Context(), p.Slug); err == nil {
			data.Total += count
		}
	}
	s.render(w, http.StatusOK, data)
}

func (s *Server) handlePlatform(w http.ResponseWriter, r *http.Request) {
	slug := r.PathValue("slug")
	platform, ok := PlatformBySlug(slug)
	if !ok {
		s.render(w, http.StatusNotFound, pageData{Title: "Unknown platform", Error: "unknown platform " + slug})
		return
	}
	query := r.URL.Query().Get("q")
	destination, err := s.downloader.platformDir(platform)
	if err != nil {
		s.render(w, http.StatusInternalServerError, pageData{Title: platform.Name, Error: err.Error()})
		return
	}
	games, err := s.catalog.Games(r.Context(), platform.Slug, query, 0, 200)
	if err != nil {
		s.render(w, http.StatusBadGateway, pageData{Title: platform.Name, Platform: platform, Error: err.Error()})
		return
	}
	s.render(w, http.StatusOK, pageData{
		Title:       platform.Name,
		Platform:    platform,
		Games:       games,
		Query:       query,
		Total:       len(games),
		Jobs:        s.jobs.List(),
		Destination: destination,
	})
}

func (s *Server) handleGame(w http.ResponseWriter, r *http.Request) {
	id, err := decodeID(r.PathValue("id"))
	if err != nil {
		s.render(w, http.StatusBadRequest, pageData{Title: "Bad game", Error: err.Error()})
		return
	}
	game, ok, err := s.catalog.Game(r.Context(), id)
	if err != nil || !ok {
		s.render(w, http.StatusNotFound, pageData{Title: "Unknown game", Error: "game not found"})
		return
	}
	platform, _ := PlatformBySlug(game.Platform)
	destination, err := s.downloader.platformDir(platform)
	if err != nil {
		s.render(w, http.StatusInternalServerError, pageData{Title: game.Title, Error: err.Error()})
		return
	}
	s.render(w, http.StatusOK, pageData{
		Title:       game.Title,
		Platform:    platform,
		Game:        &game,
		Cover:       game.Cover,
		Jobs:        s.jobs.List(),
		Destination: destination,
	})
}

func (s *Server) handleAPIPlatforms(w http.ResponseWriter, r *http.Request) {
	type platformCount struct {
		Platform
		Count int `json:"count"`
	}
	out := []platformCount{}
	for _, p := range Platforms() {
		count, err := s.catalog.Count(r.Context(), p.Slug)
		if err != nil {
			continue
		}
		out = append(out, platformCount{Platform: p, Count: count})
	}
	writeJSON(w, http.StatusOK, map[string]any{"platforms": out})
}

func (s *Server) handleAPIGames(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	platform := query.Get("platform")
	text := query.Get("q")
	offset, _ := strconv.Atoi(query.Get("offset"))
	limit, _ := strconv.Atoi(query.Get("limit"))
	if limit <= 0 {
		limit = 50
	}
	games, err := s.catalog.Games(r.Context(), platform, text, offset, limit)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"games": games})
}

func (s *Server) handleAPIGame(w http.ResponseWriter, r *http.Request) {
	game, ok, err := s.catalog.Game(r.Context(), r.URL.Query().Get("id"))
	if err != nil || !ok {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "game not found"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"game": game})
}

func (s *Server) handleAPIJobs(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"jobs": s.jobs.List()})
}

func (s *Server) handleAPIJob(w http.ResponseWriter, r *http.Request) {
	job, ok := s.jobs.Get(r.URL.Query().Get("id"))
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "job not found"})
		return
	}
	writeJSON(w, http.StatusOK, job)
}

// handleAPIDownload starts the download of one game.
func (s *Server) handleAPIDownload(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	game, ok, err := s.catalog.Game(r.Context(), body.ID)
	if err != nil || !ok {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "game not found"})
		return
	}
	file, ok := game.Main()
	if !ok {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "game has no file"})
		return
	}
	platform, ok := PlatformBySlug(game.Platform)
	if !ok {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "unknown platform"})
		return
	}
	job := s.jobs.Add(&Job{GameID: game.ID, Title: game.Title, Total: file.Size})
	go s.runDownload(job.ID, game, file, platform)
	writeJSON(w, http.StatusAccepted, job)
}

func (s *Server) runDownload(id string, game Game, file File, platform Platform) {
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Hour)
	defer cancel()
	s.jobs.Update(id, func(j *Job) { j.Status = "running" })
	result, err := s.downloader.Download(ctx, DownloadRequest{
		Game:     game,
		File:     file,
		Platform: platform,
		OnProgress: func(downloaded, total int64) {
			s.jobs.Update(id, func(j *Job) {
				j.Downloaded = downloaded
				if total > 0 {
					j.Total = total
				}
			})
		},
	})
	if err != nil {
		s.log.Error("download", "game", game.Title, "error", err)
		s.jobs.Update(id, func(j *Job) {
			j.Status = "failed"
			j.Error = err.Error()
			j.Finished = time.Now()
		})
		return
	}
	s.jobs.Update(id, func(j *Job) {
		j.Status = "done"
		j.Path = result.Path
		j.Total = result.Size
		j.Finished = time.Now()
	})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("write json", "error", err)
	}
}

func encodeID(id string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(id))
}

func decodeID(encoded string) (string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(encoded)
	if err != nil {
		return "", fmt.Errorf("bad game id: %w", err)
	}
	return string(raw), nil
}
