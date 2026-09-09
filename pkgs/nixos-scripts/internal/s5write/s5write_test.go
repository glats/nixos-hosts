package s5write

import (
	"os"
	"path/filepath"
	"testing"
)

// recordingRF records every ReadAt/WriteAt against the declared plan, so
// tests can assert ZERO writes on every refusal path.
type recordingRF struct {
	reads  []int64
	writes []int64
	data   map[int64][]byte
}

func newRecordingRF(before uint16, base int64) *recordingRF {
	rf := &recordingRF{data: map[int64][]byte{}}
	buf := []byte{byte(before), byte(before >> 8)}
	for i, b := range buf {
		rf.data[base+int64(i)] = []byte{b}
	}
	return rf
}

func (r *recordingRF) ReadAt(p []byte, off int64) (int, error) {
	r.reads = append(r.reads, off)
	for i := range p {
		if v, ok := r.data[off+int64(i)]; ok {
			p[i] = v[0]
		} else {
			return 0, os.ErrNotExist
		}
	}
	return len(p), nil
}

func (r *recordingRF) WriteAt(p []byte, off int64) (int, error) {
	r.writes = append(r.writes, off)
	for i, b := range p {
		r.data[off+int64(i)] = []byte{b}
	}
	return len(p), nil
}

// rogPlan is the plan rog's live firmware derives (Checkpoint B values).
func rogPlan() Plan {
	return Plan{
		Version:        StagedPlanVersion,
		Gate:           true,
		PM1aCntBase:    0x1804,
		SLPTyp:         7,
		GasSpaceID:     1,
		GasBitWidth:    16,
		DMISysVendor:   "ASUSTeK COMPUTER INC.",
		DMIProductName: "GL553VD",
	}
}

func rogDMI() DMI { return DMI{SysVendor: "ASUSTeK COMPUTER INC.\n", ProductName: "GL553VD\n"} }

func TestValidateRogPlan(t *testing.T) {
	if err := Validate(rogPlan()); err != nil {
		t.Fatalf("Validate(rogPlan): %v", err)
	}
}

func TestValidateRefuses(t *testing.T) {
	cases := []struct {
		name string
		mut  func(*Plan)
	}{
		{"version mismatch", func(p *Plan) { p.Version = 0 }},
		{"gate off", func(p *Plan) { p.Gate = false }},
		{"memory space", func(p *Plan) { p.GasSpaceID = 0 }},
		{"8-bit width", func(p *Plan) { p.GasBitWidth = 8 }},
		{"port 0", func(p *Plan) { p.PM1aCntBase = 0 }},
		{"port over 0xfffe", func(p *Plan) { p.PM1aCntBase = 0xFFFF }},
		{"SLP_TYP 0 (outside 1..7)", func(p *Plan) { p.SLPTyp = 0 }},
		{"SLP_TYP 8 (outside 1..7)", func(p *Plan) { p.SLPTyp = 8 }},
		{"empty DMI product", func(p *Plan) { p.DMIProductName = "" }},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			p := rogPlan()
			tc.mut(&p)
			if err := Validate(p); err == nil {
				t.Errorf("%s: expected error, got none", tc.name)
			}
		})
	}
}

// RED-test requirement: every refusal leaves the register untouched.
func TestPowerRefusalPerformsZeroWrites(t *testing.T) {
	cases := []struct {
		name string
		mut  func(*Plan)
	}{
		{"gate off", func(p *Plan) { p.Gate = false }},
		{"wrong version", func(p *Plan) { p.Version = 99 }},
		{"memory space", func(p *Plan) { p.GasSpaceID = 0 }},
		{"16-bit violated", func(p *Plan) { p.GasBitWidth = 32 }},
		{"port 0", func(p *Plan) { p.PM1aCntBase = 0 }},
		{"port over 0xfffe", func(p *Plan) { p.PM1aCntBase = 0x10000 }},
		{"SLP_TYP 0", func(p *Plan) { p.SLPTyp = 0 }},
		{"SLP_TYP 8", func(p *Plan) { p.SLPTyp = 8 }},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			p := rogPlan()
			tc.mut(&p)
			rf := newRecordingRF(0x1240, int64(p.PM1aCntBase))
			if _, err := Power(rf, p); err == nil {
				t.Fatalf("%s: expected refusal, got none", tc.name)
			}
			if n := len(rf.writes); n != 0 {
				t.Errorf("%s: %d unexpected WriteAt calls", tc.name, n)
			}
			if n := len(rf.reads); n != 0 {
				t.Errorf("%s: %d unexpected ReadAt calls (validation must run first)", tc.name, n)
			}
		})
	}
}

