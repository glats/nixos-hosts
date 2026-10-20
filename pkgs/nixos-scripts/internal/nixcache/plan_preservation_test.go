package nixcache

import (
	"fmt"
	"path/filepath"
	"reflect"
	"testing"
)

func TestPlansPreserveArguments(t *testing.T) {
	for _, opts := range []Options{{}, {Flake: "git+file:///a b?ref=main", StateDir: "/state with spaces"}} {
		for _, variant := range []string{"current", "next"} {
			ref := opts.Flake
			got := CurrentSteps(opts)
			if variant == "next" {
				ref = filepath.Join(opts.StateDir, "next")
				got = NextSteps(opts)
			}
			var want []Step
			for _, kind := range []string{"nixos", "home", "darwin", "home"} {
				hosts := []string{"macm5"}
				if len(want) < 6 {
					hosts = []string{"rog", "t14", "thinkcentre"}
				}
				for _, host := range hosts {
					attr := fmt.Sprintf("nixosConfigurations.%s.config.system.build.toplevel", host)
					if kind == "home" {
						attr = fmt.Sprintf("homeConfigurations.%s.activationPackage", host)
					}
					if kind == "darwin" {
						attr = "darwinConfigurations.macm5.config.system.build.toplevel"
					}
					args := []string{"nix", "build", "--out-link", filepath.Join(opts.StateDir, "roots", variant, kind+"-"+host)}
					if host == "macm5" {
						args = append(args, "--option", "max-jobs", "0")
					}
					args = append(args, "--keep-going", ref+"#"+attr)
					want = append(want, Step{Name: kind + " host " + host, Args: args, Fatal: variant == "current" && host != "macm5"})
				}
			}
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("%s got %#v want %#v", variant, got, want)
			}
		}
	}
}
