package main

import (
	"reflect"
	"testing"

	"github.com/glats/nixos-scripts/internal/remotelaunch"
)

func TestParseArgs(t *testing.T) {
	target, viewer, err := parseArgs([]string{"rog.lan", "3389", "--", "sdl-freerdp", "/v:{addr}"})
	if err != nil {
		t.Fatal(err)
	}
	if target != (remotelaunch.Target{Host: "rog.lan", Port: 3389}) {
		t.Fatalf("target = %+v", target)
	}
	if want := []string{"sdl-freerdp", "/v:{addr}"}; !reflect.DeepEqual(viewer, want) {
		t.Fatalf("viewer = %v, want %v", viewer, want)
	}
}

func TestParseArgsRejectsBadInput(t *testing.T) {
	cases := map[string][]string{
		"too few":        {"rog.lan", "3389"},
		"no separator":   {"rog.lan", "3389", "viewer", "x"},
		"non numeric":    {"rog.lan", "rdp", "--", "viewer"},
		"port too large": {"rog.lan", "70000", "--", "viewer"},
		"no viewer":      {"rog.lan", "3389", "--"},
	}
	for name, args := range cases {
		if _, _, err := parseArgs(args); err == nil {
			t.Errorf("%s: want error", name)
		}
	}
}
