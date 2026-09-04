// Command opencode2 runs OpenCode 2.0 beta inside an isolated docker sandbox.
//
// Port of bin/opencode2. v1 stays untouched: config is mounted read-only and
// the DB is a copy in ~/.opencode2-sandbox (made with sqlite3 .backup).
//
// Usage:
//
//	opencode2                      -> TUI
//	opencode2 run -m opencode-go/... "msg"
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

const image = "opencode2-beta"

const dockerfile = `FROM node:24-slim
RUN npm install -g @opencode-ai/cli@next
`

func main() {
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	data := filepath.Join(home, ".opencode2-sandbox", "data")
	v1Cfg := filepath.Join(home, ".config", "opencode", "opencode.json")

	if err := exec.Command("docker", "image", "inspect", image).Run(); err != nil {
		fmt.Fprintf(os.Stderr, "[opencode2] construyendo imagen %s...\n", image)
		build := exec.Command("docker", "build", "-t", image, "-")
		build.Stdin = strings.NewReader(dockerfile)
		build.Stdout = nil
		if err := build.Run(); err != nil {
			fmt.Fprintln(os.Stderr, "ERROR:", err)
			os.Exit(1)
		}
	}

	if err := os.MkdirAll(data, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	// -t only when a real terminal is attached (TUI); `run` from scripts has no tty.
	ttyFlag := ""
	if fi, err := os.Stdin.Stat(); err == nil && fi.Mode()&os.ModeCharDevice != 0 {
		ttyFlag = "-t"
	}

	dockerArgs := []string{"docker", "run", "-i"}
	if ttyFlag != "" {
		dockerArgs = append(dockerArgs, ttyFlag)
	}
	dockerArgs = append(dockerArgs, "--rm",
		"-e", "OPENCODE_API_KEY="+os.Getenv("OPENCODE_API_KEY"),
		"-v", v1Cfg+":/root/.config/opencode/opencode.json:ro",
		"-v", data+":/root/.local/share/opencode:rw",
		image, "opencode2",
	)
	dockerArgs = append(dockerArgs, os.Args[1:]...)

	// Parity with bash `exec`: replace the process with docker.
	syscall.Exec("/usr/bin/docker", dockerArgs, os.Environ())
}
