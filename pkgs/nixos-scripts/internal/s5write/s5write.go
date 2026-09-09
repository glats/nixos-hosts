// Package s5write validates refusals and performs the firmware-derived S5
// poweroff write. On the rog (GL553VD) shutdown hang the kernel reliably
// stops inside "device_shutdown" (last line "[sda] Stopping disk"); a
// direct 16-bit write of (SLP_EN | SLP_TYP) into the PM1a_CNT register
// bypasses that entire path. All values are derived from real ACPI tables
// at stage time and re-validated at write time — nothing is hardcoded.
//
// Every refusal path returns an error BEFORE any port I/O happens (the
// injected RegisterFile makes zero-write provable in tests) and the wrong
// machine is refused at both gates: staging requires the live DMI to be a
// GL553VD, and the write requires the live DMI to still match the staged
// identity (protects against a staged ramfs surviving to other hardware).
package s5write

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"syscall"

	"github.com/glats/nixos-scripts/internal/dsdt"
	"github.com/glats/nixos-scripts/internal/fadt"
)

// ACPI PM1a_CNT layout: SLP_EN is bit 13, SLP_TYP occupies bits 10-12.
// The 16-bit read-modify-write clears both then rewrites them, leaving
// every other bit of the register untouched.
const (
	bitSLPEN     uint16 = 1 << 13
	maskSLPTYP   uint16 = 0x7 << 10
	maskSLPField uint16 = bitSLPEN | maskSLPTYP
)

// Min/Max range checks for the firmware values (tasks 3.4: refuse port 0
// or >0xfffe and SLP_TYP outside 1–7; value 7 is legal per ACPICA's
// ACPI_SLEEP_TYPE_MAX and is what rog's own _S5 package provides — see the
// apply-progress note before tightening this).
const (
	maxPort  = 0xFFFE
	minTyp   = 1
	maxTyp   = 7
	gasIO    = 1  // SystemIO
	gasWidth = 16 // PM1a_CNT is a 2-byte register
)

// ExpectedProduct is the DMI identity the helper is scoped to (design:
// GL553VD only — any other machine must be refused, never guessed).
const ExpectedProduct = "GL553VD"

// DMI is the host identity read from /sys/class/dmi/id/{sys_vendor,product_name}.
type DMI struct {
	SysVendor    string
	ProductName  string
}

// Plan is the validated derivation staged as JSON in /run and consumed
// from the shutdown ramfs. It carries no raw table bytes — only the
// already-validated derived values plus the DMI strings the write gate
// re-checks at poweroff time.
type Plan struct {
	Version     int    `json:"version"`
	Gate        bool   `json:"gate"`        // explicit gate flag; false refuses
	PM1aCntBase uint64 `json:"pm1a_cnt_base"` // I/O port (0x1804 on rog)
	SLPTyp      uint64 `json:"slp_typ"`       // value for SLP_TYP bits 10-12
	GasSpaceID  uint8  `json:"gas_space_id"`  // must be SystemIO
	GasBitWidth uint8  `json:"gas_bit_width"` // must be 16
	DMISysVendor   string `json:"dmi_sys_vendor"`
	DMIProductName string `json:"dmi_product_name"`
}

// StagedPlanVersion is the schema version of the staged JSON.
const StagedPlanVersion = 1

// Validate enforces every invariant the write depends on. The same
// function runs at stage time (source values) and at poweroff time
// (staged values), so a corrupted or re-decoded JSON cannot smuggle in
// different semantics.
func Validate(p Plan) error {
	if p.Version != StagedPlanVersion {
		return fmt.Errorf("plan version %d, want %d", p.Version, StagedPlanVersion)
	}
	if !p.Gate {
		return fmt.Errorf("gate flag false: write not staged")
	}
	if p.GasSpaceID != gasIO {
		return fmt.Errorf("GAS space_id %d, want SystemIO (%d)", p.GasSpaceID, gasIO)
	}
	if p.GasBitWidth != gasWidth {
		return fmt.Errorf("GAS bit_width %d, want %d (16-bit register)", p.GasBitWidth, gasWidth)
	}
	if p.PM1aCntBase == 0 || p.PM1aCntBase > maxPort {
		return fmt.Errorf("PM1a_CNT base 0x%x outside 0x1..0x%x", p.PM1aCntBase, maxPort)
	}
	if p.SLPTyp < minTyp || p.SLPTyp > maxTyp {
		return fmt.Errorf("SLP_TYP %d outside allowed range %d..%d", p.SLPTyp, minTyp, maxTyp)
	}
	if p.DMIProductName == "" {
		return fmt.Errorf("staged DMI product name empty")
	}
	return nil
}

// CheckDMI is the stage-time gate: only the expected machine may stage a
// plan at all.
func CheckDMI(d DMI) error {
	if txt := strings.TrimSpace(d.ProductName); txt != ExpectedProduct {
		return fmt.Errorf("DMI product %q, want %q: write refused", txt, ExpectedProduct)
	}
	if strings.TrimSpace(d.SysVendor) == "" {
		return fmt.Errorf("DMI sys_vendor empty")
	}
	return nil
}

// MatchesDMI is the write-time gate: the live machine must still be the
// one the plan was staged on (the /run data could theoretically survive
// a soft-reboot into different hardware).
func (p Plan) MatchesDMI(live DMI) error {
	if got := strings.TrimSpace(live.ProductName); got != p.DMIProductName {
		return fmt.Errorf("live DMI product %q != staged %q", got, p.DMIProductName)
	}
	if got := strings.TrimSpace(live.SysVendor); got != p.DMISysVendor {
		return fmt.Errorf("live DMI vendor %q != staged %q", got, p.DMISysVendor)
	}
	return nil
}

