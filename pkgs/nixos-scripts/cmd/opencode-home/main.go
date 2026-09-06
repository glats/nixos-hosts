// Command opencode-home is the scoped proxy launcher for OpenCode on mact2.
//
// Port of bin/opencode-home. Exports HTTPS_PROXY/HTTP_PROXY pointing at the
// sing-box loopback mixed inbound (127.0.0.1:2080) ONLY while that inbound
// is listening, then execs opencode with all arguments. With the link down,
// opencode runs WITHOUT proxy vars after a stderr notice.
//
// Never export these variables in shell profiles — this launcher is the
// ONLY path that sets them (MCP children are scrubbed via mcp.environment
// in the generated opencode.json).
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

const (
	linkHost = "127.0.0.1"
	linkPort = "2080"
)

func main() {
	// Probe before exporting: -z = connect-only scan, -w 1 = 1s cap so a
	// wedged listener cannot stall the launch. BSD nc (macOS) supports both.
	probe := exec.Command("nc", "-z", "-w", "1", linkHost, linkPort)
	if err := probe.Run(); err == nil {
		proxy := "http://" + linkHost + ":" + linkPort
		os.Setenv("HTTPS_PROXY", proxy)
		os.Setenv("HTTP_PROXY", proxy)
	} else {
		fmt.Fprintf(os.Stderr, "opencode-home: %s:%s not listening — launching opencode WITHOUT proxy env\n", linkHost, linkPort)
	}

	// exec opencode with the current environment (including any proxy vars
	// just set) — bash `exec opencode "$@"` equivalent.
	bin, err := exec.LookPath("opencode")
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(127)
	}
	args := append([]string{"opencode"}, os.Args[1:]...)
	if err := syscall.Exec(bin, args, os.Environ()); err != nil {
		// Some environments restrict exec; fall back to run-and-exit with
		// the same exit code semantics.
		if strings.Contains(err.Error(), "permission denied") {
			fmt.Fprintln(os.Stderr, "ERROR:", err)
			os.Exit(126)
		}
		c := exec.Command(bin, os.Args[1:]...)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		c.Stdin = os.Stdin
		if err := c.Run(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				os.Exit(exitErr.ExitCode())
			}
			fmt.Fprintln(os.Stderr, "ERROR:", err)
			os.Exit(1)
		}
		os.Exit(0)
	}
}
