package romcatalog

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/md5"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

var snesPlatform = Platform{
	Slug:       "snes",
	Dir:        "snes",
	Name:       "Super Nintendo Entertainment System",
	Extensions: []string{".sfc", ".smc", ".gba"},
}

type zipEntry struct {
	name string
	body string
}

func newDownloader(t *testing.T) (*Downloader, string) {
	t.Helper()
	root := t.TempDir()
	return &Downloader{LibraryRoot: root}, root
}

func serve(t *testing.T, handler http.HandlerFunc) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return srv
}

func servedBody(body []byte) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Write(body)
	}
}

func zipArchive(t *testing.T, entries []zipEntry) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for _, e := range entries {
		f, err := w.Create(e.name)
		if err != nil {
			t.Fatalf("create zip entry %s: %v", e.name, err)
		}
		if _, err := f.Write([]byte(e.body)); err != nil {
			t.Fatalf("write zip entry %s: %v", e.name, err)
		}
	}
	if err := w.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	return buf.Bytes()
}

func readFile(t *testing.T, path string) []byte {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return data
}

func assertAbsent(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("%s: expected absent, stat error = %v", path, err)
	}
}

func installedFiles(t *testing.T, root string) []string {
	t.Helper()
	var files []string
	err := filepath.WalkDir(root, func(p string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !entry.IsDir() {
			files = append(files, p)
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk %s: %v", root, err)
	}
	return files
}

func TestRomFileParts(t *testing.T) {
	tests := []struct {
		name    string
		file    string
		base    string
		ext     string
		wantErr bool
	}{
		{name: "keeps source extension", file: "Chrono Trigger (USA).sfc", base: "Chrono Trigger (USA)", ext: ".sfc"},
		{name: "strips directories and traversal", file: "../../etc/passwd", base: "passwd"},
		{name: "archive extension is part of the name", file: "Bundle.zip", base: "Bundle", ext: ".zip"},
		{name: "control characters removed and spacing collapsed", file: "  Spaced\t\tName\x00 .gba ", base: "Spaced Name", ext: ".gba"},
		{name: "base name capped at 120 bytes", file: strings.Repeat("a", 200) + ".nes", base: strings.Repeat("a", 120), ext: ".nes"},
		{name: "bare dot-dot rejected", file: "..", wantErr: true},
		{name: "empty name rejected", file: "", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			base, ext, err := romFileParts(tt.file)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("romFileParts(%q) error = nil, want error", tt.file)
				}
				return
			}
			if err != nil {
				t.Fatalf("romFileParts(%q) error = %v", tt.file, err)
			}
			if base != tt.base || ext != tt.ext {
				t.Errorf("romFileParts(%q) = (%q, %q), want (%q, %q)", tt.file, base, ext, tt.base, tt.ext)
			}
		})
	}
}

func TestDownloadWritesPlainROM(t *testing.T) {
	body := []byte("0123456789abcdef")
	srv := serve(t, servedBody(body))
	d, root := newDownloader(t)

	var lastDownloaded, lastTotal int64
	res, err := d.Download(context.Background(), DownloadRequest{
		Platform: snesPlatform,
		File:     File{Name: "Chrono Trigger (USA).sfc", Size: int64(len(body)), URL: srv.URL},
		OnProgress: func(downloaded, total int64) {
			lastDownloaded, lastTotal = downloaded, total
		},
	})
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	want := filepath.Join(root, "snes", "Chrono Trigger (USA).sfc")
	if res.Path != want {
		t.Errorf("Path = %q, want %q", res.Path, want)
	}
	if res.Size != int64(len(body)) || res.Skipped || res.Extracted {
		t.Errorf("result = %+v, want size %d, not skipped, not extracted", res, len(body))
	}
	if got := readFile(t, want); !bytes.Equal(got, body) {
		t.Errorf("installed bytes = %q, want %q", got, body)
	}
	if lastDownloaded != int64(len(body)) || lastTotal != int64(len(body)) {
		t.Errorf("last progress = (%d, %d), want (%d, %d)", lastDownloaded, lastTotal, len(body), len(body))
	}
	assertAbsent(t, want+".part")
}

