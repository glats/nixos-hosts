// Package wg implements the declarative WireGuard peer management used by
// the wg-peer command: marker-based parsing and mutation of the peer block
// in linux/system/services/network/wireguard.nix.
//
// Byte format parity contract (with the retired bash wg-peer):
//
//	# --- wg-peer:managed-start ---
//	    name = {
//	      ip = "10.13.13.N";
//	      publicKey = "<base64>";
//	      psk = null;
//	    };
//	# --- wg-peer:managed-end ---
package wg

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

const (
	// StartMark / EndMark bound the wg-peer managed block in wireguard.nix.
	StartMark = "# --- wg-peer:managed-start ---"
	EndMark   = "# --- wg-peer:managed-end ---"
)

// Peer is one declarative peer entry inside the managed block.
type Peer struct {
	Name      string
	IP        string
	PublicKey string
}

// PeerNameRe is the peer name contract from the bash original: lowercase
// letters, digits and dashes, starting with a letter or digit.
var PeerNameRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]+$`)

var (
	markerRe   = regexp.MustCompile(`(?m)^[ \t]*` + regexp.QuoteMeta(StartMark) + `[ \t]*$`)
	endRe      = regexp.MustCompile(`(?m)^[ \t]*` + regexp.QuoteMeta(EndMark) + `[ \t]*$`)
	ipLineRe   = regexp.MustCompile(`(?m)^[ \t]*ip = "([^"]+)";`)
	peerHeadRe = regexp.MustCompile(`^    ([A-Za-z0-9][A-Za-z0-9-]*) = \{$`)
	blockEndRe = regexp.MustCompile(`^    \};$`)
)

// HasMarkers reports whether both managed markers exist in the content.
func HasMarkers(content string) bool {
	return markerRe.MatchString(content) && endRe.MatchString(content)
}

// ParsePeers returns the peers declared inside the managed block, in file
// order.
func ParsePeers(content string) ([]Peer, error) {
	start := markerRe.FindStringIndex(content)
	end := endRe.FindStringIndex(content)
	if start == nil || end == nil {
		return nil, fmt.Errorf("wg-peer markers missing in wireguard.nix")
	}
	if end[0] < start[1] {
		return nil, fmt.Errorf("wg-peer markers out of order in wireguard.nix")
	}
	block := content[start[1]:end[0]]

	var (
		peers []Peer
		cur   *Peer
	)
	for _, line := range strings.Split(block, "\n") {
		if m := peerHeadRe.FindStringSubmatch(line); m != nil {
			cur = &Peer{Name: m[1]}
			continue
		}
		if cur == nil {
			continue
		}
		if strings.HasPrefix(strings.TrimSpace(line), `ip = "`) {
			cur.IP = extractQuoted(line)
		} else if strings.HasPrefix(strings.TrimSpace(line), `publicKey = "`) {
			cur.PublicKey = extractQuoted(line)
		} else if blockEndRe.MatchString(line) {
			peers = append(peers, *cur)
			cur = nil
		}
	}
	return peers, nil
}

// AllIPs returns every `ip = "..."` assignment in the whole module (parity
// with the bash awk scan, which was not restricted to the managed block).
func AllIPs(content string) []string {
	var ips []string
	for _, m := range ipLineRe.FindAllStringSubmatch(content, -1) {
		ips = append(ips, m[1])
	}
	return ips
}

// NextIP returns the next free host address in network (e.g. "10.13.13"),
// mirroring the bash logic: highest existing 4th octet + 1, capped at 254.
func NextIP(content, network string) (string, error) {
	prefix := network + "."
	last := 0
	for _, ip := range AllIPs(content) {
		if !strings.HasPrefix(ip, prefix) {
			continue
		}
		n, err := strconv.Atoi(strings.TrimPrefix(ip, prefix))
		if err != nil {
			continue
		}
		if n > last {
			last = n
		}
	}
	next := last + 1
	if next > 254 {
		return "", fmt.Errorf("no free IPs left in %s.0/24", network)
	}
	return fmt.Sprintf("%s.%d", network, next), nil
}

// InsertPeer returns the content with a new peer block inserted immediately
// before the managed-end marker (byte-exact format of the bash awk script).
func InsertPeer(content, name, ip, publicKey string) (string, error) {
	if !HasMarkers(content) {
		return "", fmt.Errorf("wg-peer markers missing in wireguard.nix")
	}
	block := fmt.Sprintf(
		"    %s = {\n      ip = \"%s\";\n      publicKey = \"%s\";\n      psk = null;\n    };\n",
		name, ip, publicKey,
	)
	loc := endRe.FindStringIndex(content)
	out := content[:loc[0]] + block + content[loc[0]:]
	return out, nil
}

// RemovePeer returns the content with the named peer block removed, using
// the exact line semantics of the retired bash awk (match "    name = {"
// through the first following "    };").
func RemovePeer(content, name string) (string, bool) {
	head := "    " + name + " = {"
	lines := strings.Split(content, "\n")
	out := make([]string, 0, len(lines))
	skip := false
	removed := false
	for _, line := range lines {
		if !skip && line == head {
			skip = true
			removed = true
			continue
		}
		if skip {
			if line == "    };" {
				skip = false
			}
			continue
		}
		out = append(out, line)
	}
	return strings.Join(out, "\n"), removed
}

// UpdatePeerPublicKey replaces the publicKey assignment of the peer whose
// declaration is preceded by a `# <name>` comment — the Go equivalent of the
// retired python3 regex with DOTALL semantics:
//
//	(# <name>.*?publicKey = )".*?";
func UpdatePeerPublicKey(content, name, newPub string) (string, bool) {
	re := regexp.MustCompile(`(?s)(#\s*` + regexp.QuoteMeta(name) + `\b.*?publicKey = )"[^"]*";`)
	if !re.MatchString(content) {
		return content, false
	}
	return re.ReplaceAllString(content, `${1}"`+newPub+`";`), true
}

// ParseWGShowHandshakes extracts public-key → "latest handshake" timestamp
// pairs from `wg show wg0` output. Improvement over the bash original,
// which awk-truncated the timestamp to its first three fields ("1 minute, 2"
// instead of "1 minute, 2 seconds").
func ParseWGShowHandshakes(show string) map[string]string {
	hs := map[string]string{}
	var cur string
	for _, line := range strings.Split(show, "\n") {
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		trimmed := strings.TrimSpace(line)
		switch {
		case fields[0] == "peer:" && len(fields) >= 2:
			cur = fields[1]
		case strings.HasPrefix(trimmed, "latest handshake:") && cur != "":
			ts := strings.TrimPrefix(trimmed, "latest handshake: ")
			hs[cur] = strings.TrimSuffix(ts, " ago")
		}
	}
	return hs
}

func extractQuoted(line string) string {
	i := strings.Index(line, `"`)
	if i < 0 {
		return ""
	}
	rest := line[i+1:]
	j := strings.Index(rest, `"`)
	if j < 0 {
		return ""
	}
	return rest[:j]
}
