//go:build !linux

package main

import "syscall"

func bindIface(string) func(network, address string, c syscall.RawConn) error {
	return nil
}
