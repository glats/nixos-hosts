// Command device-link prints the runtime-only vless:// phone share link for
// the private link, or a full sing-box client config JSON for sing-box for
// Android (SFA).
//
// Port of bin/device-link: usage text, validation, messages and exit codes
// preserved. The UUID is read with a plain file read — the bash original
// piped cat so the UUID never appears in this process's argv (visible via
// /proc/<pid>/cmdline on Linux); a direct read keeps that guarantee. The
// terminal QR still shells out to `qrencode` from PATH exactly like the
// bash original (the derivation wraps this binary with wrapProgram so
// qrencode resolves).
//
// NEVER writes the UUID or the link to the repo, Nix store, logs, or any
// file. Designed to be piped straight into a QR encoder or copied to a
// clipboard — runtime-only delivery, never persisted anywhere.
//
// Usage:
//
//	device-link phone            # prints link for phone device
//	device-link phone --config   # full sing-box config JSON for SFA
//	device-link phone /custom/uuid/path   # explicit UUID path
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

// wsPath is the obscurity-not-secret WS path constant — must stay
// byte-identical across the rog server
// (linux/system/services/network/sing-box-link.nix), the nginx vhost
// (linux/system/services/web/nginx.nix) and the mact2 client
// (darwin/system/sing-box-link.nix).
const wsPath = "/ed59280aa562f4b7eba4519e3c316e24"

// deviceRe validates the device name used in the URL fragment.
var deviceRe = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

// uuidRe validates the rendered UUID. Fail closed — a corrupt file MUST
// NOT produce a usable link.
var uuidRe = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

const defaultUUIDFile = "/run/secrets/link/uuid_phone"

// configTemplate is the full sing-box client config for SFA, rendered with
// the UUID and the WS path (bash printf placeholders $uuid / $ws_path).
const configTemplate = `{
  "log": { "level": "info" },
  "dns": { "servers": [{ "tag": "direct-dns", "type": "local" }] },
  "inbounds": [{
    "type": "tun", "tag": "sb-tun",
    "address": ["172.19.0.1/30"],
    "auto_route": true, "strict_route": true, "stack": "system"
  }],
  "outbounds": [
    {
      "type": "vless", "tag": "home-out",
      "server": "tun.glats.org", "server_port": 443,
      "uuid": "%s",
      "tls": {
        "enabled": true, "server_name": "tun.glats.org",
        "utls": { "enabled": true, "fingerprint": "chrome" }
      },
      "transport": { "type": "ws", "path": "%s", "headers": { "Host": "tun.glats.org" } }
    },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" },
    {
      "type": "urltest", "tag": "auto",
      "outbounds": ["home-out", "direct"],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m", "tolerance": 50
    }
  ],
  "route": {
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "network": ["icmp"], "outbound": "direct" },
      { "ip_is_private": true, "outbound": "direct" }
    ],
    "final": "auto",
    "auto_detect_interface": true,
    "default_domain_resolver": "direct-dns"
  }
}
`

// stripSpace removes every POSIX [[:space:]] character, matching the bash
// ${uuid//[[:space:]]/} expansion.
func stripSpace(s string) string {
	return strings.Map(func(r rune) rune {
		switch r {
		case ' ', '\t', '\n', '\v', '\f', '\r':
			return -1
		}
		return r
	}, s)
}

// buildLink assembles the vless:// share link. The fragment becomes the
// profile name in SFA. Params (verified against the sing-box vless parser
// per addendum R5): encryption=none — VLESS without inner encryption;
// security=tls — outer TLS, terminated by nginx; sni/fp — outer ClientHello
// matches mact2's uTLS chrome fingerprint; type=ws over :443.
func buildLink(uuid, device string) string {
	return fmt.Sprintf("vless://%s@tun.glats.org:443?encryption=none&security=tls&sni=tun.glats.org&fp=chrome&type=ws&host=tun.glats.org&path=%s#mact2-link-%s", uuid, wsPath, device)
}

