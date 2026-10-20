package nixcache

import (
	"errors"
	"reflect"
	"testing"
)

func TestDestinationFailurePolicy(t *testing.T) {
	for _, dest := range []string{
		"ssh-ng://glats@thinkcentre",
		"ssh-ng://glats@thinkcentre/",
		"ssh-ng://glats@thinkcentre:22",
		"ssh-ng://glats@thinkcentre?remote-store=other",
		"ssh-ng://glats@thinkcentre.example",
		"ssh-ng://root@thinkcentre",
		"ssh-ng://glats@THINKCENTRE",
		"https://cache.example",
		"file:///tmp/cache",
		"",
	} {
		t.Run(dest, func(t *testing.T) {
			for _, strict := range []bool{false, true} {
				r := &fakeRunner{fail: func([]string) error { return errors.New("probe failure") }}
				var warnings []string
				err := Push(dest, nil, strict, r, func(w string) { warnings = append(warnings, w) })
				if dest == "" {
					if err == nil || err.Error() != "nix-cache push: empty --to destination" || len(r.argvs) != 0 || len(warnings) != 0 {
						t.Fatalf("empty destination: %v %v %v", err, r.argvs, warnings)
					}
					continue
				}
				want := []string{"nix", "copy"}
				if dest == "ssh-ng://glats@thinkcentre" {
					want = append(want, "--no-check-sigs")
				}
				want = append(want, "--to", dest, "/run/current-system")
				if !reflect.DeepEqual(r.argvs, [][]string{want}) {
					t.Errorf("argv: %v want %v", r.argvs, want)
				}
				if strict {
					if err == nil || err.Error() != "nix copy --to "+dest+": probe failure" || len(warnings) != 0 {
						t.Fatalf("strict: %v %v", err, warnings)
					}
				} else if err != nil || !reflect.DeepEqual(warnings, []string{"push failed (best-effort, continuing): probe failure"}) {
					t.Fatalf("best effort: %v %v", err, warnings)
				}
			}
		})
	}
}
