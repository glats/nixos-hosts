package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/glats/nixos-scripts/internal/kmsg"
	"github.com/glats/nixos-scripts/internal/s5write"
)

// recordingRF records every WriteAt (tests assert ZERO writes on refusal
// paths) and answers reads with the register's starting value.
type recordingRF struct {
	value   uint16
	writes  []int64
	storage [2]byte
}

func (r *recordingRF) ReadAt(p []byte, off int64) (int, error) {
	for i := range p {
		p[i] = byte(r.value >> uint(8*i))
	}
	return len(p), nil
}

func (r *recordingRF) WriteAt(p []byte, off int64) (int, error) {
	r.writes = append(r.writes, off)
	copy(r.storage[:], p)
	return len(p), nil
}

// fixturePaths copies the real rog FADT + DSDT into a temp dir and returns
// the file paths for the stage verb flags.
func fixturePaths(t *testing.T) (fadtPath, dsdtPath string) {
	t.Helper()
	copyTable := func(src, name string) string {
		b, err := os.ReadFile(src)
		if err != nil {
			t.Fatalf("copy %s: %v", name, err)
		}
		dst := filepath.Join(t.TempDir(), name)
		if err := os.WriteFile(dst, b, 0o600); err != nil {
			t.Fatal(err)
		}
		return dst
	}
	return copyTable(filepath.Join("..", "..", "internal", "fadt", "testdata", "FADT.rog.bin"), "FACP"),
		copyTable(filepath.Join("..", "..", "internal", "dsdt", "testdata", "DSDT.rog.bin"), "DSDT")
}

// dmiDir fabricates a /sys/class/dmi/id-shaped directory.
func dmiDir(t *testing.T, vendor, product string) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "sys_vendor"), []byte(vendor), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "product_name"), []byte(product), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

var rogProduct = struct{ vendor, name string }{"ASUSTeK COMPUTER INC.\n", "GL553VD\n"}

// hookVM ties deps to a temp kmsg file and exposes breadcrumb assertions.
type hookVM struct {
	t     *testing.T
	d     deps
	kmLog string
}

func newHook(t *testing.T, vendor, productName string) *hookVM {
	t.Helper()
	kmLog := filepath.Join(t.TempDir(), "kmsg")
	if err := os.WriteFile(kmLog, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	h := &hookVM{t: t, kmLog: kmLog}
	h.d = deps{
		km:          &kmsg.Writer{Path: kmLog},
		dmiDirs:     dmiDir(t, vendor, productName),
		returnedMax: 1, // single s5-returned breadcrumb, no sleeping
	}
	return h
}

// crumbs returns the rog-s5 breadcrumb lines in write order.
func (h *hookVM) crumbs() []string {
	b, err := os.ReadFile(h.kmLog)
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(b), "\n") {
		if !strings.HasPrefix(l, "<1") {
			continue
		}
		i := strings.Index(l, ">rog-s5: ")
		if i >= 0 {
			out = append(out, l[i+1:])
		}
	}
	return out
}

// breadcrumbs asserts ordered appearance of substrings, then more of them.
func crumbsOrdered(t *testing.T, crumbs []string, wants ...string) {
	t.Helper()
	pos := 0
	for _, want := range wants {
		found := -1
		for i := pos; i < len(crumbs); i++ {
			if strings.Contains(crumbs[i], want) {
				found = i
				break
			}
		}
		if found < 0 {
			t.Fatalf("breadcrumb %q missing or out of order in %v", want, crumbs)
		}
		pos = found
	}
}

func TestStageProducesValidJSON(t *testing.T) {
	fadtPath, dsdtPath := fixturePaths(t)
	h := newHook(t, rogProduct.vendor, rogProduct.name)
	out := filepath.Join(t.TempDir(), "staged.json")

	code := run("stage", h.d, []string{"-fadt", fadtPath, "-dsdt", dsdtPath, "-out", out})
	if code != 0 {
		t.Fatalf("stage exit = %d, crumbs=%v", code, h.crumbs())
	}
	j, err := os.ReadFile(out)
	if err != nil {
		t.Fatalf("no staged JSON: %v", err)
	}
	p, err := s5write.Unmarshal(j)
	if err != nil {
		t.Fatalf("staged JSON invalid: %v", err)
	}
	if p.PM1aCntBase != 0x1804 || p.SLPTyp != 7 || !p.Gate {
		t.Errorf("staged plan = %+v", p)
	}
	crumbs := h.crumbs()
	if len(crumbs) == 0 || !strings.Contains(crumbs[0], "stage: ok pm1a=0x1804 slp_typ=7") {
		t.Errorf("breadcrumbs = %v", crumbs)
	}
}

