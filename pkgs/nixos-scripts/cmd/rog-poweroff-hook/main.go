// Command rog-poweroff-hook performs the firmware-derived S5 poweroff for
// rog (ASUS GL553VD) from the systemd shutdown ramfs, plus the boot-time
// staging of the validated values it needs.
//
// It is wired by linux/system/hardware/rog-poweroff.nix:
//
//	stage    — a boot-time oneshot unit (rog-poweroff-stage.service) parses
//	           /sys/firmware/acpi/tables/{FACP,DSDT} + live DMI, validates,
//	           and writes the staged JSON (derived values + gate flag, NO
//	           raw tables) to /run/rog-poweroff/staged.json. /run is
//		   bind-transferred into the shutdown ramfs by systemd's
//		   switch_root, so the file is readable at hook time. Any
//	           refusal exits nonzero with a kmsg breadcrumb so the unit
//	           fails visibly.
//	poweroff — systemd-shutdown executes /etc/systemd/system-shutdown/* in
//	           the ramfs, right before the final reboot(RB_POWER_OFF). The
//	           hook re-validates (values + live DMI), then performs the
//	           16-bit read-modify-write of PM1a_CNT: replace SLP_TYP bits
//	           10-12 with the \_S5 value and set SLP_EN (bit 13). Machines
//	           on S5 do not return; if control DOES return, the hook
//	           breadcrumbs "s5-returned" for a bounded window — that is
//	           Gate-3 evidence — and lets the normal path continue.
//
// Context guard: systemd-shutdown runs the scripts twice (once pre-pivot
// from the old root, once again from the ramfs). The poweroff flow only
// runs in the ramfs context — detected via /oldroot, where switch_root
// parks the old root — so the write can never fire before the umount loop.
//
// Breadcrumbs (via /dev/kmsg, which is bind-transferred into the ramfs):
// "rog-s5: hook-start", "rog-s5: modules-state", "rog-s5: s5-attempt",
// "rog-s5: s5-refused" / "rog-s5: s5-returned", "rog-s5: hook-end".
// Every refusal exits 0 (never blocks shutdown); only stage failures are
// loud (exit 1).
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/kmsg"
	"github.com/glats/nixos-scripts/internal/s5write"
)

// Prefix for every breadcrumb this hook emits (design: "rog-s5:").
const prefix = "rog-s5:"

// oldRootPath is where systemd's switch_root parks the old root. A var so
// tests can point it at a temp directory instead of the real filesystem.
var oldRootPath = "/oldroot"

// staleJSONFallback is the pre-pivot fallback read for the staged JSON,
// relative to the old root.
func staleJSONFallback() string {
	return oldRootPath + "/run/rog-poweroff/staged.json"
}

// s5ReturnedWindow defaults for the bounded breadcrumb loop after a
// successful S5 write returns control (firmware should NOT return; if it
// does, the evidence interval is this long, then the normal poweroff path
// runs). Tests shrink them through deps.
const (
	defaultReturnedEvery = 5 * time.Second
	defaultReturnedMax   = 6
)

// deps collects everything run() needs from the environment so tests can
// inject fakes; production fills it with OS paths / the real register
// file.
type deps struct {
	km      *kmsg.Writer // kmsg device (breadcrumb sink)
	dmiDirs string       // sysfs dmi id directory ("" => production path)
	out     string       // where the staged JSON is written (stage verb)
	config  string       // where the staged JSON is read (poweroff verb)
	openRF  func() (s5write.RegisterFile, error)
	// s5-returned loop pacing (0 => production defaults).
	returnedEvery time.Duration
	returnedMax   int
}

// run executes verb and returns the process exit code.
func run(verb string, d deps, extraArgs []string) int {
	switch verb {
	case "stage":
		return runStage(d, extraArgs)
	case "poweroff":
		return runPoweroff(d, extraArgs)
	case "reboot", "halt", "kexec", "exit":
		// Non-poweroff verbs do nothing (design: never interfere).
		return 0
	default:
		log.Printf("%s: unknown verb %q", prefix, verb)
		return 2
	}
}

