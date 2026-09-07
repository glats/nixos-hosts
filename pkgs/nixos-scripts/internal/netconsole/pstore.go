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

// EnsurePstore verifies the pstore parameters and, when one is still at
// its default (kernel cmdline not applied yet — the boot right after
// switching the diagnostics gate on), attempts a runtime write before
// failing. Module bools are writable through sysfs, so this self-heal
// activates diagnostics on the switch that enables them instead of
// failing visibly until the next reboot. A write failure still fails
// closed: reboot to apply the kernel parameters. Both funcs are
// injectable so tests never touch the real sysfs tree.
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

// ensureBoolParam requires the parameter at path to be want ("1"/"y") or
// not-want ("0"/"n"); if it is not, a runtime write of the desired value
// is attempted and the parameter is re-read to confirm.
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
