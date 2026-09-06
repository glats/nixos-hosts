// Command netdiag prints a network diagnostic snapshot for multi-NIC
// Realtek hosts (r8169 debugging on t14), or monitors in watch mode and
// re-prints the snapshot whenever RX throughput degrades.
//
// Port of bin/netdiag: sections, messages, colors and exit codes
// preserved byte-for-byte.
//
// Improvements over the bash original (runtime tools eliminated):
//   - bc: all throughput arithmetic (bytes/s → MB/s, the 50 MB/s
//     threshold compare) is done in pure Go, matching bc's scale=1
//     truncation (floor at one decimal, not rounding).
//   - curl: the per-NIC Cloudflare throughput probe uses net/http with
//     the same semantics — 10s cap (--max-time 10) and the same
//     per-interface pinning (curl --interface <iface> resolves to
//     SO_BINDTODEVICE, reproduced in ifbind_linux.go). Non-Linux builds
//     probe unbound. HTTP status is ignored like bare curl (no --fail),
//     so error-page bodies still count as downloaded bytes.
//
// Tools still exec'd exactly where the bash original did: ip, ping,
// sudo+ethtool, resolvectl (optional), nmcli (optional). bc and curl are
// no longer needed.
//
// Faithfully-replicated pipefail quirks: the bash script runs under
// `set -euo pipefail`, so a grep that matches nothing in a pipeline
// silently kills the script with exit 1 (routing table, Tcp lines,
// ethtool driver lines, resolv.conf/nmcli fallbacks). Those silent
// deaths are reproduced via pipefailDie() to keep behavior identical.
package main

import (
	"bytes"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Interfaces probed with privileged/system tools (hardcoded in bash too).
var probedIfaces = []string{"enp2s0f0", "enp5s0"}

// ANSI colors from the bash header, byte-identical.
const (
	red    = "\x1b[0;31m"
	green  = "\x1b[0;32m"
	yellow = "\x1b[1;33m"
	nc     = "\x1b[0m"
)

// Line filters ported from the bash greps.
var (
	routeRe    = regexp.MustCompile(`default|172\.`)                 // grep -E 'default|172\.'
	ethtoolIRe = regexp.MustCompile(`driver|firmware|bus`)           // grep -E 'driver|firmware|bus'
	ethtoolSRe = regexp.MustCompile(`(?i)err|drop|discard|fail|crc`) // grep -iE
	snmpPrefix = "Tcp:"                                              // grep -E '^Tcp:'
)

const banner = "══════════════════════════════════════════════"

func header(name string) {
	fmt.Printf("\n%s=== %s ===%s\n", yellow, name, nc)
}

func metricOk(label, val string) {
	fmt.Printf("  %s✔%s %-35s %s\n", green, nc, label, val)
}

func metricWarn(label, val string) {
	fmt.Printf("  %s✘%s %-35s %s\n", red, nc, label, val)
}

// pipefailDie replicates the bash original's `set -euo pipefail` death:
// a grep with no matches in a pipeline silently terminates the script
// with exit 1 — no message, no extra output.
func pipefailDie() {
	os.Exit(1)
}

// readSys reads a sysfs/procfs value like `$(cat path 2>/dev/null || echo
// fallback)`: trailing newlines are stripped, read errors yield fallback.
func readSys(path, fallback string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return fallback
	}
	return strings.TrimRight(string(b), "\n")
}

// filterLines returns the lines of s matching re, fed through the same
// shape the bash while-loops consumed: `read -r line` strips leading and
// trailing IFS (space/tab) whitespace from every line.
func filterLines(s string, re *regexp.Regexp) []string {
	var out []string
	for _, line := range strings.Split(strings.TrimRight(s, "\n"), "\n") {
		line = strings.Trim(line, " \t")
		if re.MatchString(line) {
			out = append(out, line)
		}
	}
	return out
}

// lastLine ports `... | tail -1`: the final line of out, dropping one
// trailing newline; empty input yields an empty line.
func lastLine(out string) string {
	s := strings.TrimSuffix(out, "\n")
	if s == "" {
		return ""
	}
	if i := strings.LastIndex(s, "\n"); i >= 0 {
		return s[i+1:]
	}
	return s
}