func TestDownloadResumesPartFile(t *testing.T) {
	body := []byte("0123456789abcdef")
	ranges := make(chan string, 1)
	srv := serve(t, func(w http.ResponseWriter, r *http.Request) {
		select {
		case ranges <- r.Header.Get("Range"):
		default:
		}
		if r.Header.Get("Range") != "bytes=4-" {
			w.Write(body)
			return
		}
		w.Header().Set("Content-Range", "bytes 4-15/16")
		w.WriteHeader(http.StatusPartialContent)
		w.Write(body[4:])
	})
	d, root := newDownloader(t)
	dir := filepath.Join(root, "snes")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "Game.sfc.part"), body[:4], 0o644); err != nil {
		t.Fatal(err)
	}

	res, err := d.Download(context.Background(), DownloadRequest{
		Platform: snesPlatform,
		File:     File{Name: "Game.sfc", Size: int64(len(body)), URL: srv.URL},
	})
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	select {
	case got := <-ranges:
		if got != "bytes=4-" {
			t.Errorf("Range header = %q, want %q", got, "bytes=4-")
		}
	default:
		t.Fatal("server was not contacted")
	}
	if got := readFile(t, res.Path); !bytes.Equal(got, body) {
		t.Errorf("resumed bytes = %q, want %q", got, body)
	}
	assertAbsent(t, filepath.Join(dir, "Game.sfc.part"))
}

func TestDownloadChecksum(t *testing.T) {
	body := []byte("checksum-me")
	md5Sum := md5.Sum(body)
	sha1Sum := sha1.Sum(body)
	zeroMD5 := strings.Repeat("0", 32)

	tests := []struct {
		name    string
		md5     string
		sha1    string
		wantErr bool
	}{
		{name: "upper-case MD5 matches", md5: strings.ToUpper(hex.EncodeToString(md5Sum[:]))},
		{name: "SHA1 matches", sha1: hex.EncodeToString(sha1Sum[:])},
		{name: "MD5 mismatch installs nothing", md5: zeroMD5, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := serve(t, servedBody(body))
			d, root := newDownloader(t)
			file := File{Name: "Game.sfc", Size: int64(len(body)), URL: srv.URL, MD5: tt.md5, SHA1: tt.sha1}

			res, err := d.Download(context.Background(), DownloadRequest{Platform: snesPlatform, File: file})
			target := filepath.Join(root, "snes", "Game.sfc")
			if !tt.wantErr {
				if err != nil {
					t.Fatalf("Download() error = %v", err)
				}
				if got := readFile(t, res.Path); !bytes.Equal(got, body) {
					t.Errorf("installed bytes = %q, want %q", got, body)
				}
				return
			}
			if err == nil {
				t.Fatal("Download() error = nil, want checksum mismatch")
			}
			actual := hex.EncodeToString(md5Sum[:])
			if !strings.Contains(err.Error(), zeroMD5) || !strings.Contains(err.Error(), actual) {
				t.Errorf("error %q does not name expected %s and actual %s", err, zeroMD5, actual)
			}
			assertAbsent(t, target)
			assertAbsent(t, target+".part")
		})
	}
}

func TestDownloadNeutralizesTraversal(t *testing.T) {
	body := []byte("passwd-rom")
	srv := serve(t, servedBody(body))
	d, root := newDownloader(t)

	res, err := d.Download(context.Background(), DownloadRequest{
		Platform: snesPlatform,
		File:     File{Name: "../../etc/passwd", Size: int64(len(body)), URL: srv.URL},
	})
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	want := filepath.Join(root, "snes", "passwd.sfc")
	if res.Path != want {
		t.Errorf("Path = %q, want %q", res.Path, want)
	}
	if !strings.HasPrefix(res.Path, root+string(filepath.Separator)) {
		t.Errorf("Path %q escapes library root %q", res.Path, root)
	}
	if got := readFile(t, want); !bytes.Equal(got, body) {
		t.Errorf("installed bytes = %q, want %q", got, body)
	}
}

func TestDownloadSkipsPresentROM(t *testing.T) {
	var hits atomic.Int32
	srv := serve(t, func(w http.ResponseWriter, _ *http.Request) {
		hits.Add(1)
		w.Write([]byte("0123456789"))
	})
	d, root := newDownloader(t)
	dir := filepath.Join(root, "snes")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(dir, "Game.sfc")
	local := []byte("abcdefghij")
	if err := os.WriteFile(target, local, 0o644); err != nil {
		t.Fatal(err)
	}

	res, err := d.Download(context.Background(), DownloadRequest{
		Platform: snesPlatform,
		File:     File{Name: "Game.sfc", Size: int64(len(local)), URL: srv.URL},
	})
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	if !res.Skipped || res.Path != target {
		t.Errorf("result = %+v, want skipped at %s", res, target)
	}
	if n := hits.Load(); n != 0 {
		t.Errorf("server hits = %d, want 0", n)
	}
	if got := readFile(t, target); !bytes.Equal(got, local) {
		t.Errorf("existing ROM changed to %q", got)
	}
}

