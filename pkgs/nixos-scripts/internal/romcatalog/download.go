package romcatalog

import (
	"context"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"hash"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"unicode"
	"unicode/utf8"
)

const maxBaseNameBytes = 120

// DownloadRequest describes one download.
type DownloadRequest struct {
	Game       Game
	File       File
	Platform   Platform
	OnProgress func(downloaded, total int64)
}

// DownloadResult reports what was installed.
type DownloadResult struct {
	Path      string // final path of the ROM inside the library
	Size      int64
	Skipped   bool // true when the ROM was already present
	Extracted bool // true when the downloaded file was an archive
}

// Downloader installs downloads under a library root.
type Downloader struct {
	LibraryRoot  string // e.g. /run/media/library/roms
	HTTPClient   *http.Client
	SevenZipPath string // path to the 7z binary, defaults to "7z"
}

// Download fetches req.File and installs the ROM it holds under the library root.
func (d *Downloader) Download(ctx context.Context, req DownloadRequest) (DownloadResult, error) {
	if err := ctx.Err(); err != nil {
		return DownloadResult{}, err
	}
	if d.LibraryRoot == "" {
		return DownloadResult{}, errors.New("romcatalog: library root is not set")
	}
	if req.File.URL == "" {
		return DownloadResult{}, fmt.Errorf("romcatalog: %s has no download URL", req.File.Name)
	}
	base, ext, err := romFileParts(req.File.Name)
	if err != nil {
		return DownloadResult{}, err
	}
	archive := isArchiveExt(ext)
	if req.File.Archive && !archive {
		return DownloadResult{}, fmt.Errorf("romcatalog: unsupported archive format for %s", req.File.Name)
	}
	if !archive && ext == "" {
		if len(req.Platform.Extensions) == 0 {
			return DownloadResult{}, fmt.Errorf("romcatalog: %s has no extension to install under", req.File.Name)
		}
		ext = req.Platform.Extensions[0]
	}
	dir, err := d.platformDir(req.Platform)
	if err != nil {
		return DownloadResult{}, err
	}
	target, err := d.targetPath(dir, base, ext)
	if err != nil {
		return DownloadResult{}, err
	}
	if archive {
		if err := requireExtractor(ext, d.sevenZipBinary()); err != nil {
			return DownloadResult{}, err
		}
	} else if skipPresent(target, req.File.Size) {
		return DownloadResult{Path: target, Size: req.File.Size, Skipped: true}, nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return DownloadResult{}, fmt.Errorf("romcatalog: create %s: %w", dir, err)
	}
	part := target + ".part"
	if err := fetch(ctx, d.client(), req.File, part, progressReporter(req)); err != nil {
		return DownloadResult{}, err
	}
	if err := ctx.Err(); err != nil {
		return DownloadResult{}, err
	}
	if err := verifyChecksum(part, req.File); err != nil {
		os.Remove(part)
		return DownloadResult{}, err
	}
	if archive {
		return d.installArchive(ctx, dir, base, ext, part, req.Platform.Extensions)
	}
	if err := install(part, tempPath(dir, filepath.Base(target)), target); err != nil {
		return DownloadResult{}, err
	}
	return installedResult(target, false)
}

func (d *Downloader) installArchive(ctx context.Context, dir, base, archiveExt, archivePath string, exts []string) (DownloadResult, error) {
	workDir, err := os.MkdirTemp(dir, ".extract-")
	if err != nil {
		os.Remove(archivePath)
		return DownloadResult{}, fmt.Errorf("romcatalog: create extraction directory: %w", err)
	}
	defer os.RemoveAll(workDir)

	romPath, romExt, err := extractROM(ctx, d.sevenZipBinary(), archiveExt, archivePath, workDir, exts)
	if err != nil {
		os.Remove(archivePath)
		return DownloadResult{}, err
	}
	target, err := d.targetPath(dir, base, romExt)
	if err != nil {
		return DownloadResult{}, err
	}
	if err := install(romPath, tempPath(dir, base+romExt), target); err != nil {
		return DownloadResult{}, err
	}
	os.Remove(archivePath)
	return installedResult(target, true)
}

func (d *Downloader) platformDir(p Platform) (string, error) {
	name := p.Dir
	if name == "" {
		name = p.Slug
	}
	if name == "" {
		return "", errors.New("romcatalog: platform has no library folder")
	}
	return filepath.Join(d.LibraryRoot, name), nil
}

func (d *Downloader) targetPath(dir, base, ext string) (string, error) {
	root := filepath.Clean(d.LibraryRoot)
	target := filepath.Join(dir, base+ext)
	if !strings.HasPrefix(target, root+string(filepath.Separator)) {
		return "", fmt.Errorf("romcatalog: target %q escapes library root %q", target, root)
	}
	return target, nil
}

func (d *Downloader) client() *http.Client {
	if d.HTTPClient != nil {
		return d.HTTPClient
	}
	return http.DefaultClient
}

func (d *Downloader) sevenZipBinary() string {
	if d.SevenZipPath != "" {
		return d.SevenZipPath
	}
	return "7z"
}

func progressReporter(req DownloadRequest) func(downloaded, total int64) {
	if req.OnProgress != nil {
		return req.OnProgress
	}
	return func(int64, int64) {}
}

