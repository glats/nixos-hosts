// Command wg-peer manages declarative WireGuard peers on rog.
//
// Port of bin/wg-peer (list/add/remove/qr) and absorbs the retired
// generate-thinkpad-wireguard as the `generate` subcommand (now targeting
// the real module linux/system/services/network/wireguard.nix instead of
// the removed hosts/rog/services/wireguard.nix path).
//
// Peers are declarative in linux/system/services/network/wireguard.nix,
// between the wg-peer managed markers. New peers get no PSK (optional in wg).
// Client keys live in /etc/wireguard/keys/<name>.key; ready-to-import confs
// and QR PNGs land in /etc/wireguard/clients/.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/glats/nixos-scripts/internal/reporoot"
	"github.com/glats/nixos-scripts/internal/wg"
)

const (
	clientsDir = "/etc/wireguard/clients"
	keysDir    = "/etc/wireguard/keys"
	network    = "10.13.13"
)

const usageText = `wg-peer — manage WireGuard peers on rog from one command

Commands:
  wg-peer list            list peers (name, ip, key, last handshake)
  wg-peer add <name>      new peer: keypair + next free IP, rebuild, conf + QR
  wg-peer remove <name>   delete peer, rebuild, drop its conf/QR/key
  wg-peer qr <name>       reprint the QR of an existing peer
  wg-peer generate <endpoint>
                          fresh thinkpad keypair + conf, update its publicKey
                          (replaces generate-thinkpad-wireguard)

Peers are declarative in linux/system/services/network/wireguard.nix,
between the wg-peer managed markers. New peers get no PSK (optional in wg).
`

func die(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}

func needArg(sub string, args []string) string {
	if len(args) == 0 {
		fmt.Fprintf(os.Stderr, "usage: wg-peer %s <name>\n", sub)
		os.Exit(1)
	}
	return args[0]
}

func toolOr(name, fallback string) string {
	if p, err := exec.LookPath(name); err == nil {
		return p
	}
	return fallback
}

func main() {
	args := os.Args[1:]
	cmd := ""
	if len(args) > 0 {
		cmd = args[0]
		args = args[1:]
	}

	switch cmd {
	case "list":
		list()
	case "add":
		add(needArg("add", args))
	case "remove":
		remove(needArg("remove", args))
	case "qr":
		qr(needArg("qr", args))
	case "generate":
		generate(needArg("generate <endpoint>", args))
	case "help", "-h", "--help", "":
		fmt.Print(usageText)
		os.Exit(0)
	default:
		fmt.Fprint(os.Stderr, usageText)
		os.Exit(1)
	}
}

func modulePath() string {
	root, err := reporoot.Resolve()
	if err != nil {
		die("%v", err)
	}
	return filepath.Join(root, "linux", "system", "services", "network", "wireguard.nix")
}

func readModule(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		die("%v", err)
	}
	return string(b)
}

func writeModule(path, content string) {
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		die("%v", err)
	}
}

// runCmd executes a command with inherited stdio and dies on failure.
func runCmd(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		die("%s failed: %v", name, err)
	}
}

// capture runs a command and returns trimmed stdout.
func capture(name string, args ...string) string {
	out, err := exec.Command(name, args...).Output()
	if err != nil {
		die("%s failed: %v", name, err)
	}
	return strings.TrimSpace(string(out))
}

// rebuild runs the same gates as the bash original: fmt, flake check, switch.
func rebuild(module string, repo string) {
	runCmd("nix", "fmt", "--", module)
	flake := exec.Command("nix", "flake", "check", "--no-build")
	flake.Dir = repo
	flake.Stdout = os.Stdout
	flake.Stderr = os.Stderr
	if err := flake.Run(); err != nil {
		die("nix flake check failed: %v", err)
	}
	runCmd("nixos-build")
}

func list() {
	module := modulePath()
	content := readModule(module)
	peers, err := wg.ParsePeers(content)
	if err != nil {
		die("%v", err)
	}

	handshakes := map[string]string{}
	show, showErr := exec.Command("sudo", "-n", toolOr("wg", "/run/current-system/sw/bin/wg"), "show", "wg0").Output()
	if showErr == nil {
		handshakes = wg.ParseWGShowHandshakes(string(show))
	}

	fmt.Printf("%-16s %-13s %-48s %s\n", "NAME", "IP", "PUBLIC-KEY", "LAST-HANDSHAKE")
	for _, p := range peers {
		hs, ok := handshakes[p.PublicKey]
		if !ok {
			hs = "never"
		}
		fmt.Printf("%-16s %-13s %-48s %s\n", p.Name, p.IP, p.PublicKey, hs)
	}
}

