package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

const (
	label = "org.nixos.sing-box"
	plist = "/Library/LaunchDaemons/" + label + ".plist"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: linkctl start|stop|restart|status")
	os.Exit(1)
}

func lc(suppressStderr bool, args ...string) (string, int) {
	c := exec.Command("launchctl", args...)
	var out strings.Builder
	c.Stdout = &out
	if suppressStderr {
		c.Stderr = nil
	} else {
		c.Stderr = &out
	}
	err := c.Run()
	rc := 0
	if exitErr, ok := err.(*exec.ExitError); ok {
		rc = exitErr.ExitCode()
	} else if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	return out.String(), rc
}

func printState() {
	out, _ := lc(true, "print", "system/"+label)
	if strings.TrimSpace(out) == "" {
		fmt.Printf("linkctl: %s stopped (booted out or never loaded since boot)\n", label)
		return
	}
	var lines []string
	hasPID := false
	for _, line := range strings.Split(out, "\n") {
		if strings.Contains(line, "state") || strings.Contains(line, "pid") {
			lines = append(lines, line)
			if strings.Contains(line, "pid") {
				hasPID = true
			}
		}
	}
	if len(lines) > 0 {
		fmt.Println(strings.Join(lines, "\n"))
	}
	if !hasPID {
		fmt.Printf("linkctl: %s registered, idle — run: linkctl start\n", label)
	}
}

func cmdStart() {
	if _, rc := lc(true, "print", "system/"+label); rc == 0 {
		if _, rc := lc(true, "kickstart", "system/"+label); rc != 0 {
			fmt.Fprintf(os.Stderr, "linkctl: kickstart failed for %s (sudo?)\n", label)
		}
	} else if _, rc := lc(true, "bootstrap", "system", plist); rc == 0 {
		if _, rc := lc(true, "kickstart", "system/"+label); rc != 0 {
			fmt.Fprintf(os.Stderr, "linkctl: kickstart failed for %s (sudo?)\n", label)
		}
	} else {
		fmt.Fprintf(os.Stderr, "linkctl: bootstrap failed for %s (sudo?)\n", plist)
	}
	printState()
}

func cmdStop() {
	out, rc := lc(false, "bootout", "system/"+label)
	combined := strings.ToLower(out)
	switch {
	case rc == 0:
		fmt.Printf("linkctl: %s booted out — TUN down, 100%% corporate path\n", label)
	case rc == 3 || strings.Contains(combined, "no such process") || strings.Contains(combined, "could not find service"):
		fmt.Printf("linkctl: %s already stopped (nothing running — corporate path active)\n", label)
	default:
		fmt.Fprintf(os.Stderr, "linkctl: bootout failed (rc=%d): %s\n", rc, strings.TrimSpace(out))
	}
}

func cmdRestart() {

	lc(true, "bootout", "system/"+label)
	if _, rc := lc(true, "bootstrap", "system", plist); rc == 0 {
		if _, rc := lc(true, "kickstart", "system/"+label); rc != 0 {
			fmt.Fprintf(os.Stderr, "linkctl: kickstart failed for %s (sudo?)\n", label)
		}
	} else {
		fmt.Fprintf(os.Stderr, "linkctl: bootstrap failed for %s (sudo?)\n", plist)
	}
	printState()
}

func main() {
	args := os.Args[1:]
	if len(args) != 1 {
		usage()
	}

	if os.Geteuid() != 0 && args[0] != "status" {
		self, err := os.Executable()
		if err != nil {
			fmt.Fprintln(os.Stderr, "ERROR:", err)
			os.Exit(1)
		}
		syscall.Exec("/usr/bin/sudo", []string{"sudo", self, args[0]}, os.Environ())
	}

	switch args[0] {
	case "start":
		cmdStart()
	case "stop":
		cmdStop()
	case "restart":
		cmdRestart()
	case "status":
		printState()
	default:
		usage()
	}
}