func TestPowerReadModifyWrite(t *testing.T) {
	// Before: SLP_STS entries (0x1240: bits 10-12 pattern 0b0 -> hmm, use a
	// realistic prior value with SLP_TYP=0 and SLP_EN=0: 0x0010? Use
	// 0x0140: byte-wise 40 01 -> registers bits: bit6=1 (BSA?) whatever.
	// The assertion only checks the SLP fields are rewritten correctly.
	rf := newRecordingRF(0x0140, 0x1804)
	p := rogPlan()
	was, err := Power(rf, p)
	if err != nil {
		t.Fatalf("Power: %v", err)
	}
	if was != 0x0140 {
		t.Errorf("was = 0x%x, want 0x0140", was)
	}
	want := S5WriteValue(was, p.SLPTyp) // (0x0140 &^ 0x3C00) | 7<<10 | 1<<13 = 0x3D40
	if want != 0x3D40 {
		t.Errorf("S5WriteValue = 0x%x, want 0x3D40", want)
	}
	if len(rf.writes) != 1 || rf.writes[0] != 0x1804 {
		t.Fatalf("writes = %v, want one write at 0x1804", rf.writes)
	}
	got := uint16(rf.data[0x1804][0]) | uint16(rf.data[0x1805][0])<<8
	if got != want {
		t.Errorf("register after write = 0x%x, want 0x%x", got, want)
	}
	// The preserved high bits must survive: bit 6 and bit 8 stay set.
	if got&0x0140 != 0x0140 {
		t.Errorf("pre-existing non-SLP bits clobbered: got=0x%x", got)
	}
}

func TestStageFromLiveFixtures(t *testing.T) {
	// Checkpoint B end-to-end: the real rog FADT + DSDT + DMI must stage a
	// plan whose values match /proc/ioports (0x1804) and the live _S5 (7).
	fadtRaw, err := os.ReadFile(filepath.Join("..", "fadt", "testdata", "FADT.rog.bin"))
	if err != nil {
		t.Fatalf("read FADT fixture: %v", err)
	}
	dsdtRaw, err := os.ReadFile(filepath.Join("..", "dsdt", "testdata", "DSDT.rog.bin"))
	if err != nil {
		t.Fatalf("read DSDT fixture: %v", err)
	}
	p, err := Stage(fadtRaw, dsdtRaw, rogDMI())
	if err != nil {
		t.Fatalf("Stage: %v", err)
	}
	if p.PM1aCntBase != 0x1804 || p.SLPTyp != 7 {
		t.Errorf("staged plan = {base=0x%x typ=%d}, want {0x1804, 7}", p.PM1aCntBase, p.SLPTyp)
	}
	if !p.Gate {
		t.Errorf("staged plan must carry the gate flag")
	}
	if p.DMIProductName != "GL553VD" || p.DMISysVendor != "ASUSTeK COMPUTER INC." {
		t.Errorf("staged DMI: vendor=%q product=%q", p.DMISysVendor, p.DMIProductName)
	}
}

