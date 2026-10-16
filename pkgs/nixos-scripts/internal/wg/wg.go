package wg

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

const (
	StartMark = "# --- wg-peer:managed-start ---"
	EndMark   = "# --- wg-peer:managed-end ---"
)

type Peer struct {
	Name      string
	IP        string
	PublicKey string
}

var PeerNameRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]+$`)

var (
	markerRe   = regexp.MustCompile(`(?m)^[ \t]*` + regexp.QuoteMeta(StartMark) + `[ \t]*$`)
	endRe      = regexp.MustCompile(`(?m)^[ \t]*` + regexp.QuoteMeta(EndMark) + `[ \t]*$`)
	ipLineRe   = regexp.MustCompile(`(?m)^[ \t]*ip = "([^"]+)";`)
	peerHeadRe = regexp.MustCompile(`^    ([A-Za-z0-9][A-Za-z0-9-]*) = \{$`)
	blockEndRe = regexp.MustCompile(`^    \};$`)
)

func HasMarkers(content string) bool {
	return markerRe.MatchString(content) && endRe.MatchString(content)
}

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

func AllIPs(content string) []string {
	var ips []string
	for _, m := range ipLineRe.FindAllStringSubmatch(content, -1) {
		ips = append(ips, m[1])
	}
	return ips
}

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

func UpdatePeerPublicKey(content, name, newPub string) (string, bool) {
	re := regexp.MustCompile(`(?s)(#\s*` + regexp.QuoteMeta(name) + `\b.*?publicKey = )"[^"]*";`)
	if !re.MatchString(content) {
		return content, false
	}
	return re.ReplaceAllString(content, `${1}"`+newPub+`";`), true
}

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
