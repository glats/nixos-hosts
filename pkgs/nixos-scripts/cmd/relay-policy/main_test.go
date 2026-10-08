package main

import "testing"

func TestStageDispatchesBeforeServiceAccountLookup(t *testing.T) {
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
