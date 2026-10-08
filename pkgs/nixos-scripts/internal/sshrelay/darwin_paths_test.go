package sshrelay

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"testing"
)

type directoryMetadata struct {
	os.FileInfo
	mode     os.FileMode
	uid, gid uint32
}

func (m directoryMetadata) Mode() os.FileMode { return m.mode }
func (m directoryMetadata) IsDir() bool       { return m.mode.IsDir() }
func (m directoryMetadata) Sys() any          { return &syscall.Stat_t{Uid: m.uid, Gid: m.gid} }

func TestDarwinRunDirectoryTrustBoundary(t *testing.T) {
	for _, tt := range []struct {
		name, path, platform string
		uid, gid             uint32
		mode                 os.FileMode
		want                 bool
	}{
		{"native system run", "/private/var/run", "darwin", 0, 1, os.ModeDir | 0775, true},
		{"Linux unchanged", "/private/var/run", "linux", 0, 1, os.ModeDir | 0775, false},
		{"other Darwin directory", "/private/var/other", "darwin", 0, 1, os.ModeDir | 0775, false},
		{"alias not canonical", "/var/run", "darwin", 0, 1, os.ModeDir | 0775, false},
		{"wrong owner", "/private/var/run", "darwin", 501, 1, os.ModeDir | 0775, false},
		{"wrong group", "/private/var/run", "darwin", 0, 80, os.ModeDir | 0775, false},
		{"world writable", "/private/var/run", "darwin", 0, 1, os.ModeDir | 0777, false},
		{"different writable mode", "/private/var/run", "darwin", 0, 1, os.ModeDir | 0770, false},
		{"symlink", "/private/var/run", "darwin", 0, 1, os.ModeSymlink | 0775, false},
		{"extra special bits", "/private/var/run", "darwin", 0, 1, os.ModeDir | os.ModeSetgid | 0775, false},
	} {
		t.Run(tt.name, func(t *testing.T) {
			info := directoryMetadata{mode: tt.mode, uid: tt.uid, gid: tt.gid}
			if got := trustedDirectoryForPlatform(tt.path, info, 501, tt.platform); got != tt.want {
				t.Fatalf("trusted = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestStageCredentialsCreatesPrivateParents(t *testing.T) {
	launcher := &fakeLauncher{}
	c, oldStage, _ := newCredentialController(t, launcher, false)
	dir := filepath.Join(filepath.Dir(filepath.Dir(oldStage)), "nixos", "ssh-relay")
	c.config.CredentialStagePath = filepath.Join(dir, "authorization")
	c.config.HeadersPath = filepath.Join(dir, "headers")
	if err := c.StageCredentials(context.Background(), oldStage); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{filepath.Dir(dir), dir, c.config.CredentialStagePath} {
		info, err := os.Lstat(path)
		if err != nil {
			t.Fatal(err)
		}
		want := os.FileMode(0700)
		if path == c.config.CredentialStagePath {
			want = 0600
		}
		if info.Mode().Perm() != want || ownerUID(info) != uint32(os.Getuid()) || info.Mode()&os.ModeSymlink != 0 {
			t.Fatalf("unsafe created metadata for %s: %v", path, info.Mode())
		}
	}
	if len(launcher.calls()) != 0 {
		t.Fatal("staging called launchctl")
	}
	if _, err := os.Lstat(c.config.HeadersPath); !os.IsNotExist(err) {
		t.Fatal("staging changed live headers")
	}
	st, err := c.readState()
	if err != nil || st.Enabled || st.Generation != 1 {
		t.Fatalf("staging changed intent: %+v, %v", st, err)
	}
	if err := c.ApplyCredentials(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := ValidateHeaderFile(c.config.HeadersPath); err != nil {
		t.Fatal(err)
	}
}

func TestStageCredentialsInvalidSourceDoesNotCreateParents(t *testing.T) {
	c, source, _ := newCredentialController(t, &fakeLauncher{}, false)
	parent := filepath.Join(filepath.Dir(filepath.Dir(source)), "nixos")
	c.config.CredentialStagePath = filepath.Join(parent, "ssh-relay", "authorization")
	if err := os.Chmod(source, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := c.StageCredentials(context.Background(), source); err == nil {
		t.Fatal("unsafe source accepted")
	}
	if _, err := os.Lstat(parent); !os.IsNotExist(err) {
		t.Fatalf("invalid source created credential parents: %v", err)
	}
}

func TestStageCredentialsRejectsUnsafeParentsWithoutRepair(t *testing.T) {
	for _, kind := range []string{"writable ancestor", "symlink ancestor", "nonprivate final directory"} {
		t.Run(kind, func(t *testing.T) {
			c, source, _ := newCredentialController(t, &fakeLauncher{}, false)
			parent := filepath.Join(filepath.Dir(filepath.Dir(source)), "nixos")
			if kind == "symlink ancestor" {
				if err := os.Symlink(filepath.Dir(source), parent); err != nil {
					t.Fatal(err)
				}
			} else {
				if err := os.Mkdir(parent, 0755); err != nil {
					t.Fatal(err)
				}
				if kind == "writable ancestor" {
					if err := os.Chmod(parent, 0775); err != nil {
						t.Fatal(err)
					}
				} else {
					if err := os.Mkdir(filepath.Join(parent, "ssh-relay"), 0755); err != nil {
						t.Fatal(err)
					}
				}
			}
			before, err := os.Lstat(parent)
			if err != nil {
				t.Fatal(err)
			}
			c.config.CredentialStagePath = filepath.Join(parent, "ssh-relay", "authorization")
			if err := c.StageCredentials(context.Background(), source); err == nil {
				t.Fatal("unsafe parent accepted")
			}
			after, err := os.Lstat(parent)
			if err != nil || before.Mode() != after.Mode() {
				t.Fatal("unsafe parent was changed")
			}
			if _, err := os.Lstat(c.config.CredentialStagePath); !os.IsNotExist(err) {
				t.Fatalf("stage created: %v", err)
			}
		})
	}
}

// Resolves live paths using metadata only; never invokes a credential reader.
func TestNativeDarwinSourceMetadataOnly(t *testing.T) {
	if runtime.GOOS != "darwin" {
		t.Skip("native macOS metadata proof")
	}
	if os.Getenv("SSHRELAY_NATIVE_METADATA_TEST") != "1" {
		t.Skip("explicit native metadata diagnostic only")
	}
	resolved, err := resolveTrustedSourcePath("/run/secrets/ssh-relay/authorization", uint32(os.Getuid()))
	if err != nil {
		t.Fatal(err)
	}
	info, err := os.Lstat(resolved)
	if err != nil {
		t.Fatal(err)
	}
	if !info.Mode().IsRegular() || info.Mode().Perm() != 0600 || ownerUID(info) != uint32(os.Getuid()) {
		t.Fatal("unexpected native source leaf metadata")
	}
	t.Logf("metadata-only resolved source: %s", resolved)
}