// isTerminal reports whether f is attached to a character device (the bash
// [ -t 1 ] check).
func isTerminal(f *os.File) bool {
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

func usage() {
	fmt.Fprintf(os.Stderr, `Usage: %s <device> [<uuid-file>]

Print a vless:// share link to stdout for importing into sing-box for
Android (SFA). The phone UUID is read at runtime from the host's
rendered sops file and never written to disk, the Nix store, or logs.

Arguments:
  <device>      Device name (cosmetic, used in the link fragment only).
  <uuid-file>   Optional explicit path to the rendered UUID file.
                Defaults:
                  - rog:     /run/secrets/link/uuid_phone
                  - mact2:   /run/secrets/link/uuid_phone

Environment:
  LINK_PHONE_UUID_FILE   Override the UUID file path (CI / scripting).
`, filepath.Base(os.Args[0]))
	os.Exit(0)
}

func main() {
	args := os.Args[1:]
	if len(args) < 1 || args[0] == "-h" || args[0] == "--help" {
		usage()
	}
	device := args[0]
	args = args[1:]

	mode := "link"
	if len(args) > 0 && args[0] == "--config" {
		mode = "config"
		args = args[1:]
	}

	// Validate device name — used in the URL fragment so keep it tame.
	if !deviceRe.MatchString(device) {
		fmt.Fprintf(os.Stderr, "error: device name '%s' must be [A-Za-z0-9_-]+\n", device)
		os.Exit(2)
	}

	// Resolve the UUID file path. Priority:
	//   1. explicit positional argument
	//   2. LINK_PHONE_UUID_FILE env var
	//   3. default path (rog + mact2 layout is identical)
	uuidFile := defaultUUIDFile
	if v := os.Getenv("LINK_PHONE_UUID_FILE"); v != "" {
		uuidFile = v
	}
	if len(args) > 0 {
		uuidFile = args[0]
	}

	if !readable(uuidFile) {
		fmt.Fprintf(os.Stderr, "error: UUID file not readable: %s\n", uuidFile)
		fmt.Fprintln(os.Stderr, "       (sops-install-secrets must have run; check activation log)")
		os.Exit(1)
	}

	// Read the UUID directly (no argv exposure, unlike passing it as an
	// argument) and strip all whitespace.
	data, err := os.ReadFile(uuidFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: UUID file not readable: %s\n", uuidFile)
		fmt.Fprintln(os.Stderr, "       (sops-install-secrets must have run; check activation log)")
		os.Exit(1)
	}
	uuid := stripSpace(string(data))

	// Validate it looks like a UUID. Fail closed — a corrupt file MUST NOT
	// produce a usable link.
	if !uuidRe.MatchString(uuid) {
		fmt.Fprintf(os.Stderr, "error: UUID at %s does not match UUID format\n", uuidFile)
		os.Exit(1)
	}

	if mode == "config" {
		// Full sing-box client config for SFA (Local profile via clipboard).
		// Mirrors the mact2 darwin client minus macOS-specific bits (no
		// process rules on Android; endpoint-agent CIDR exclusion is a Mac
		// concern). Validated shape: identical rule/dns/urltest structure
		// passes `sing-box check` on 1.13.x. urltest order note: the Mac
		// client lists "direct" first (safe default for degenerate states);
		// the phone profile keeps "home-out" first — a phone's degenerate
		// fallback is normal mobile egress, so probing the link first is
		// the sensible default there.
		fmt.Printf(configTemplate, uuid, wsPath)
		return
	}

	fmt.Println(buildLink(uuid, device))

	// Interactive terminals also get a scannable QR (rendered to stdout,
	// never a file — same runtime-only rule as the link). Piped stdout
	// stays machine-consumable: URL only, no QR.
	qrBin, err := exec.LookPath("qrencode")
	if err != nil {
		fmt.Fprintln(os.Stderr, "(qrencode not on PATH — copy the link and use SFA → + → Import from clipboard)")
		return
	}
	if !isTerminal(os.Stdout) {
		return
	}
	fmt.Fprint(os.Stderr, "\nScan in SFA (sing-box for Android → + → scan/import):\n\n")
	cmd := exec.Command(qrBin, "-t", "ANSIUTF8", "-m", "2", buildLink(uuid, device))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		// qrencode could not run at all (bash prints a shell-level
		// "command not found" line; closest portable equivalent below).
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(127)
	}
}

// readable ports the [ -r "$uuid_file" ] check.
func readable(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	f.Close()
	return true
}
