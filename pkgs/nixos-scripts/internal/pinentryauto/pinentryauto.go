package pinentryauto

import (
	"path/filepath"
	"strings"
)

const (
	FlavorQt     = "pinentry-qt"
	FlavorCurses = "pinentry-curses"
)

// Decide picks the pinentry flavor that should be exec'd in place, given the
// pinentry command line gpg-agent provided and the inherited environment.
// It returns FlavorQt or FlavorCurses, or "" when no flavor may run: that is
// the opencode contract, where a curses prompt would corrupt the TUI and the
// sign operation must fail cleanly instead.
func Decide(args []string, env map[string]string) string {
	if envDisplay(args, env) {
		return FlavorQt
	}
	if forbidsCurses(env["PINENTRY_USER_DATA"]) {
		return ""
	}
	return FlavorCurses
}

// envDisplay mirrors pinentry's own display selection: the agent may hand the
// display as a --display argument, or it may arrive through the environment.
func envDisplay(args []string, env map[string]string) bool {
	if env["DISPLAY"] != "" || env["WAYLAND_DISPLAY"] != "" {
		return true
	}
	for i, arg := range args {
		value, hasValue := strings.CutPrefix(arg, "--display=")
		if hasValue {
			if value != "" {
				return true
			}
			continue
		}
		if arg != "--display" {
			continue
		}
		if i+1 < len(args) && args[i+1] != "" {
			return true
		}
	}
	return false
}

// forbidsCurses reads the opencode marker out of PINENTRY_USER_DATA, which
// gpg-agent forwards to every pinentry process. Tokens are split on commas
// and whitespace, so "notopencode" never matches.
func forbidsCurses(userData string) bool {
	for _, token := range strings.FieldsFunc(userData, func(r rune) bool {
		return r == ',' || r == ' '
	}) {
		if token == "opencode" {
			return true
		}
	}
	return false
}

// TargetPath resolves the flavor binary next to the pinentry-auto entry
// point; the flavors are symlinked into the same packaged bin directory as
// the entry point by the derivation. An empty flavor maps to no path.
func TargetPath(exeDir string, flavor string) string {
	if flavor == "" {
		return ""
	}
	return filepath.Join(exeDir, flavor)
}