func runStage(d deps, args []string) int {
	fs := flag.NewFlagSet("stage", flag.ContinueOnError)
	out := fs.String("out", "/run/rog-poweroff/staged.json", "staged JSON path")
	fadtPath := fs.String("fadt", "/sys/firmware/acpi/tables/FACP", "FADT table file (signature name FACP)")
	dsdtPath := fs.String("dsdt", "/sys/firmware/acpi/tables/DSDT", "DSDT table file")
	fs.Parse(args)

	fadtRaw, err := os.ReadFile(*fadtPath)
	if err != nil {
		return fail(d.km, "stage", err)
	}
	dsdtRaw, err := os.ReadFile(*dsdtPath)
	if err != nil {
		return fail(d.km, "stage", err)
	}
	dmi := readDMI(d.dmiDirs)
	p, err := s5write.Stage(fadtRaw, dsdtRaw, dmi)
	if err != nil {
		return fail(d.km, "stage", err)
	}
	j, err := s5write.Marshal(p)
	if err != nil {
		return fail(d.km, "stage", err)
	}
	_ = d.km.Write(kmsg.UserNotice, fmt.Sprintf(
		"%s stage: ok pm1a=0x%x slp_typ=%d gate on -> %s", prefix, p.PM1aCntBase, p.SLPTyp, *out))
	if err := os.WriteFile(*out, j, 0o644); err != nil {
		return fail(d.km, "stage", err)
	}
	return 0
}

func runPoweroff(d deps, args []string) int {
	_ = d.km.Write(kmsg.UserNotice, prefix+" hook-start poweroff")

	// Context guard: before the pivot the old root has no /oldroot; refuse
	// so a double invocation (systemd-shutdown runs scripts pre-pivot too)
	// can never fire the write with filesystems still mounted.
	if _, err := os.Stat(oldRootPath); err != nil {
		_ = d.km.Write(kmsg.UserNotice, fmt.Sprintf("%s s5-refused reason=%q", prefix, "not-in-shutdown-ramfs (no /oldroot)"))
		_ = d.km.Write(kmsg.UserNotice, prefix+" hook-end outcome=refused")
		return 0
	}
	_ = d.km.Write(kmsg.UserNotice, modulesState())

	j, err := readStaged(d)
	if err != nil {
		return refuse(d, err)
	}
	p, err := s5write.Unmarshal(j)
	if err != nil {
		return refuse(d, err)
	}
	if err := s5write.Validate(p); err != nil {
		return refuse(d, err)
	}
	live := readDMI(d.dmiDirs)
	if err := p.MatchesDMI(live); err != nil {
		return refuse(d, err)
	}

	was := uint16(0)
	_ = d.km.Write(kmsg.UserNotice, fmt.Sprintf(
		"%s s5-attempt pm1a=0x%x slp_typ=%d", prefix, p.PM1aCntBase, p.SLPTyp))
	rf, err := d.openRF()
	if err != nil {
		return refuse(d, err)
	}
	was, err = s5write.Power(rf, p)
	if err != nil {
		return refuse(d, err)
	}
	// Success means control returned: firmware SHOULD have powered the
	// machine off. Breadcrumb the anomaly for Gate 3, bounded loop.
	_ = d.km.Write(kmsg.UserWarning, fmt.Sprintf(
		"%s s5-returned pm1a=0x%x old=0x%x new=0x%x (firmware returned control — evidence for Gate 3)",
		prefix, p.PM1aCntBase, was, s5write.S5WriteValue(was, p.SLPTyp)))
	for i := 1; i < d.max(); i++ {
		time.Sleep(d.every())
		_ = d.km.Write(kmsg.UserWarning, fmt.Sprintf("%s s5-returned t=+%ds", prefix, i*int(d.every()/time.Second)))
	}
	_ = d.km.Write(kmsg.UserNotice, prefix+" hook-end outcome=s5-returned")
	return 0
}

