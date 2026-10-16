package sshtunnel

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
)

const FallbackPortStep = 10000

func BuildSSHArgs(host, user, keyPath string, localPort, remotePort int) []string {
	return []string{
		"-i", keyPath,
		"-N",
		"-L", fmt.Sprintf("127.0.0.1:%d:%s:%d", localPort, host, remotePort),
		fmt.Sprintf("%s@%s", user, host),
	}
}

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

func LocalURL(localPort int) string {
	return fmt.Sprintf("http://127.0.0.1:%d/", localPort)
}

func BuildBridgeSSHArgs(host string, ports []int) ([]string, error) {
	if host == "" {
		return nil, fmt.Errorf("bridge host is required (use an ssh_config alias, e.g. a LAN-mesh member)")
	}
	if len(ports) == 0 {
		return nil, fmt.Errorf("at least one callback port is required")
	}
	args := []string{
		"-N",
		"-o", "ExitOnForwardFailure=yes",
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=5",
		"-o", "ServerAliveInterval=15",
		"-o", "ServerAliveCountMax=4",
	}
	for _, port := range ports {
		if port < 1 || port > 65535 {
			return nil, fmt.Errorf("forward port %d out of range 1..65535", port)
		}
		args = append(args, "-R", fmt.Sprintf("127.0.0.1:%d:localhost:%d", port, port))
	}
	return append(args, host), nil
}

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
