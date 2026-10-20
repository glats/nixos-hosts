package main

import (
	"errors"
	"reflect"
	"testing"

	"github.com/glats/nixos-scripts/internal/nixbuild"
)

func TestPushFailurePolicy(t *testing.T) {
	for _, command := range []string{"switch", "upgrade", "safe", "dry", "check", "build"} {
		for _, darwin := range []bool{false, true} {
			for _, code := range []int{0, 1} {
				for _, opt := range []string{"", "0"} {
					r := &recordingRunner{err: errors.New("probe failure")}
					var warnings []string
					maybePush(nixbuild.Env{Darwin: darwin, Hostname: "macm5"}, command, code,
						func(string) string { return opt }, r, func(w string) { warnings = append(warnings, w) })
					active := darwin && code == 0 && opt != "0" && (command == "switch" || command == "upgrade" || command == "safe")
					if !active {
						if len(r.argvs) != 0 || len(warnings) != 0 {
							t.Fatalf("unexpected push: %s %v %d %q: %v %v", command, darwin, code, opt, r.argvs, warnings)
						}
						continue
					}
					want := [][]string{{"nix", "copy", "--no-check-sigs", "--to", "ssh-ng://glats@thinkcentre", "/run/current-system"}}
					if !reflect.DeepEqual(r.argvs, want) {
						t.Errorf("%s argv: got %v want %v", command, r.argvs, want)
					}
					if !reflect.DeepEqual(warnings, []string{"push failed (best-effort, continuing): probe failure"}) {
						t.Errorf("warnings: %v", warnings)
					}
				}
			}
		}
	}
}
