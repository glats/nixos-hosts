package main

import (
	"os"
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

func TestUsageInterpolatesCurrentValues(t *testing.T) {
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
	if !strings.Contains(out, "(default: https://staging.example.com/seed.age)") {
		t.Fatalf("usage did not interpolate the current seed-url: %q", out)
	}
	if !strings.Contains(out, "0 success  1 args  2 fetch  3 decrypt  4 json  5 backup  6 merge") {
		t.Fatal("usage lost its exit-code table")
	}
}
