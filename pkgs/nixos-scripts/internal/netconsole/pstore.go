package netconsole

import (
	"fmt"
)

type PstoreParams struct {
	AlwaysKmsgDump string
	PstoreDisable  string
}

var LivePstoreParams = PstoreParams{
	AlwaysKmsgDump: "/sys/module/printk/parameters/always_kmsg_dump",
	PstoreDisable:  "/sys/module/efi_pstore/parameters/pstore_disable",
}

func VerifyPstore(read func(path string) ([]byte, error), p PstoreParams) error {
	if err := checkBoolParam(read, p.AlwaysKmsgDump, true); err != nil {
		return err
	}
	return checkBoolParam(read, p.PstoreDisable, false)
}

func EnsurePstore(
	read func(string) ([]byte, error),
	write func(string, []byte) error,
	p PstoreParams,
) error {
	if err := ensureBoolParam(read, write, p.AlwaysKmsgDump, true); err != nil {
		return err
	}
	return ensureBoolParam(read, write, p.PstoreDisable, false)
}

func ensureBoolParam(
	read func(string) ([]byte, error),
	write func(string, []byte) error,
	path string,
	want bool,
) error {
	if err := checkBoolParam(read, path, want); err == nil {
		return nil
	}
	val := "0"
	if want {
		val = "1"
	}
	if err := write(path, []byte(val)); err != nil {
		return fmt.Errorf(
			"netconsole: pstore check: %s = wrong value, runtime write failed (%v); reboot to apply kernel params",
			path, err)
	}
	return checkBoolParam(read, path, want)
}

func checkBoolParam(read func(string) ([]byte, error), path string, want bool) error {
	raw, err := read(path)
	if err != nil {
		return fmt.Errorf("netconsole: pstore check: read %s: %w", path, err)
	}
	v := TrimParam(raw)
	got := v == "y" || v == "1"
	if got != want {
		return fmt.Errorf("netconsole: pstore check: %s = %q, want %v", path, v, want)
	}
	return nil
}
