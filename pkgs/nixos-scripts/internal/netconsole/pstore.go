package netconsole

import (
	"fmt"
)

// PstoreParams are the sysfs parameter paths the diagnostics gate verifies
// at startup: with printk.always_kmsg_dump=1 the kernel dumps the full kmsg
// buffer on shutdown/emergency paths, and efi_pstore.pstore_disable=N keeps
// the EFI pstore backend registered so those dumps survive the next boot
// (rog kernel: PSTORE=y, EFI_VARS_PSTORE=y, verified against 6.18.45).
type PstoreParams struct {
	AlwaysKmsgDump string // /sys/module/printk/parameters/always_kmsg_dump
	PstoreDisable  string // /sys/module/efi_pstore/parameters/pstore_disable
}

// LivePstoreParams is the production parameter path set.
var LivePstoreParams = PstoreParams{
	AlwaysKmsgDump: "/sys/module/printk/parameters/always_kmsg_dump",
	PstoreDisable:  "/sys/module/efi_pstore/parameters/pstore_disable",
}

// VerifyPstore returns nil only when persistent kmsg dumping is active:
// always_kmsg_dump enabled and efi_pstore not disabled. Values may be
// "Y"/"N" (kernel bool rendering) or "1"/"0". read is injectable so tests
// never touch the real sysfs tree; a read error (missing parameter) means
// the expected kernel configuration is absent and fails the check.
func VerifyPstore(read func(path string) ([]byte, error), p PstoreParams) error {
	if err := checkBoolParam(read, p.AlwaysKmsgDump, true); err != nil {
		return err
	}
	return checkBoolParam(read, p.PstoreDisable, false)
}

// checkBoolParam requires the parameter at path to be want ("1"/"y") or
// not-want ("0"/"n") respectively.
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
