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

var probedIfaces = []string{"enp2s0f0", "enp5s0"}

const (
	red    = "\x1b[0;31m"
	green  = "\x1b[0;32m"
	yellow = "\x1b[1;33m"
	nc     = "\x1b[0m"
)

var (
	routeRe    = regexp.MustCompile(`default|172\.`)
	ethtoolIRe = regexp.MustCompile(`driver|firmware|bus`)
	ethtoolSRe = regexp.MustCompile(`(?i)err|drop|discard|fail|crc`)
	snmpPrefix = "Tcp:"
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

func pipefailDie() {
	os.Exit(1)
}

func readSys(path, fallback string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return fallback
	}
	return strings.TrimRight(string(b), "\n")
}

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

func needsSudo() bool {
	if os.Geteuid() == 0 {
		return true
	}
	return exec.Command("sudo", "-n", "true").Run() == nil
}

func ifaceState(iface string) string {
	return readSys("/sys/class/net/"+iface+"/operstate", "")
}

func captureSnapshot() {
	ts := time.Now().Format("2006-01-02 15:04:05")

	fmt.Println()
	fmt.Println(banner)
	fmt.Println("  NETWORK DIAGNOSTIC — " + ts)
	fmt.Println(banner)

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

	header("INTERFACE STATUS")
	for _, iface := range globIfaces() {
		name := filepath.Base(iface)
		operstate := readSys(iface+"/operstate", "unknown")
		speed := readSys(iface+"/speed", "N/A")
		mtu := readSys(iface+"/mtu", "N/A")
		fmt.Printf("  %s: state=%-5s speed=%-4s mtu=%-5s\n", name, operstate, speed+"Mb/s", mtu)
	}

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

	header("TCP RETRANSMITS (since boot)")
	if _, err := os.Stat("/proc/net/snmp"); err == nil {
		b, _ := os.ReadFile("/proc/net/snmp")
		var tcpLines []string
		for _, line := range strings.Split(strings.TrimRight(string(b), "\n"), "\n") {
			line = strings.Trim(line, " \t")
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

	header("LATENCY (1.1.1.1, per NIC)")
	for _, iface := range probedIfaces {
		if ifaceState(iface) != "up" {
			fmt.Printf("  %s: DOWN — skipping\n", iface)
			continue
		}
		out, _ := exec.Command("ping", "-c", "3", "-W", "2", "-I", iface, "1.1.1.1").CombinedOutput()
		fmt.Printf("  %s: %s\n", iface, lastLine(string(out)))
	}

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

func throughputProbe(iface string) float64 {
	const url = "https://speed.cloudflare.com/__down?bytes=25000000"
	dialer := &net.Dialer{Timeout: 10 * time.Second}
	if ctl := bindIface(iface); ctl != nil {
		dialer.Control = ctl
	}
	client := &http.Client{
		Timeout:   10 * time.Second,
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

func bcScale1(v float64) string {
	return fmt.Sprintf("%.1f", math.Trunc(v*10)/10)
}

func watchMode(interval int) {
	fmt.Printf("⏱  netdiag — watch mode (interval=%ds)\n", interval)
	fmt.Println("   Press Ctrl+C to stop.")
	fmt.Println()

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

	n, err := strconv.Atoi(watchInterval)
	if err == nil && n > 0 {
		watchMode(n)
	} else {
		captureSnapshot()
	}
}