// needsSudo ports needs_sudo(): root, or a passwordless `sudo -n true`.
func needsSudo() bool {
	if os.Geteuid() == 0 {
		return true
	}
	return exec.Command("sudo", "-n", "true").Run() == nil
}

// ifaceState reads an interface operstate with no fallback (bash: bare
// `$(cat ... 2>/dev/null)` → empty string on error).
func ifaceState(iface string) string {
	return readSys("/sys/class/net/"+iface+"/operstate", "")
}

func captureSnapshot() {
	ts := time.Now().Format("2006-01-02 15:04:05")

	fmt.Println()
	fmt.Println(banner)
	fmt.Println("  NETWORK DIAGNOSTIC — " + ts)
	fmt.Println(banner)

	// ── ROUTING ──────────────────────────────────
	header("ROUTING TABLE")
	routeOut, err := func() (string, error) {
		cmd := exec.Command("ip", "route", "show")
		var out bytes.Buffer
		cmd.Stdout = &out
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		return out.String(), err
	}()
	routes := filterLines(routeOut, routeRe)
	if err != nil || len(routes) == 0 {
		pipefailDie()
	}
	for _, line := range routes {
		metricOk("route", line)
	}

	// ── INTERFACE STATUS ─────────────────────────
	header("INTERFACE STATUS")
	for _, iface := range globIfaces() {
		name := filepath.Base(iface)
		operstate := readSys(iface+"/operstate", "unknown")
		speed := readSys(iface+"/speed", "N/A")
		mtu := readSys(iface+"/mtu", "N/A")
		fmt.Printf("  %s: state=%-5s speed=%-4s mtu=%-5s\n", name, operstate, speed+"Mb/s", mtu)
	}

	// ── INTERFACE ERRORS (cumulative) ────────────
	header("INTERFACE ERRORS (cumulative)")
	for _, iface := range globIfaces() {
		name := filepath.Base(iface)
		s := iface + "/statistics"
		fmt.Printf("  %s: rx_err=%-6s rx_drop=%-6s tx_err=%-6s tx_drop=%-6s\n",
			name,
			readSys(s+"/rx_errors", "N/A"),
			readSys(s+"/rx_dropped", "N/A"),
			readSys(s+"/tx_errors", "N/A"),
			readSys(s+"/tx_dropped", "N/A"))
	}

	// ── NAPI COALESCING ──────────────────────────
	header("NAPI INTERRUPT COALESCING")
	for _, iface := range globIfaces() {
		name := filepath.Base(iface)
		napi := readSys(iface+"/napi_defer_hard_irqs", "N/A")
		flush := readSys(iface+"/gro_flush_timeout", "N/A")
		if napi == "0" {
			metricOk(name+" napi_defer", napi+"  (correct)")
		} else {
			metricWarn(name+" napi_defer", napi+"  (should be 0!)")
		}
		metricOk(name+" gro_flush", flush)
	}

	// ── RP_FILTER ────────────────────────────────
	header("REVERSE PATH FILTER")
	for _, path := range globFiles("/proc/sys/net/ipv4/conf/enp*/rp_filter") {
		name := filepath.Base(filepath.Dir(path))
		val := readSys(path, "")
		if val == "1" || val == "0" {
			metricOk(name+" rp_filter", val+"  (loose/off)")
		} else {
			metricWarn(name+" rp_filter", val+"  (strict — drops packets on multi-homed!)")
		}
	}

	// ── TCP RETRANSMISSIONS ──────────────────────
	header("TCP RETRANSMITS (since boot)")
	if _, err := os.Stat("/proc/net/snmp"); err == nil {
		b, _ := os.ReadFile("/proc/net/snmp")
		var tcpLines []string
		for _, line := range strings.Split(strings.TrimRight(string(b), "\n"), "\n") {
			line = strings.Trim(line, " \t") // `read -r` semantics
			if strings.HasPrefix(line, snmpPrefix) {
				tcpLines = append(tcpLines, line)
			}
		}
		if len(tcpLines) == 0 {
			pipefailDie()
		}
		for _, line := range tcpLines {
			fmt.Println("  " + line)
		}
	}

	// ── THROUGHPUT TEST (quick, per NIC) ─────────
	header("THROUGHPUT TEST (Cloudflare 25MB, per NIC)")
	for _, iface := range probedIfaces {
		if ifaceState(iface) != "up" {
			fmt.Printf("  %s: DOWN — skipping\n", iface)
			continue
		}
		speed := throughputProbe(iface)
		if speed == 0 {
			metricWarn(iface+" throughput", "FAILED")
			continue
		}
		mbs := bcScale1(speed / 1048576)
		if speed < 50000000 {
			metricWarn(iface+" throughput", mbs+" MB/s  (bajo!)")
		} else {
			metricOk(iface+" throughput", mbs+" MB/s")
		}
	}

	// ── LATENCY ──────────────────────────────────
	header("LATENCY (1.1.1.1, per NIC)")
	for _, iface := range probedIfaces {
		if ifaceState(iface) != "up" {
			fmt.Printf("  %s: DOWN — skipping\n", iface)
			continue
		}
		out, _ := exec.Command("ping", "-c", "3", "-W", "2", "-I", iface, "1.1.1.1").CombinedOutput()
		fmt.Printf("  %s: %s\n", iface, lastLine(string(out)))
	}

	// ── ETHTOOL (sudo) ────────────────────────────
	if needsSudo() {
		header("ETHTOOL DRIVER INFO")
		for _, iface := range probedIfaces {
			out, _ := exec.Command("sudo", "ethtool", "-i", iface).Output()
			lines := filterLines(string(out), ethtoolIRe)
			if len(lines) == 0 {
				pipefailDie()
			}
			for _, line := range lines {
				fmt.Printf("  %s: %s\n", iface, line)
			}
		}

		header("ETHTOOL STATISTICS (errors only)")
		for _, iface := range probedIfaces {
			out, _ := exec.Command("sudo", "ethtool", "-S", iface).Output()
			et := filterLines(string(out), ethtoolSRe)
			if len(et) > 0 {
				fmt.Printf("  %s:\n", iface)
				for _, line := range et {
					fmt.Printf("    %s\n", line)
				}
			}
		}
	} else {
		fmt.Println()
		fmt.Println("  ⚠ sudo not available — skipping ethtool stats.")
		fmt.Println("  Run with: sudo netdiag")
	}

	// ── DNS ──────────────────────────────────────
	header("DNS RESOLUTION")
	if _, err := exec.LookPath("resolvectl"); err == nil {
		out, _ := exec.Command("resolvectl", "status").Output()
		lines := strings.Split(strings.TrimRight(string(out), "\n"), "\n")
		if len(lines) == 1 && lines[0] == "" {
			lines = nil
		}
		if len(lines) > 10 {
			lines = lines[:10]
		}
		for _, line := range lines {
			fmt.Println(line)
		}
	} else {
		b, _ := os.ReadFile("/etc/resolv.conf")
		var lines []string
		for _, line := range strings.Split(strings.TrimRight(string(b), "\n"), "\n") {
			if strings.HasPrefix(line, "#") || line == "" {
				continue
			}
			lines = append(lines, line)
		}
		if len(lines) == 0 {
			pipefailDie()
		}
		for _, line := range lines {
			fmt.Println(line)
		}
	}

	// ── NM CONNECTIONS ───────────────────────────
	header("NETWORKMANAGER ACTIVE CONNECTIONS")
	if _, err := exec.LookPath("nmcli"); err == nil {
		out, _ := exec.Command("nmcli", "-t", "-f", "DEVICE,TYPE,STATE,IP4.ADDRESS", "device", "status").Output()
		var lines []string
		for _, line := range strings.Split(strings.TrimRight(string(out), "\n"), "\n") {
			if line == "" {
				continue
			}
			lines = append(lines, line)
		}
		if len(lines) == 0 {
			pipefailDie()
		}
		for _, line := range lines {
			fmt.Println(line)
		}
	}

	fmt.Println()
	fmt.Println(banner)
	fmt.Println("  DIAGNOSTIC COMPLETE — " + ts)
	fmt.Println(banner)
}