func add(name string) {
	module := modulePath()
	repo, err := reporoot.Resolve()
	if err != nil {
		die("%v", err)
	}
	content := readModule(module)

	if !wg.PeerNameRe.MatchString(name) {
		die("invalid name '%s' (lowercase letters, digits and dashes only)", name)
	}
	if strings.Contains(content, "    "+name+" = {") {
		die("peer '%s' already exists", name)
	}
	if !wg.HasMarkers(content) {
		die("wg-peer markers missing in wireguard.nix")
	}

	ip, err := wg.NextIP(content, network)
	if err != nil {
		die("%v", err)
	}

	wgBin := toolOr("wg", "/run/current-system/sw/bin/wg")
	priv := capture(wgBin, "genkey")
	pubCmd := exec.Command(wgBin, "pubkey")
	pubCmd.Stdin = strings.NewReader(priv + "\n")
	pubOut, err := pubCmd.Output()
	if err != nil {
		die("wg pubkey failed: %v", err)
	}
	pub := strings.TrimSpace(string(pubOut))

	out, err := wg.InsertPeer(content, name, ip, pub)
	if err != nil {
		die("%v", err)
	}
	writeModule(module, out)

	// Store the client private key BEFORE the rebuild so the activation
	// script emits a ready-to-import conf.
	priv = strings.TrimRight(priv, "\n")
	if err := exec.Command("sudo", "mkdir", "-p", keysDir).Run(); err != nil {
		die("mkdir %s: %v", keysDir, err)
	}
	tee := exec.Command("sudo", "tee", filepath.Join(keysDir, name+".key"))
	tee.Stdin = strings.NewReader(priv + "\n")
	tee.Stdout = nil
	if err := tee.Run(); err != nil {
		die("storing key: %v", err)
	}
	if err := exec.Command("sudo", "chmod", "600", filepath.Join(keysDir, name+".key")).Run(); err != nil {
		die("chmod key: %v", err)
	}

	// Rebuild: conf lands in /etc/wireguard/clients with the real key.
	rebuild(module, repo)

	// QR PNG next to the conf + print QR to the terminal.
	qrencode := toolOr("qrencode", "/etc/profiles/per-user/glats/bin/qrencode")
	confPath := filepath.Join(clientsDir, name+".conf")
	pngPath := filepath.Join(clientsDir, name+".png")
	if err := exec.Command("sudo", qrencode, "-t", "PNG", "-s", "8", "-m", "2", "-o", pngPath, confPath).Run(); err != nil {
		die("qrencode PNG: %v", err)
	}
	if err := exec.Command("sudo", "chmod", "600", pngPath).Run(); err != nil {
		die("chmod png: %v", err)
	}

	fmt.Printf("peer '%s' added (%s)\n", name, ip)
	fmt.Printf("config: %s\n", confPath)
	fmt.Println()
	printQR(confPath, qrencode)
}

func remove(name string) {
	module := modulePath()
	repo, err := reporoot.Resolve()
	if err != nil {
		die("%v", err)
	}
	content := readModule(module)

	if !strings.Contains(content, "    "+name+" = {") {
		die("peer '%s' not found", name)
	}

	out, removed := wg.RemovePeer(content, name)
	if !removed {
		die("peer '%s' not found", name)
	}
	writeModule(module, out)

	rebuild(module, repo)

	for _, f := range []string{
		filepath.Join(clientsDir, name+".conf"),
		filepath.Join(clientsDir, name+".png"),
		filepath.Join(keysDir, name+".key"),
	} {
		if err := exec.Command("sudo", "rm", "-f", f).Run(); err != nil {
			die("rm %s: %v", f, err)
		}
	}
	fmt.Printf("peer '%s' removed\n", name)
}

func qr(name string) {
	conf := filepath.Join(clientsDir, name+".conf")
	if err := exec.Command("sudo", "test", "-f", conf).Run(); err != nil {
		die("no config for '%s' in %s", name, clientsDir)
	}
	printQR(conf, toolOr("qrencode", "/etc/profiles/per-user/glats/bin/qrencode"))
}

