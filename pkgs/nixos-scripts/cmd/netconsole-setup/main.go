// Command netconsole-setup is the rog-side netconsole readiness probe run
// by the netconsole-setup oneshot unit at boot:
//
//  1. verifies the diagnostics-gate kernel state (always_kmsg_dump on,
//     efi_pstore not disabled),
//  2. reads the CURRENT IPv4 of the configured interface (runtime DHCP,
//     never a fixed source IP),
//  3. writes the configfs netconsole target (dev_name, local_ip,
//     local_port, remote_ip, remote_mac, remote_port, enabled last),
//  4. emits the nonce probe "netconsole-verify: nonce=<token>" to
//     /dev/kmsg, binds UDP :6665 and waits up to 2s for the receiver's
//     matching "netconsole-ack" (contract in internal/netconsole).
//
// Any failure exits nonzero (plus a /dev/kmsg breadcrumb) so the unit is
// visibly failed. All logic lives in internal/netconsole and is covered by
// unit tests; this entry only parses flags and dispatches.
package main

import (
	"flag"
	"log"
	"net"
	"os"
	"time"

	"github.com/glats/nixos-scripts/internal/kmsg"
	"github.com/glats/nixos-scripts/internal/netconsole"
)

func main() {
	iface := flag.String("interface", "enp3s0", "interface whose current IPv4 is the netconsole source")
	localPort := flag.Int("local-port", 6665, "UDP source port to bind (the ACK return port)")
	remoteIP := flag.String("remote-ip", "172.16.0.11", "receiver address")
	remoteMAC := flag.String("remote-mac", "6c:4b:90:2d:97:42", "receiver MAC")
	remotePort := flag.Int("remote-port", 6666, "receiver UDP port")
	configfs := flag.String("configfs", "/sys/kernel/config/netconsole", "configfs netconsole root")
	timeout := flag.Duration("timeout", 2*time.Second, "ACK wait window")
	flag.Parse()

	km := kmsg.New()
	target := netconsole.Target{
		Iface:      *iface,
		LocalPort:  *localPort,
		RemoteIP:   *remoteIP,
		RemoteMAC:  *remoteMAC,
		RemotePort: *remotePort,
	}

	// Diagnostics-gate check first: without persistent kmsg dumping the
	// pstore half of the evidence chain is missing, so fail fast. The
	// check self-heals via runtime sysfs writes when the kernel cmdline
	// has not been applied yet (first boot after switching the gate on).
	if err := netconsole.EnsurePstore(os.ReadFile,
		func(path string, val []byte) error {
			return os.WriteFile(path, val, 0o644)
		}, netconsole.LivePstoreParams); err != nil {
		fatal(km, "pstore check failed: "+err.Error())
	}

	src, err := netconsole.IPv4Of(listAddrs, *iface)
	if err != nil {
		fatal(km, err.Error())
	}

	// Bind the ACK socket before emitting the probe: the receiver replies
	// to the datagram's source port, so :6665 must already be listening.
	conn, err := net.ListenUDP("udp", &net.UDPAddr{Port: *localPort})
	if err != nil {
		fatal(km, err.Error())
	}
	defer conn.Close()

	fs := &netconsole.OsConfigFS{Root: *configfs}
	if err := netconsole.ConfigureTarget(fs, target, src); err != nil {
		fatal(km, err.Error())
	}

	nonce, err := netconsole.NewNonce()
	if err != nil {
		fatal(km, err.Error())
	}
	_ = km.Write(kmsg.UserNotice, "netconsole-setup: start "+netconsole.SetupStatus(target, src, "pending"))

	if err := netconsole.Verify(km, conn, nonce, *timeout); err != nil {
		fatal(km, err.Error())
	}

	_ = km.Write(kmsg.UserNotice, netconsole.SetupStatus(target, src, nonce))
	log.Printf("netconsole-setup: target1 ready %s", netconsole.SetupStatus(target, src, nonce))
}

func fatal(km *kmsg.Writer, msg string) {
	_ = km.Write(kmsg.UserWarning, "netconsole-setup: FAILED: "+msg)
	log.Fatalf("netconsole-setup: %s", msg)
}

func listAddrs(name string) ([]net.Addr, error) {
	i, err := net.InterfaceByName(name)
	if err != nil {
		return nil, err
	}
	return i.Addrs()
}
