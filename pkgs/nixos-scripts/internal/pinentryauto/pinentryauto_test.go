package pinentryauto

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDecide(t *testing.T) {
	cases := []struct {
		name string
		args []string
		env  map[string]string
		want string
	}{
		{
			name: "no display and no opencode marker uses curses",
			args: []string{},
			env:  map[string]string{},
			want: FlavorCurses,
		},
		{
			name: "DISPLAY set uses qt",
			args: []string{},
			env:  map[string]string{"DISPLAY": ":0"},
			want: FlavorQt,
		},
		{
			name: "WAYLAND_DISPLAY set uses qt",
			args: []string{},
			env:  map[string]string{"WAYLAND_DISPLAY": "wayland-0"},
			want: FlavorQt,
		},
		{
			name: "a --display argument with a value uses qt",
			args: []string{"--display", ":99.9"},
			env:  map[string]string{},
			want: FlavorQt,
		},
		{
			name: "a --display=value argument with a value uses qt",
			args: []string{"--display=:99.9"},
			env:  map[string]string{},
			want: FlavorQt,
		},
		{
			name: "a valueless --display argument is not a display",
			args: []string{"--display"},
			env:  map[string]string{},
			want: FlavorCurses,
		},
		{
			name: "an empty --display value is not a display",
			args: []string{"--display", ""},
			env:  map[string]string{},
			want: FlavorCurses,
		},
		{
			name: "opencode marker without display asks to quit",
			args: []string{},
			env:  map[string]string{"PINENTRY_USER_DATA": "opencode"},
			want: "",
		},
		{
			name: "opencode marker among other tokens asks to quit",
			args: []string{},
			env:  map[string]string{"PINENTRY_USER_DATA": "extra, opencode"},
			want: "",
		},
		{
			name: "text containing opencode is not the marker",
			args: []string{},
			env:  map[string]string{"PINENTRY_USER_DATA": "notopencode"},
			want: FlavorCurses,
		},
		{
			name: "opencode marker with a display still uses qt",
			args: []string{},
			env:  map[string]string{"PINENTRY_USER_DATA": "opencode", "DISPLAY": ":0"},
			want: FlavorQt,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := Decide(tc.args, tc.env); got != tc.want {
				t.Fatalf("Decide = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestTargetPath(t *testing.T) {
	setupLayout := func(t *testing.T, wantsLibexec bool) string {
		t.Helper()
		root := t.TempDir()
		binDir := filepath.Join(root, "bin")
		if err := os.MkdirAll(binDir, 0o755); err != nil {
			t.Fatal(err)
		}
		if !wantsLibexec {
			return binDir
		}
		libexecDir := filepath.Join(root, "libexec", "nixos-scripts")
		if err := os.MkdirAll(libexecDir, 0o755); err != nil {
			t.Fatal(err)
		}
		for _, flavor := range []string{FlavorQt, FlavorCurses} {
			if err := os.WriteFile(filepath.Join(libexecDir, flavor), nil, 0o755); err != nil {
				t.Fatal(err)
			}
		}
		return binDir
	}

	t.Run("packaged flavors resolve through libexec", func(t *testing.T) {
		binDir := setupLayout(t, true)
		if got, want := TargetPath(binDir, FlavorQt), filepath.Join(binDir, "..", "libexec", "nixos-scripts", FlavorQt); got != want {
			t.Fatalf("TargetPath = %q, want %q", got, want)
		}
		if got, want := TargetPath(binDir, FlavorCurses), filepath.Join(binDir, "..", "libexec", "nixos-scripts", FlavorCurses); got != want {
			t.Fatalf("TargetPath = %q, want %q", got, want)
		}
	})

	t.Run("a same-directory flavor still resolves", func(t *testing.T) {
		binDir := setupLayout(t, false)
		if err := os.WriteFile(filepath.Join(binDir, FlavorQt), nil, 0o755); err != nil {
			t.Fatal(err)
		}
		if got, want := TargetPath(binDir, FlavorQt), filepath.Join(binDir, FlavorQt); got != want {
			t.Fatalf("TargetPath = %q, want %q", got, want)
		}
	})

	t.Run("a missing flavor falls back to the libexec path", func(t *testing.T) {
		binDir := setupLayout(t, false)
		if got, want := TargetPath(binDir, FlavorQt), filepath.Join(binDir, "..", "libexec", "nixos-scripts", FlavorQt); got != want {
			t.Fatalf("TargetPath = %q, want %q", got, want)
		}
	})

	t.Run("empty flavor yields no target", func(t *testing.T) {
		if got := TargetPath(t.TempDir(), ""); got != "" {
			t.Fatalf("TargetPath = %q, want empty", got)
		}
	})
}