// Stage derives a validated Plan directly from raw firmware tables plus
// live DMI identity. This is the boot-time path: parse FADT (PM1a base)
// and DSDT (SLP_TYP), refuse ambiguity or malformed firmware, gate on DMI,
// and only then hand out a plan. Errors mean "refuse", never "guess".
func Stage(fadtRaw, dsdtRaw []byte, dmi DMI) (Plan, error) {
	if err := CheckDMI(dmi); err != nil {
		return Plan{}, fmt.Errorf("s5write: stage: %w", err)
	}
	tab, err := fadt.Parse(fadtRaw)
	if err != nil {
		return Plan{}, fmt.Errorf("s5write: stage: %w", err)
	}
	res, err := dsdt.Scan(dsdtRaw)
	if err != nil {
		return Plan{}, fmt.Errorf("s5write: stage: %w", err)
	}
	p := Plan{
		Version:        StagedPlanVersion,
		Gate:           true,
		PM1aCntBase:    tab.PM1aCntBase,
		SLPTyp:         res.SLPTypA,
		GasSpaceID:     1,
		GasBitWidth:    16,
		DMISysVendor:   strings.TrimSpace(dmi.SysVendor),
		DMIProductName: strings.TrimSpace(dmi.ProductName),
	}
	if err := Validate(p); err != nil {
		return Plan{}, fmt.Errorf("s5write: stage: %w", err)
	}
	return p, nil
}

// Marshal serializes the plan for the staged JSON file.
func Marshal(p Plan) ([]byte, error) {
	return json.MarshalIndent(p, "", "  ")
}

// Unmarshal parses a staged JSON file back into a Plan.
func Unmarshal(data []byte) (Plan, error) {
	var p Plan
	if err := json.Unmarshal(data, &p); err != nil {
		return Plan{}, fmt.Errorf("s5write: unmarshal staged plan: %w", err)
	}
	return p, nil
}

// RegisterFile is the port-I/O surface: exactly the two byte-range
// operations the 16-bit register write needs. *os.File (the /dev/port
// device) implements both; tests inject a recording implementation that
// counts every WriteAt.
type RegisterFile interface {
	io.ReaderAt
	io.WriterAt
}

// Power performs the validated S5 write: 16-bit read-modify-write of the
// PM1a_CNT register replacing SLP_TYP bits 10-12 with the staged SLP_TYP
// and setting SLP_EN (bit 13). Validation runs first — every refused path
// touches the register file ZERO times. On success control is expected to
// never return (SLP_EN powers the machine off); a return is evidence for
// the caller to breadcrumb ("s5-returned").
func Power(rf RegisterFile, p Plan) (uint16, error) {
	if err := Validate(p); err != nil {
		return 0, fmt.Errorf("s5write: refused: %w", err)
	}
	buf := make([]byte, 2)
	if _, err := rf.ReadAt(buf, int64(p.PM1aCntBase)); err != nil {
		return 0, fmt.Errorf("s5write: read PM1a_CNT: %w", err)
	}
	was := binary.LittleEndian.Uint16(buf)
	changed := was &^ maskSLPField | (uint16(p.SLPTyp) << 10) | bitSLPEN
	binary.LittleEndian.PutUint16(buf, changed)
	if _, err := rf.WriteAt(buf, int64(p.PM1aCntBase)); err != nil {
		return 0, fmt.Errorf("s5write: write PM1a_CNT: %w", err)
	}
	return was, nil
}

// S5WriteValue renders the value Power writes, for breadcrumbs: the
// preserved high bits, the SLP_TYP field, and SLP_EN set.
func S5WriteValue(before uint16, typ uint64) uint16 {
	return before&^maskSLPField | uint16(typ)<<10 | bitSLPEN
}

// DevPort is the production RegisterFile over /dev/port: a 2-byte read at
// offset p is a word port read, a 2-byte write at offset p a word write.
// If the device node is missing (fresh shutdown ramfs without devtmpfs
// populating it) it re-creates the node with mknod(S_IFCHR, 1:4), the
// well-known /dev/port numbers, so the recovery works inside the ramfs.
type DevPort struct {
	Path string // production: /dev/port
}

// Open returns the register file, creating the char device 1:4 when the
// node itself is absent.
func (d DevPort) Open() (RegisterFile, error) {
	if _, err := os.Stat(d.path()); err != nil {
		if !os.IsNotExist(err) {
			return nil, fmt.Errorf("s5write: stat %s: %w", d.path(), err)
		}
		if err := mknodChar(d.path(), 1, 4); err != nil {
			return nil, fmt.Errorf("s5write: mknod %s (1:4): %w", d.path(), err)
		}
	}
	f, err := os.OpenFile(d.path(), os.O_RDWR|os.O_SYNC, 0)
	if err != nil {
		return nil, fmt.Errorf("s5write: open %s: %w", d.path(), err)
	}
	return f, nil
}

// path falls back to the production path when unset.
func (d DevPort) path() string {
	if d.Path == "" {
		return "/dev/port"
	}
	return d.Path
}

func mknodChar(path string, major, minor uint32) error {
	dev := minor<<8 | major // Linux old-style 16-bit device encoding
	if err := syscall.Mknod(path, syscall.S_IFCHR|0o600, int(dev)); err != nil {
		return err
	}
	return nil
}
