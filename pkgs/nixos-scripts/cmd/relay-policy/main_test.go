package main

import (
	"errors"
	"runtime"
	"testing"
)

func TestStageDispatchesBeforeServiceAccountLookup(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("stage dispatch is supported only on Linux")
	}
	const source = "/run/secrets/ssh-relay/authorization"
	called := ""
	err := run([]string{"stage", source}, func(path string) error {
		called = path
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if called != source {
		t.Fatalf("stage source = %q, want %q", called, source)
	}
}

func TestUnsupportedPlatformRejectsActions(t *testing.T) {
	if runtime.GOOS == "linux" {
		t.Skip("unsupported-platform rejection requires a non-Linux host")
	}
	for _, action := range []string{"apply", "revoke", "stage"} {
		t.Run(action, func(t *testing.T) {
			args := []string{action}
			if action == "stage" {
				args = append(args, "/run/secrets/ssh-relay/authorization")
			}
			err := run(args, func(string) error {
				t.Fatal("unsupported platform dispatched staging")
				return nil
			})
			if !errors.Is(err, errUsage) {
				t.Fatalf("run(%q) = %v, want platform usage rejection before service account lookup", args, err)
			}
		})
	}
}
