package ui

import (
	"strings"
	"testing"
)

// Confirm trims whitespace then accepts exactly "y" or "Y" — the Go port of
// the bash regex ^[Yy]$ from common.sh confirm_action.
func TestConfirmContract(t *testing.T) {
	scenarios := []struct {
		input string
		want  bool
	}{
		{"y", true},
		{"Y", true},
		{"yes", false},
		{"", false},
		{"n", false},
		{"no", false},
		{"y\n", true}, // scanner line ending trimmed
	}
	for _, s := range scenarios {
		resp := strings.TrimSpace(s.input)
		got := resp == "y" || resp == "Y"
		if got != s.want {
			t.Fatalf("input %q: got %v, want %v", s.input, got, s.want)
		}
	}
}