func romFileParts(fileName string) (string, string, error) {
	name := sanitizeName(lastPathElement(fileName))
	ext := filepath.Ext(name)
	base := strings.Trim(truncateBytes(strings.TrimSuffix(name, ext), maxBaseNameBytes), ". ")
	if base == "" {
		return "", "", fmt.Errorf("romcatalog: %q has no usable ROM name", fileName)
	}
	return base, ext, nil
}

func lastPathElement(s string) string {
	return s[strings.LastIndexAny(s, `/\`)+1:]
}

func sanitizeName(s string) string {
	var b strings.Builder
	for _, r := range s {
		if unicode.IsControl(r) && !unicode.IsSpace(r) {
			continue
		}
		b.WriteRune(r)
	}
	return strings.Trim(strings.Join(strings.Fields(b.String()), " "), ". ")
}

func truncateBytes(s string, limit int) string {
	if len(s) <= limit {
		return s
	}
	cut := limit
	for cut > 0 && !utf8.RuneStart(s[cut]) {
		cut--
	}
	return s[:cut]
}

func isArchiveExt(ext string) bool {
	lower := strings.ToLower(ext)
	return lower == ".zip" || lower == ".7z"
}

func tempPath(dir, name string) string {
	return filepath.Join(dir, "."+name+".tmp")
}

func skipPresent(target string, size int64) bool {
	if size <= 0 {
		return false
	}
	info, err := os.Stat(target)
	return err == nil && info.Mode().IsRegular() && info.Size() == size
}

func installedResult(path string, extracted bool) (DownloadResult, error) {
	info, err := os.Stat(path)
	if err != nil {
		return DownloadResult{}, fmt.Errorf("romcatalog: stat installed ROM: %w", err)
	}
	return DownloadResult{Path: path, Size: info.Size(), Extracted: extracted}, nil
}

func fetch(ctx context.Context, client *http.Client, file File, part string, progress func(downloaded, total int64)) error {
	var offset int64
	if info, err := os.Stat(part); err == nil {
		offset = info.Size()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, file.URL, nil)
	if err != nil {
		return fmt.Errorf("romcatalog: build request for %s: %w", file.Name, err)
	}
	if offset > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", offset))
	}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("romcatalog: download %s: %w", file.Name, err)
	}
	defer resp.Body.Close()

	resuming := offset > 0 && resp.StatusCode == http.StatusPartialContent
	if !resuming && resp.StatusCode != http.StatusOK {
		if offset > 0 && resp.StatusCode == http.StatusRequestedRangeNotSatisfiable {
			os.Remove(part)
			return fmt.Errorf("romcatalog: download %s: partial file no longer matches the source, discarded; retry", file.Name)
		}
		return fmt.Errorf("romcatalog: download %s: unexpected HTTP status %s", file.Name, resp.Status)
	}

	flags := os.O_WRONLY | os.O_CREATE | os.O_TRUNC
	var done int64
	if resuming {
		flags = os.O_WRONLY | os.O_CREATE | os.O_APPEND
		done = offset
	}
	out, err := os.OpenFile(part, flags, 0o644)
	if err != nil {
		return fmt.Errorf("romcatalog: open %s: %w", part, err)
	}
	w := &progressWriter{w: out, downloaded: done, total: max(file.Size, 0), report: progress}
	_, copyErr := io.Copy(w, resp.Body)
	if copyErr == nil {
		copyErr = out.Sync()
	}
	if closeErr := out.Close(); copyErr == nil {
		copyErr = closeErr
	}
	if copyErr != nil {
		return fmt.Errorf("romcatalog: download %s: %w", file.Name, copyErr)
	}
	return nil
}

type progressWriter struct {
	w          io.Writer
	downloaded int64
	total      int64
	report     func(downloaded, total int64)
}

func (p *progressWriter) Write(b []byte) (int, error) {
	n, err := p.w.Write(b)
	p.downloaded += int64(n)
	p.report(p.downloaded, p.total)
	return n, err
}

func verifyChecksum(path string, file File) error {
	if file.MD5 != "" {
		if err := checkDigest(path, md5.New(), "md5", file.MD5); err != nil {
			return err
		}
	}
	if file.SHA1 != "" {
		if err := checkDigest(path, sha1.New(), "sha1", file.SHA1); err != nil {
			return err
		}
	}
	if file.SHA256 != "" {
		return checkDigest(path, sha256.New(), "sha256", file.SHA256)
	}
	return nil
}

func checkDigest(path string, h hash.Hash, algorithm, expected string) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("romcatalog: open %s for checksum: %w", path, err)
	}
	defer f.Close()
	if _, err := io.Copy(h, f); err != nil {
		return fmt.Errorf("romcatalog: checksum %s: %w", path, err)
	}
	actual := hex.EncodeToString(h.Sum(nil))
	if !strings.EqualFold(actual, expected) {
		return fmt.Errorf("romcatalog: %s checksum mismatch: expected %s, got %s", algorithm, expected, actual)
	}
	return nil
}

func install(src, tmp, target string) error {
	if err := os.Rename(src, tmp); err != nil {
		return fmt.Errorf("romcatalog: stage %s: %w", target, err)
	}
	if err := os.Rename(tmp, target); err != nil {
		os.Remove(tmp)
		return fmt.Errorf("romcatalog: install %s: %w", target, err)
	}
	return nil
}
