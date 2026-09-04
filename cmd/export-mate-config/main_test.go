package main

import (
	"os"
	"strings"
	"testing"
)

func TestConvertValue(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  string
	}{
		{name: "two-element array keeps the bash double-space quirk", value: "['a', 'b']", want: `[ "a" "b"  ]`},
		{name: "empty array", value: "[]", want: "[   ]"},
		// The bash pipeline always leaves a trailing space (echo's newline
		// survives tr), so even a single element renders double-spaced.
		{name: "single-element array", value: "['x']", want: `[ "x"  ]`},
		{name: "array without spaces", value: "['a','b']", want: `[ "a" "b"  ]`},
		{name: "boolean true passes through", value: "true", want: "true"},
		{name: "boolean false passes through", value: "false", want: "false"},
		{name: "quoted true is a string", value: "'true'", want: `"true"`},
		{name: "integer passes through", value: "42", want: "42"},
		{name: "zero passes through", value: "0", want: "0"},
		{name: "negative number is a string", value: "-1", want: `"-1"`},
		{name: "quoted string rewrapped", value: "'Menta'", want: `"Menta"`},
		{name: "unquoted string still wrapped", value: "Menta", want: `"Menta"`},
		{name: "empty value becomes empty string", value: "", want: `""`},
		{name: "value containing equals is kept whole", value: "'a=b'", want: `"a=b"`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := convertValue(tt.value); got != tt.want {
				t.Errorf("convertValue(%q) = %q, want %q", tt.value, got, tt.want)
			}
		})
	}
}

func TestArrayBody(t *testing.T) {
	tests := []struct {
		name    string
		content string
		want    string
	}{
		{name: "comma splitting trims elements", content: "'a', 'b'", want: `"a" "b" `},
		{name: "quote replacement", content: "['x']", want: `["x"] `},
		{name: "empty content keeps the echo trailing space", content: "", want: " "},
		{name: "inner double spaces collapse", content: "'a  b'", want: `"a b" `},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := arrayBody(tt.content); got != tt.want {
				t.Errorf("arrayBody(%q) = %q, want %q", tt.content, got, tt.want)
			}
		})
	}
}

func TestXargsTrim(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{name: "plain key", in: "theme-name", want: "theme-name"},
		{name: "leading and trailing spaces", in: "  key  ", want: "key"},
		{name: "internal whitespace collapses", in: "a  b\tc", want: "a b c"},
		{name: "empty", in: "", want: ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := xargsTrim(tt.in); got != tt.want {
				t.Errorf("xargsTrim(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestConvertDump(t *testing.T) {
	// Section paths are relative to /org/mate/ in a real dump; the
	// conversion re-prefixes "org/mate/".
	const dump = `[desktop/interface]
color-scheme='default'
enable-animations=true
gtk-theme='Menta'

[marco/general]
num-workspaces=4
theme='Crux'

[panel]
object-id-list=['menu-bar', 'notification-area']
`
	want := `{ config, lib, pkgs, ... }:

{
  dconf.settings = {
    "org/mate/desktop/interface" = {
      color-scheme = "default";
      enable-animations = true;
      gtk-theme = "Menta";
    };

    "org/mate/marco/general" = {
      num-workspaces = 4;
      theme = "Crux";
    };

    "org/mate/panel" = {
      object-id-list = [ "menu-bar" "notification-area"  ];
    };
`
	if got := convertDump(dump); got != want {
		t.Errorf("convertDump mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}

// TestConvertDumpSkipsNonMatchingLines pins that lines which match neither
// the section nor the key=value pattern are skipped (bash if/elif fall-through).
func TestConvertDumpSkipsNonMatchingLines(t *testing.T) {
	got := convertDump("=nokey\nnovalue\n[sec]\nkey='v'\n")
	if strings.Contains(got, "nokey") || strings.Contains(got, "novalue") {
		t.Errorf("non-matching lines must be skipped, got:\n%s", got)
	}
	if !strings.Contains(got, "      key = \"v\";\n") {
		t.Errorf("key line missing, got:\n%s", got)
	}
}

// TestConvertDumpEmpty pins the bash parity quirk: with an empty dump the
// unconditional final close still renders (malformed, but identical).
func TestConvertDumpEmpty(t *testing.T) {
	want := header + "    };\n"
	if got := convertDump(""); got != want {
		t.Errorf("convertDump(\"\") = %q, want %q", got, want)
	}
}

func TestPrintLastLines(t *testing.T) {
	tests := []struct {
		name string
		out  string
		n    int
		want string
	}{
		{name: "empty output prints nothing", out: "", n: 10, want: ""},
		{name: "fewer lines than n", out: "a\nb\n", n: 10, want: "a\nb\n"},
		{name: "more lines than n", out: "1\n2\n3\n4\n", n: 2, want: "3\n4\n"},
		{name: "exact n", out: "1\n2\n", n: 2, want: "1\n2\n"},
		{name: "no trailing newline", out: "1\n2", n: 1, want: "2\n"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Capture stdout via os.Pipe to keep the check honest.
			got := captureStdout(t, func() { printLastLines(tt.out, tt.n) })
			if got != tt.want {
				t.Errorf("printLastLines(%q, %d) printed %q, want %q", tt.out, tt.n, got, tt.want)
			}
		})
	}
}

func captureStdout(t *testing.T, fn func()) string {
	t.Helper()
	old := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatalf("os.Pipe: %v", err)
	}
	os.Stdout = w
	done := make(chan string)
	go func() {
		var b strings.Builder
		buf := make([]byte, 4096)
		for {
			n, err := r.Read(buf)
			if n > 0 {
				b.Write(buf[:n])
			}
			if err != nil {
				break
			}
		}
		done <- b.String()
	}()
	fn()
	w.Close()
	os.Stdout = old
	return <-done
}
