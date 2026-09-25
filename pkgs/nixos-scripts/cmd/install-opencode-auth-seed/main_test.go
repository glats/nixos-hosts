package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestIsAgeCiphertext(t *testing.T) {
	cases := []struct {
		name  string
		first string
		want  bool
	}{
		{"age header", "-----BEGIN AGE ENCRYPTED FILE-----YWdlLWVuY3J5cHRpb24ub3JnL3YxCg==", true},
		{"empty", "", false},
		{"pem", "-----BEGIN CERTIFICATE-----", false},
		{"base64 blob", "YWJjZA==", false},
		{"json", `{"auth":{}}`, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := isAgeCiphertext(tc.first); got != tc.want {
				t.Fatalf("isAgeCiphertext(%q) = %v, want %v", tc.first, got, tc.want)
			}
		})
	}
}

func TestFirstLine(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"", ""},
		{"one\n", "one"},
		{"one\ntwo\n", "one"},
		{"no trailing", "no trailing"},
	}
	for _, tc := range cases {
		if got := firstLine([]byte(tc.in)); got != tc.want {
			t.Errorf("firstLine(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestUsageDescribesExplicitSeedURLRequirement(t *testing.T) {
	// The bash heredoc is unquoted: usage shows the CURRENT resolved
	// values (env or earlier flags), not static defaults.
	oldURL := seedURL
	defer func() { seedURL = oldURL }()
	seedURL = "https://staging.example.com/seed.age"

	path := filepath.Join(t.TempDir(), "usage.txt")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	usage(f)
	f.Close()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	out := string(data)
	if !strings.Contains(out, "(required unless SEED_URL is set)") {
		t.Fatalf("usage did not describe the explicit seed-url requirement: %q", out)
	}
	if !strings.Contains(out, "0 success  1 args  2 fetch  3 decrypt  4 json  5 backup  6 merge") {
		t.Fatal("usage lost its exit-code table")
	}
}

func TestV2SeedKeepsV1AuthUntouched(t *testing.T) {
	cases := []struct {
		name       string
		breakV2Dir bool
		wantOK     bool
	}{
		{name: "writes V2 auth with mode 0600", wantOK: true},
		{name: "refuses a broken V2 destination", breakV2Dir: true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			home := t.TempDir()
			v1Auth := filepath.Join(home, ".local", "share", "opencode", "auth.json")
			if err := os.MkdirAll(filepath.Dir(v1Auth), 0o755); err != nil {
				t.Fatal(err)
			}
			const v1Contents = `{"v1":"unchanged"}`
			if err := os.WriteFile(v1Auth, []byte(v1Contents), 0o600); err != nil {
				t.Fatal(err)
			}

			if tc.breakV2Dir {
				v2Data := filepath.Join(home, ".local", "opencode-v2", "data")
				if err := os.MkdirAll(filepath.Dir(v2Data), 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(v2Data, []byte("not a directory"), 0o600); err != nil {
					t.Fatal(err)
				}
			}

			bin := writeSeedTestTools(t)
			key := filepath.Join(home, "key.txt")
			if err := os.WriteFile(key, []byte("test key"), 0o600); err != nil {
				t.Fatal(err)
			}
			cmd := exec.Command("go", "run", ".", "--v2", "--seed-url", "https://example.invalid/seed.age", "--key-file", key)
			cmd.Env = append(os.Environ(), "HOME="+home, "PATH="+bin+":"+os.Getenv("PATH"))
			err := cmd.Run()
			if tc.wantOK && err != nil {
				t.Fatalf("--v2 seed failed: %v", err)
			}
			if !tc.wantOK && err == nil {
				t.Fatal("--v2 seed succeeded with a broken V2 destination")
			}

			contents, err := os.ReadFile(v1Auth)
			if err != nil {
				t.Fatal(err)
			}
			if string(contents) != v1Contents {
				t.Fatalf("V1 auth changed to %q", contents)
			}

			if tc.wantOK {
				v2Auth := filepath.Join(home, ".local", "opencode-v2", "data", "auth.json")
				info, err := os.Stat(v2Auth)
				if err != nil {
					t.Fatal(err)
				}
				if info.Mode().Perm() != 0o600 {
					t.Fatalf("V2 auth mode = %04o, want 0600", info.Mode().Perm())
				}
			}
		})
	}
}

func writeSeedTestTools(t *testing.T) string {
	t.Helper()
	bin := t.TempDir()
	for name, body := range map[string]string{
		"curl": "#!/bin/sh\nprintf '%s\\n' '-----BEGIN AGE ENCRYPTED FILE-----' > \"$8\"\n",
		"age":  "#!/bin/sh\nprintf '%s\\n' '{\"proxy\":\"seed\"}' > \"$5\"\n",
		"jq":   "#!/bin/sh\nprintf '1\\n'\n",
	} {
		path := filepath.Join(bin, name)
		if err := os.WriteFile(path, []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return bin
}