func TestDownloadExtractsZipROM(t *testing.T) {
	archive := zipArchive(t, []zipEntry{
		{name: "notes.txt", body: "read me"},
		{name: "disc/alt.sfc", body: "alternate"},
		{name: "Game.sfc", body: "game-data"},
	})
	srv := serve(t, servedBody(archive))
	d, root := newDownloader(t)

	res, err := d.Download(context.Background(), DownloadRequest{
		Platform: snesPlatform,
		File:     File{Name: "Bundle.zip", Size: int64(len(archive)), URL: srv.URL, Archive: true},
	})
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	want := filepath.Join(root, "snes", "Bundle.sfc")
	if res.Path != want || !res.Extracted {
		t.Errorf("result = %+v, want extracted ROM at %s", res, want)
	}
	if got := readFile(t, want); string(got) != "game-data" {
		t.Errorf("installed bytes = %q, want the root-level ROM", got)
	}
	files := installedFiles(t, root)
	if len(files) != 1 || files[0] != want {
		t.Errorf("library files = %v, want only %s", files, want)
	}
}

func TestDownloadExtractsSevenZipROM(t *testing.T) {
	if _, err := exec.LookPath("sh"); err != nil {
		t.Skip("sh not available to stand in for 7z")
	}
	bin := filepath.Join(t.TempDir(), "7z")
	script := "#!/bin/sh\n" +
		"for arg in \"$@\"; do\n  case \"$arg\" in\n    -o*) dest=\"${arg#-o}\" ;;\n  esac\ndone\n" +
		"mkdir -p \"$dest/extras\"\nprintf 'seven-zip-rom' > \"$dest/extras/Game.gba\"\n"
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	srv := serve(t, servedBody([]byte("not-a-real-7z")))
	d, root := newDownloader(t)
	d.SevenZipPath = bin

	res, err := d.Download(context.Background(), DownloadRequest{
		Platform: snesPlatform,
		File:     File{Name: "Bundle.7z", URL: srv.URL, Archive: true},
	})
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	want := filepath.Join(root, "snes", "Bundle.gba")
	if res.Path != want || !res.Extracted {
		t.Errorf("result = %+v, want extracted ROM at %s", res, want)
	}
	if got := readFile(t, want); string(got) != "seven-zip-rom" {
		t.Errorf("installed bytes = %q", got)
	}
	files := installedFiles(t, root)
	if len(files) != 1 {
		t.Errorf("library files = %v, want only the ROM", files)
	}
}

func TestDownloadFailureInstallsNothing(t *testing.T) {
	tests := []struct {
		name     string
		cancel   bool
		sevenZip func(t *testing.T) string
		file     func(url string) File
		wantErr  string
	}{
		{
			name:    "server error",
			file:    func(url string) File { return File{Name: "Game.sfc", URL: url} },
			wantErr: "500",
		},
		{
			name:    "canceled context",
			cancel:  true,
			file:    func(url string) File { return File{Name: "Game.sfc", URL: url} },
			wantErr: "context canceled",
		},
		{
			name: "missing 7z binary",
			sevenZip: func(t *testing.T) string {
				return filepath.Join(t.TempDir(), "absent-7z")
			},
			file:    func(url string) File { return File{Name: "Bundle.7z", URL: url, Archive: true} },
			wantErr: "7z",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := serve(t, func(w http.ResponseWriter, _ *http.Request) {
				http.Error(w, "boom", http.StatusInternalServerError)
			})
			d, root := newDownloader(t)
			if tt.sevenZip != nil {
				d.SevenZipPath = tt.sevenZip(t)
			}
			ctx := context.Background()
			if tt.cancel {
				var cancel context.CancelFunc
				ctx, cancel = context.WithCancel(ctx)
				cancel()
			}

			_, err := d.Download(ctx, DownloadRequest{Platform: snesPlatform, File: tt.file(srv.URL)})
			if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
				t.Fatalf("Download() error = %v, want one containing %q", err, tt.wantErr)
			}
			if files := installedFiles(t, root); len(files) != 0 {
				t.Errorf("library files = %v, want none", files)
			}
		})
	}
}

func TestDownloadRejectsEscapingPlatformDir(t *testing.T) {
	d, root := newDownloader(t)
	escaping := Platform{Slug: "snes", Dir: "../escape", Extensions: []string{".sfc"}}

	_, err := d.Download(context.Background(), DownloadRequest{
		Platform: escaping,
		File:     File{Name: "Game.sfc", URL: "http://unused.invalid/game"},
	})
	if err == nil {
		t.Fatal("Download() error = nil, want escape rejected")
	}
	if files := installedFiles(t, root); len(files) != 0 {
		t.Errorf("library files = %v, want none", files)
	}
}