// printQR reads the conf via sudo and pipes it into qrencode's ANSIUTF8
// terminal renderer, matching `sudo cat conf | qrencode -t ANSIUTF8 -s 2 -m 1`.
func printQR(conf, qrencode string) {
	cat := exec.Command("sudo", "cat", conf)
	qr := exec.Command(qrencode, "-t", "ANSIUTF8", "-s", "2", "-m", "1")
	qr.Stdin, _ = cat.StdoutPipe()
	qr.Stdout = os.Stdout
	qr.Stderr = os.Stderr
	if err := qr.Start(); err != nil {
		die("qrencode: %v", err)
	}
	if err := cat.Run(); err != nil {
		die("reading %s: %v", conf, err)
	}
	if err := qr.Wait(); err != nil {
		die("qrencode: %v", err)
	}
}

// generate ports bin/generate-thinkpad-wireguard: fresh thinkpad client
// keypair + conf, then updates the thinkpad publicKey in the module. The
// retired script edited the dead path hosts/rog/services/wireguard.nix;
// this port targets the real managed module.
func generate(endpoint string) {
	repo, err := reporoot.Resolve()
	if err != nil {
		die("%v", err)
	}
	module := filepath.Join(repo, "linux", "system", "services", "network", "wireguard.nix")
	sopsFile := filepath.Join(repo, "secrets", "host", "rog", "wireguard.yaml")
	wgBin := toolOr("wg", "/run/current-system/sw/bin/wg")

	sopsExtract := func(field string) string {
		out, err := exec.Command("sops", "-d", "--extract",
			`["wireguard"]["`+field+`"]`, sopsFile).Output()
		if err != nil {
			die("sops decrypt %s: %v", field, err)
		}
		return strings.TrimSpace(string(out))
	}

	fmt.Println("> Decrypting server private key...")
	serverPriv := sopsExtract("server_private_key")
	pubCmd := exec.Command(wgBin, "pubkey")
	pubCmd.Stdin = strings.NewReader(serverPriv + "\n")
	serverPub, err := pubCmd.Output()
	if err != nil {
		die("wg pubkey failed: %v", err)
	}

	fmt.Println("> Decrypting thinkpad preshared key...")
	thinkpadPSK := sopsExtract("peer_thinkpad_psk")

	fmt.Println("> Generating fresh client keypair...")
	clientPriv := capture(wgBin, "genkey")
	clientPubCmd := exec.Command(wgBin, "pubkey")
	clientPubCmd.Stdin = strings.NewReader(clientPriv + "\n")
	clientPub, err := clientPubCmd.Output()
	if err != nil {
		die("wg pubkey failed: %v", err)
	}

	outputFile := "thinkpad-wireguard.conf"
	conf := fmt.Sprintf(`[Interface]
Address = 10.13.13.4/32
PrivateKey = %s
DNS = 10.13.13.1

[Peer]
PublicKey = %s
PresharedKey = %s
AllowedIPs = 10.13.13.0/24
Endpoint = %s:51820
PersistentKeepalive = 25
`,
		strings.TrimSpace(string(clientPriv)),
		strings.TrimSpace(string(serverPub)),
		thinkpadPSK,
		endpoint,
	)
	if err := os.WriteFile(outputFile, []byte(conf), 0o600); err != nil {
		die("writing %s: %v", outputFile, err)
	}
	fmt.Printf("> Created: %s\n", outputFile)

	fmt.Printf("> Updating thinkpad public key in %s...\n", module)
	content := readModule(module)
	updated, ok := wg.UpdatePeerPublicKey(content, "thinkpad", strings.TrimSpace(string(clientPub)))
	if !ok {
		die("thinkpad peer not found in %s", module)
	}
	writeModule(module, updated)

	host := capture("hostname")
	fmt.Println()
	fmt.Println("=== Ready ===")
	fmt.Println()
	fmt.Println("  1. Copy this file to the thinkpad and import:")
	fmt.Printf("     scp %s thinkpad:/etc/wireguard/wg0.conf\n", outputFile)
	fmt.Println()
	fmt.Println("  2. On the thinkpad, start the tunnel:")
	fmt.Println("     sudo wg-quick up wg0")
	fmt.Println()
	fmt.Println("  3. Rebuild rog with new public key:")
	fmt.Printf("     sudo nixos-rebuild switch --flake '/etc/nixos#%s'\n", host)
	fmt.Println()
	fmt.Println("  4. Verify connection:")
	fmt.Println("     sudo wg show")
}
