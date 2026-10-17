package pinentryauto

import "testing"

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
	cases := []struct {
		name   string
		exeDir string
		flavor string
		want   string
	}{
		{name: "qt lives next to the entry point", exeDir: "/bin", flavor: FlavorQt, want: "/bin/pinentry-qt"},
		{name: "curses lives next to the entry point", exeDir: "/bin", flavor: FlavorCurses, want: "/bin/pinentry-curses"},
		{name: "empty flavor yields no target", exeDir: "/bin", flavor: "", want: ""},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := TargetPath(tc.exeDir, tc.flavor); got != tc.want {
				t.Fatalf("TargetPath = %q, want %q", got, tc.want)
			}
		})
	}
}