// globIfaces returns the /sys/class/net/enp* directories (bash iterates
// the glob and skips non-directories; the entries are symlinks to the
// device dirs, so the check follows links like bash `[ -d ]`).
func globIfaces() []string {
	matches, err := filepath.Glob("/sys/class/net/enp*")
	if err != nil {
		return nil
	}
	var out []string
	for _, m := range matches {
		if fi, err := os.Stat(m); err == nil && fi.IsDir() {
			out = append(out, m)
		}
	}
	return out
}

// globFiles is bash globbing plus a `[ -f ]` check (symlinks followed):
// only existing regular files are returned.
func globFiles(pattern string) []string {
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return nil
	}
	var out []string
	for _, m := range matches {
		if fi, err := os.Stat(m); err == nil && fi.Mode().IsRegular() {
			out = append(out, m)
		}
	}
	return out
}

// throughputProbe measures download bytes/sec like
//
//	curl -s -o /dev/null -w '%{speed_download}' --interface IFACE
//	     --max-time 10 'https://speed.cloudflare.com/__down?bytes=25000000'
//
// 0 means failure (the bash `|| echo 0` path → "FAILED").
func throughputProbe(iface string) float64 {
	const url = "https://speed.cloudflare.com/__down?bytes=25000000"
	dialer := &net.Dialer{Timeout: 10 * time.Second}
	if ctl := bindIface(iface); ctl != nil {
		dialer.Control = ctl
	}
	client := &http.Client{
		Timeout:   10 * time.Second, // curl --max-time 10
		Transport: &http.Transport{DialContext: dialer.DialContext},
	}
	start := time.Now()
	resp, err := client.Get(url)
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	n, err := io.Copy(io.Discard, resp.Body)
	if err != nil {
		return 0
	}
	elapsed := time.Since(start).Seconds()
	if elapsed <= 0 {
		return 0
	}
	return float64(n) / elapsed
}

