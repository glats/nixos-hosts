//go:build linux

package main

import "syscall"

// bindIface returns a control function pinning the socket to the network
// interface — the syscall-level equivalent of `curl --interface <iface>`
// (curl uses SO_BINDTODEVICE for interface names). Unprivileged callers
// hit the same EPERM curl hits, surfacing as a FAILED probe.
func bindIface(dev string) func(network, address string, c syscall.RawConn) error {
	return func(network, address string, c syscall.RawConn) error {
		var err error
		c.Control(func(fd uintptr) {
			err = syscall.SetsockoptString(int(fd), syscall.SOL_SOCKET, syscall.SO_BINDTODEVICE, dev)
		})
		return err
	}
}
