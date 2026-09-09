// Package sshtunnel implements the reusable tunnel plumbing for the
// adguard-tunnel command: SSH argument assembly, local port resolution and
// UI URL formatting. It deliberately contains no exec or network dialing
// beyond the localhost listener availability probe, so the test suite stays
// hermetic (no remote connections, no real ssh invocation).
//
// adguard-tunnel gives the operator UI access to AdGuard Home on the OnePlus
// 5 (`172.16.0.12:3000`). The phone's curated nftables firewall intentionally
// blocks :3000 from the LAN by design, so access is an SSH local port-forward
// authenticated with the dedicated key (~/.ssh/oneplus5). SSH key auth IS the
// access control for the admin UI.
package sshtunnel

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
)

// FallbackPortStep is how far PickFreePort jumps when the requested local
// port is busy: host + step (3000 → 13000). One fallback, then refuse.
const FallbackPortStep = 10000

// BuildSSHArgs assembles the argument vector for the `ssh` binary given a
// destination host, SSH user, identity key path and a local→remote forward
// pair. The forward binds the local loopback end (127.0.0.1:<localPort>) to
// <targetHost>:<remotePort> as seen FROM the remote host; the forward target
// defaults to the same host string, making this a generic single-hop pair
// (AdGuard specifics are only the command's flag defaults).
//
// The arg shape is:
//
//	ssh -i <keyPath> -N -L 127.0.0.1:<localPort>:<targetHost>:<remotePort> <user>@<host>
func BuildSSHArgs(host, user, keyPath string, localPort, remotePort int) []string {
	return []string{
		"-i", keyPath,
		"-N",
		"-L", fmt.Sprintf("127.0.0.1:%d:%s:%d", localPort, host, remotePort),
		fmt.Sprintf("%s@%s", user, host),
	}
}

// PickFreePort verifies the requested local port is free on loopback. If Busy
// it falls back to request+FallbackPortStep and returns (fallback, true). A
// second failure is a hard error ("refuse" behavior, documented in the help
// text). The listener is closed before returning — options races leak ssh
// clear errors, accepted for a single-user helper.
func PickFreePort(requested int) (chosen int, fellBack bool, err error) {
	probe := func(port int) bool {
		l, e := net.Listen("tcp4", fmt.Sprintf("127.0.0.1:%d", port))
		if e != nil {
			return false
		}
		l.Close()
		return true
	}

	switch {
	case probe(requested):
		return requested, false, nil
	case probe(requested + FallbackPortStep):
		return requested + FallbackPortStep, true, nil
	default:
		return 0, false, fmt.Errorf(
			"local ports %d and %d are both unavailable; free one and retry",
			requested, requested+FallbackPortStep)
	}
}

// LocalURL renders the operator-facing URL for the forward's local end.
func LocalURL(localPort int) string {
	return fmt.Sprintf("http://127.0.0.1:%d/", localPort)
}

// ExpandHome makes a leading "~/" or "~" resolve to the current user's home
// directory; absolute and relative paths pass through unchanged.
func ExpandHome(path string) (string, error) {
	if path == "~" {
		return os.UserHomeDir()
	}
	if rest, ok := strings.CutPrefix(path, "~/"); ok {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolving home for %q: %w", path, err)
		}
		return filepath.Join(home, rest), nil
	}
	return path, nil
}