// bcScale1 renders v like `echo "scale=1; $v" | bc`: truncated (not
// rounded) to one decimal.
func bcScale1(v float64) string {
	return fmt.Sprintf("%.1f", math.Trunc(v*10)/10)
}

func watchMode(interval int) {
	fmt.Printf("⏱  netdiag — watch mode (interval=%ds)\n", interval)
	fmt.Println("   Press Ctrl+C to stop.")
	fmt.Println()

	// Baseline: run once and store RX bytes.
	prevRx := map[string]int64{}
	for _, path := range globFiles("/sys/class/net/enp*/statistics/rx_bytes") {
		name := filepath.Base(filepath.Dir(filepath.Dir(path)))
		prevRx[name] = readSysInt(path, 0)
	}

	prevTime := time.Now().Unix()
	degradation := 0

	for {
		time.Sleep(time.Duration(interval) * time.Second)

		now := time.Now().Unix()
		elapsed := now - prevTime
		if elapsed < 1 {
			elapsed = 1
		}

		for _, path := range globFiles("/sys/class/net/enp*/statistics/rx_bytes") {
			name := filepath.Base(filepath.Dir(filepath.Dir(path)))
			curr := readSysInt(path, 0)
			diff := curr - prevRx[name]
			rate := diff / elapsed

			// Flag if rate drops below 1 MB/s while interface is up.
			if ifaceState(name) == "up" && rate < 1048576 {
				degradation = 1
			}

			prevRx[name] = curr
		}

		if degradation == 1 {
			captureSnapshot()
			degradation = 0
		}

		prevTime = now
	}
}

// readSysInt reads a counter file like `$(cat)` in bash arithmetic:
// unreadable → 0 (empty expansion evaluates as 0 in $(( ))).
func readSysInt(path string, fallback int64) int64 {
	b, err := os.ReadFile(path)
	if err != nil {
		return fallback
	}
	v, err := strconv.ParseInt(strings.TrimRight(string(b), "\n"), 10, 64)
	if err != nil {
		return 0
	}
	return v
}

func main() {
	// WATCH_INTERVAL="${1:-0}"; if [ "$WATCH_INTERVAL" = "--watch" ];
	// then WATCH_INTERVAL="${2:-5}"; fi
	watchInterval := ""
	args := os.Args[1:]
	if len(args) >= 1 {
		watchInterval = args[0]
	}
	if len(args) >= 1 && args[0] == "--watch" {
		watchInterval = "5"
		if len(args) >= 2 {
			watchInterval = args[1]
		}
	}

	// [ "$WATCH_INTERVAL" -gt 0 ] 2>/dev/null — a non-integer or
	// non-positive value falls through to a single snapshot.
	n, err := strconv.Atoi(watchInterval)
	if err == nil && n > 0 {
		watchMode(n)
	} else {
		captureSnapshot()
	}
}