func TestStageRefusalIsLoud(t *testing.T) {
	h := newHook(t, "Lenovo\n", "ThinkPad\n") // wrong DMI → refuse
	out := filepath.Join(t.TempDir(), "staged.json")
	bad := filepath.Join(t.TempDir(), "badtable")
	if err := os.WriteFile(bad, []byte("garbage"), 0o600); err != nil {
		t.Fatal(err)
	}
	code := run("stage", h.d, []string{"-fadt", bad, "-dsdt", bad, "-out", out})
	if code != 1 {
		t.Errorf("exit = %d, want 1 (staging failures are loud)", code)
	}
	if _, err := os.ReadFile(out); err == nil {
		t.Errorf("no JSON must exist after refusal")
	}
	crumbsOrdered(t, h.crumbs(), "stage-refused", "hook-end outcome=staging-failed")
}

func TestPoweroffVerbMatrix(t *testing.T) {
	cases := []struct {
		name       string
		verb       string
		oldRoot    bool // exists (in the ramfs) or not (pre-pivot)
		stageJSON  bool
		vendor     string
		product    string
		wantCode   int
		wantWrite  int
		wantCrumbs []string
	}{
		{"reboot verb is a silent no-op", "reboot", false, false, rogProduct.vendor, rogProduct.name,
			0, 0, nil},
		{"pre-pivot guard refuses", "poweroff", false, true, rogProduct.vendor, rogProduct.name,
			0, 0, []string{"hook-start", "s5-refused reason=\"not-in-shutdown-ramfs", "hook-end outcome=refused"}},
		{"no staged config refuses", "poweroff", true, false, rogProduct.vendor, rogProduct.name,
			0, 0, []string{"hook-start", "modules-state", "s5-refused", "hook-end"}},
		{"wrong live DMI refuses", "poweroff", true, true, "Lenovo\n", "ThinkPad\n",
			0, 0, []string{"hook-start", "s5-refused", "hook-end"}},
		{"write fires from the ramfs", "poweroff", true, true, rogProduct.vendor, rogProduct.name,
			0, 1, []string{"hook-start", "modules-state", "s5-attempt pm1a=0x1804 slp_typ=7", "s5-returned", "hook-end outcome=s5-returned"}},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			h := newHook(t, tc.vendor, tc.product)
			cfg := filepath.Join(t.TempDir(), "staged.json")
			h.d.config = cfg

			if tc.stageJSON {
				j, err := s5write.Marshal(rogPlan())
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(cfg, j, 0o600); err != nil {
					t.Fatal(err)
				}
			}
			rf := &recordingRF{value: 0x0140}
			h.d.openRF = func() (s5write.RegisterFile, error) { return rf, nil }

			backup := oldRootPath
			defer func() { oldRootPath = backup }()
			if tc.oldRoot {
				oldRootPath = t.TempDir()
			} else {
				oldRootPath = t.TempDir() + "/nonexistent"
			}

			code := run(tc.verb, h.d, nil)
			if code != tc.wantCode {
				t.Errorf("exit = %d, want %d", code, tc.wantCode)
			}
			if n := len(rf.writes); n != tc.wantWrite {
				t.Errorf("writes = %d, want %d (crumbs: %v)", n, tc.wantWrite, h.crumbs())
			}
			if tc.wantCrumbs != nil {
				crumbsOrdered(t, h.crumbs(), tc.wantCrumbs...)
			}
			if tc.wantWrite > 0 && rf.writes[0] != 0x1804 {
				t.Errorf("write at 0x%x, want 0x1804", rf.writes[0])
			}
		})
	}
}

// unknown verb exits 2 with a log line and no breadcrumbs.
func TestUnknownVerbExit2(t *testing.T) {
	h := newHook(t, rogProduct.vendor, rogProduct.name)
	code := run("frobnicate", h.d, nil)
	if code != 2 {
		t.Errorf("exit = %d, want 2", code)
	}
	if crumbs := h.crumbs(); len(crumbs) != 0 {
		t.Errorf("unexpected breadcrumbs: %v", crumbs)
	}
}

func rogPlan() s5write.Plan {
	return s5write.Plan{
		Version:        s5write.StagedPlanVersion,
		Gate:           true,
		PM1aCntBase:    0x1804,
		SLPTyp:         7,
		GasSpaceID:     1,
		GasBitWidth:    16,
		DMISysVendor:   "ASUSTeK COMPUTER INC.",
		DMIProductName: "GL553VD",
	}
}
