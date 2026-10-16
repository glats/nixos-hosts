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

const prefix = "rog-s5:"

var oldRootPath = "/oldroot"

func staleJSONFallback() string {
	return oldRootPath + "/run/rog-poweroff/staged.json"
}

const (
	defaultReturnedEvery = 5 * time.Second
	defaultReturnedMax   = 6
)

type deps struct {
	km      *kmsg.Writer
	dmiDirs string
	out     string
	config  string
	openRF  func() (s5write.RegisterFile, error)

	returnedEvery time.Duration
	returnedMax   int
}

func run(verb string, d deps, extraArgs []string) int {
	switch verb {
	case "stage":
		return runStage(d, extraArgs)
	case "poweroff":
		return runPoweroff(d, extraArgs)
	case "reboot", "halt", "kexec", "exit":

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
	dmi, _ := readDMI(d.dmiDirs)
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
	live, dmiReadable := readDMI(d.dmiDirs)
	if dmiReadable {
		if err := p.MatchesDMI(live); err != nil {
			return refuse(d, err)
		}
	} else {

		_ = d.km.Write(kmsg.UserNotice, prefix+" dmi-live-unreadable — staged DMI trusted (boot-time gate matched GL553VD)")
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

func refuse(d deps, err error) int {
	_ = d.km.Write(kmsg.UserWarning, fmt.Sprintf("%s s5-refused reason=%q", prefix, err.Error()))
	_ = d.km.Write(kmsg.UserNotice, prefix+" hook-end outcome=refused")
	return 0
}

func fail(km *kmsg.Writer, verb string, err error) int {
	_ = km.Write(kmsg.UserWarning, fmt.Sprintf("%s %s-refused reason=%q", prefix, verb, err.Error()))
	_ = km.Write(kmsg.UserNotice, fmt.Sprintf("%s hook-end outcome=staging-failed", prefix))
	log.Printf("%s %s failed: %v", prefix, verb, err)
	return 1
}

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

func readStaged(d deps) ([]byte, error) {
	if j, err := os.ReadFile(d.config); err == nil {
		return j, nil
	}
	return os.ReadFile(staleJSONFallback())
}

func readDMI(dmiDirs string) (s5write.DMI, bool) {
	candidates := []string{oldRootPath + "/sys/class/dmi/id", "/sys/class/dmi/id"}
	if dmiDirs != "" {
		candidates = []string{dmiDirs}
	}
	for _, dir := range candidates {
		vendor, verr := os.ReadFile(dir + "/sys_vendor")
		product, perr := os.ReadFile(dir + "/product_name")
		if verr == nil && perr == nil {
			return s5write.DMI{SysVendor: string(vendor), ProductName: string(product)}, true
		}
	}
	return s5write.DMI{}, false
}

func main() {

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

		config: "/run/rog-poweroff/staged.json",
		openRF: func() (s5write.RegisterFile, error) { return (s5write.DevPort{}).Open() },
	}
	os.Exit(run(verb, d, extraArgs))
}
