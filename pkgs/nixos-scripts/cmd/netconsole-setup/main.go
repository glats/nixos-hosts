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
	timeout := flag.Duration("timeout", 2*time.Second, "ACK wait window per probe")
	attempts := flag.Int("probe-attempts", 5, "ACK probes before accepting a soft no-ACK")
	interval := flag.Duration("probe-interval", 5*time.Second, "sleep between ACK probes")
	flag.Parse()

	km := kmsg.New()
	target := netconsole.Target{
		Iface:      *iface,
		LocalPort:  *localPort,
		RemoteIP:   *remoteIP,
		RemoteMAC:  *remoteMAC,
		RemotePort: *remotePort,
	}

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

	acked, err := netconsole.VerifyRetries(km, conn, nonce, *timeout, *interval, *attempts, time.Sleep)
	if err != nil {
		fatal(km, err.Error())
	}
	if !acked {
		_ = km.Write(kmsg.UserWarning, netconsole.SetupNoACK(target, nonce, *attempts))
		log.Printf("%s", netconsole.SetupNoACK(target, nonce, *attempts))
		return
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