func (d deps) every() time.Duration {
	if d.returnedEvery == 0 {
		return defaultReturnedEvery
	}
	return d.returnedEvery
}

func (d deps) max() int {
	if d.returnedMax == 0 {
		return defaultReturnedMax
	}
	return d.returnedMax
}

// refuse logs the refusal and exits 0: a refused write must not block the
// normal (later stages + kernel) shutdown path in any way.
func refuse(d deps, err error) int {
	_ = d.km.Write(kmsg.UserWarning, fmt.Sprintf("%s s5-refused reason=%q", prefix, err.Error()))
	_ = d.km.Write(kmsg.UserNotice, prefix+" hook-end outcome=refused")
	return 0
}

// fail is the stage counterpart: a staging failure breaks the readiness
// contract and must be LOUD (nonzero exit = failed oneshot unit).
func fail(km *kmsg.Writer, verb string, err error) int {
	_ = km.Write(kmsg.UserWarning, fmt.Sprintf("%s %s-refused reason=%q", prefix, verb, err.Error()))
	_ = km.Write(kmsg.UserNotice, fmt.Sprintf("%s hook-end outcome=staging-failed", prefix))
	log.Printf("%s %s failed: %v", prefix, verb, err)
	return 1
}

// modulesState breadcrumbs loaded-module facts at write time: module count
// plus which suspects are still resident (NVIDIA GPU teardown and the
// Realtek NIC were the hardware candidates in the investigation).
func modulesState() string {
	data, err := os.ReadFile("/proc/modules")
	if err != nil {
		return prefix + " modules-state unreadable"
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	nv := "nvidia:no"
	rtl := "r8169:no"
	for _, l := range lines {
		name, _, _ := strings.Cut(l, " ")
		switch name {
		case "nvidia":
			nv = "nvidia=yes"
		case "r8169":
			rtl = "r8169=yes"
		}
	}
	return fmt.Sprintf("%s modules-state loaded=%d %s %s", prefix, len(lines), nv, rtl)
}

// readStaged returns the staged JSON. Primary: /run (bind-transferred
// into the ramfs by switch_root). Fallback: the old root's /run in case
// the transfer is unavailable on some systemd build.
func readStaged(d deps) ([]byte, error) {
	if j, err := os.ReadFile(d.config); err == nil {
		return j, nil
	}
	return os.ReadFile(staleJSONFallback())
}

// readDMI reads the live machine identity; trailing newlines are trimmed
// by s5write.CheckDMI. In the ramfs /proc, /dev, /sys, /run are bind
// mounts maintained by switch_root, so sysfs is readable.
func readDMI(dmiDirs string) s5write.DMI {
	dir := "/sys/class/dmi/id"
	if dmiDirs != "" {
		dir = dmiDirs
	}
	vendor, _ := os.ReadFile(dir + "/sys_vendor")
	product, _ := os.ReadFile(dir + "/product_name")
	return s5write.DMI{SysVendor: string(vendor), ProductName: string(product)}
}

func main() {
	// systemd-shutdown executes /etc/systemd/system-shutdown/* with NO
	// arguments: no-args defaults to the poweroff verb. Explicit verbs
	// (stage, reboot, ...) come from the boot-time unit and operators.
	verb := "poweroff"
	var extraArgs []string
	if len(os.Args) >= 2 {
		if os.Args[1] == "-h" || os.Args[1] == "--help" {
			log.Printf("usage: rog-poweroff-hook [stage|poweroff|reboot|halt|kexec|exit] [flags]")
			os.Exit(1)
		}
		verb = os.Args[1]
		extraArgs = os.Args[2:]
	}
	d := deps{
		km:  kmsg.New(),
		out: "/run/rog-poweroff/staged.json",
		openRF: func() (s5write.RegisterFile, error) { return (s5write.DevPort{}).Open() },
	}
	os.Exit(run(verb, d, extraArgs))
}
