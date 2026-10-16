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

const (
	bitSLPEN     uint16 = 1 << 13
	maskSLPTYP   uint16 = 0x7 << 10
	maskSLPField uint16 = bitSLPEN | maskSLPTYP
)

const (
	maxPort  = 0xFFFE
	minTyp   = 1
	maxTyp   = 7
	gasIO    = 1
	gasWidth = 16
)

const ExpectedProduct = "GL553VD"

type DMI struct {
	SysVendor   string
	ProductName string
}

type Plan struct {
	Version        int    `json:"version"`
	Gate           bool   `json:"gate"`
	PM1aCntBase    uint64 `json:"pm1a_cnt_base"`
	SLPTyp         uint64 `json:"slp_typ"`
	GasSpaceID     uint8  `json:"gas_space_id"`
	GasBitWidth    uint8  `json:"gas_bit_width"`
	DMISysVendor   string `json:"dmi_sys_vendor"`
	DMIProductName string `json:"dmi_product_name"`
}

const StagedPlanVersion = 1

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

func CheckDMI(d DMI) error {
	if txt := strings.TrimSpace(d.ProductName); txt != ExpectedProduct {
		return fmt.Errorf("DMI product %q, want %q: write refused", txt, ExpectedProduct)
	}
	if strings.TrimSpace(d.SysVendor) == "" {
		return fmt.Errorf("DMI sys_vendor empty")
	}
	return nil
}

func (p Plan) MatchesDMI(live DMI) error {
	if got := strings.TrimSpace(live.ProductName); got != p.DMIProductName {
		return fmt.Errorf("live DMI product %q != staged %q", got, p.DMIProductName)
	}
	if got := strings.TrimSpace(live.SysVendor); got != p.DMISysVendor {
		return fmt.Errorf("live DMI vendor %q != staged %q", got, p.DMISysVendor)
	}
	return nil
}

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

func Marshal(p Plan) ([]byte, error) {
	return json.MarshalIndent(p, "", "  ")
}

func Unmarshal(data []byte) (Plan, error) {
	var p Plan
	if err := json.Unmarshal(data, &p); err != nil {
		return Plan{}, fmt.Errorf("s5write: unmarshal staged plan: %w", err)
	}
	return p, nil
}

type RegisterFile interface {
	io.ReaderAt
	io.WriterAt
}

func Power(rf RegisterFile, p Plan) (uint16, error) {
	if err := Validate(p); err != nil {
		return 0, fmt.Errorf("s5write: refused: %w", err)
	}
	buf := make([]byte, 2)
	if _, err := rf.ReadAt(buf, int64(p.PM1aCntBase)); err != nil {
		return 0, fmt.Errorf("s5write: read PM1a_CNT: %w", err)
	}
	was := binary.LittleEndian.Uint16(buf)
	changed := was&^maskSLPField | (uint16(p.SLPTyp) << 10) | bitSLPEN
	binary.LittleEndian.PutUint16(buf, changed)
	if _, err := rf.WriteAt(buf, int64(p.PM1aCntBase)); err != nil {
		return 0, fmt.Errorf("s5write: write PM1a_CNT: %w", err)
	}
	return was, nil
}

func S5WriteValue(before uint16, typ uint64) uint16 {
	return before&^maskSLPField | uint16(typ)<<10 | bitSLPEN
}

type DevPort struct {
	Path string
}

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

func (d DevPort) path() string {
	if d.Path == "" {
		return "/dev/port"
	}
	return d.Path
}

func mknodDev(major, minor uint32) uint32 {
	return major<<8 | minor
}

func mknodChar(path string, major, minor uint32) error {
	dev := mknodDev(major, minor)
	if err := syscall.Mknod(path, syscall.S_IFCHR|0o600, int(dev)); err != nil {
		return err
	}
	return nil
}
