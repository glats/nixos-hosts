//go:build !linux

package main

import "syscall"

// bindIface is a no-op on non-Linux (SO_BINDTODEVICE does not exist
// there); throughput probes run unbound.
func bindIface(string) func(network, address string, c syscall.RawConn) error {
	return nil
}