func TestStageRefuses(t *testing.T) {
	fadtRaw, _ := os.ReadFile(filepath.Join("..", "fadt", "testdata", "FADT.rog.bin"))
	dsdtRaw, _ := os.ReadFile(filepath.Join("..", "dsdt", "testdata", "DSDT.rog.bin"))

	t.Run("wrong DMI product", func(t *testing.T) {
		dmi := DMI{SysVendor: "Lenovo", ProductName: "ThinkPad"}
		if _, err := Stage(fadtRaw, dsdtRaw, dmi); err == nil {
			t.Errorf("wrong DMI: expected refusal, got none")
		}
	})
	t.Run("malformed FADT", func(t *testing.T) {
		if _, err := Stage([]byte("FACPsh"), dsdtRaw, rogDMI()); err == nil {
			t.Errorf("malformed FADT: expected refusal, got none")
		}
	})
	t.Run("ambiguous DSDT", func(t *testing.T) {
		// Two _S5 packages in one buffer → the scanner refuses, the stage
		// refuses with it.
		two := make([]byte, 0)
		pkg := buildS5Bytes()
		two = append(two, pkg...)
		two = append(two, pkg...)
		if _, err := Stage(fadtRaw, two, rogDMI()); err == nil {
			t.Errorf("ambiguous DSDT: expected refusal, got none")
		}
	})
}

// buildS5Bytes is a single root _S5 NameOp+Package in raw AML bytes.
func buildS5Bytes() []byte {
	b := []byte{0x08, 0x5C, '_', 'S', '5', '_', 0x12, 0x07, 0x04, 0x0A, 0x07, 0x00, 0x00, 0x00}
	return b
}

func TestUnmarshalRoundTrip(t *testing.T) {
	b, err := Marshal(rogPlan())
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	p, err := Unmarshal(b)
	if err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if p != rogPlan() {
		t.Errorf("round trip mismatch: %+v", p)
	}
}

func TestMatchesDMIOfStagedPlan(t *testing.T) {
	p := rogPlan()
	if err := p.MatchesDMI(rogDMI()); err != nil {
		t.Errorf("same machine: %v", err)
	}
	if err := p.MatchesDMI(DMI{SysVendor: "ASUSTeK COMPUTER INC.", ProductName: "OTHER"}); err == nil {
		t.Errorf("different product: expected mismatch error, got none")
	}
	if err := p.MatchesDMI(DMI{SysVendor: "Lenovo", ProductName: "GL553VD"}); err == nil {
		t.Errorf("different vendor: expected mismatch error, got none")
	}
}

// DevPort.Open against an existing regular file (tests never mknod into
// the real /dev).
func TestDevPortOpenExisting(t *testing.T) {
	path := filepath.Join(t.TempDir(), "port")
	if err := os.WriteFile(path, []byte{0x40, 0x01}, 0o600); err != nil {
		t.Fatal(err)
	}
	f, err := DevPort{Path: path}.Open()
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	// DevPort.Open returns *os.File for a real file; nothing to close here
	// through the RegisterFile interface (the production caller owns the
	// file lifetime).
	buf := make([]byte, 2)
	if _, err := f.ReadAt(buf, 0); err != nil {
		t.Errorf("ReadAt: %v", err)
	}
}

// The mknod fallback: on a missing node the Open either creates it
// (privileged) or fails visibly; an EPERM environment (unprivileged CI)
// still exercises the visible-failure contract.
func TestDevPortMissingNodeFailsClosed(t *testing.T) {
	path := filepath.Join(t.TempDir(), "port")
	_, err := DevPort{Path: path}.Open()
	if err == nil {
		t.Errorf("missing node without privileges expected failure or success-with-node")
	}
	// Either way no half-open file leaks: the path must stay absent or be
	// a proper char node we just made.
	if st, serr := os.Stat(path); serr == nil && st.Mode()&os.ModeCharDevice == 0 {
		t.Errorf("left non-device file behind at %s", path)
	}
}

// F3 (judgment-day round 1, confirmed by both judges): the device-number
// encoding was swapped (minor<<8|major). /dev/port is char 1:4, which in
// Linux old-style encoding is 0x0104 — major in the HIGH byte.
func TestMknodDevEncoding(t *testing.T) {
	if got := mknodDev(1, 4); got != 0x0104 {
		t.Errorf("mknodDev(1,4) = %#x, want 0x0104 (/dev/port char 1:4)", got)
	}
	if got := mknodDev(4, 1); got != 0x0401 {
		t.Errorf("mknodDev(4,1) = %#x, want 0x0401 (the swapped value must belong to major 4)", got)
	}
}
