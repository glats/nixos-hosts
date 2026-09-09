package fadt

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

// buildFadt assembles a minimal-but-valid FADT byte image for table tests.
// X_PM1a GAS fields and the legacy field are set from the arguments; every
// byte contributes to the checksum so the image stays valid (-minus-one is
// deliberately patched at the end to make it so).
func buildFadt(t *testing.T, opts func(data []byte)) []byte {
	t.Helper()
	data := make([]byte, 276) // FADT v6 full size, matches rog's live table
	copy(data[0:4], "FACP")
	binary.LittleEndian.PutUint32(data[4:8], 276)
	data[8] = 6
	copy(data[10:16], "ASUSN")
	copy(data[16:24], "GL553VD.")
	// Legacy PM1a_CNT_BLK @64 = 0 (refuse-by-default so a table without a
	// usable address fails unless the test opts in).
	// PM1_CNT_LEN @89 = 2 (the register width the writer assumes).
	data[offsetPM1CntLen] = 2
	if opts != nil {
		opts(data)
	}
	// Fix the checksum byte so the byte sum over the table is 0.
	var sum uint8
	for _, b := range data {
		sum += b
	}
	data[9] = -sum
	return data
}

// putXPM1a writes an X_PM1a_CNT_BLK GAS at offset 172.
func putXPM1a(data []byte, spaceID, bitWidth, bitOffset, accessSize uint8, addr uint64) {
	data[offsetXPM1aCnt] = spaceID
	data[offsetXPM1aCnt+1] = bitWidth
	data[offsetXPM1aCnt+2] = bitOffset
	data[offsetXPM1aCnt+3] = accessSize
	binary.LittleEndian.PutUint64(data[offsetXPM1aCnt+4:], addr)
}

func wantErr(t *testing.T, name string, err error) {
	t.Helper()
	if err == nil {
		t.Errorf("%s: expected error, got none", name)
	}
}

func TestParseLiveROGFadt(t *testing.T) {
	// Checkpoint B: rog's real table. The X field is valid here
	// (SystemIO, 16-bit, addr 0x1804), matching /proc/ioports
	// (ACPI PM1a_CNT_BLK) from the live machine.
	data, err := os.ReadFile(filepath.Join("testdata", "FADT.rog.bin"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	tab, err := Parse(data)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if tab.PM1aCntBase != 0x1804 {
		t.Errorf("PM1aCntBase = 0x%x, want 0x1804", tab.PM1aCntBase)
	}
	if !tab.PM1aFromX {
		t.Errorf("expected X_PM1a_CNT_BLK (GAS @172) to resolve PM1a on rog")
	}
	wantGAS := GAS{SpaceID: 1, BitWidth: 16, BitOffset: 0, AccessSize: 2, AddrBase: 0x1804, AddrValid: true}
	if tab.XPM1aCntGas != wantGAS {
		t.Errorf("XPM1aCntGas = %+v, want %+v", tab.XPM1aCntGas, wantGAS)
	}
	if tab.PM1aCntBase == tab.PM1bCntBase {
		t.Errorf("PM1b should be absent (0), got 0x%x", tab.PM1bCntBase)
	}
	if tab.Header.OemID != "_ASUS_" || tab.Header.OemTableID != "Notebook" {
		t.Errorf("OEM identification: id=%q table=%q", tab.Header.OemID, tab.Header.OemTableID)
	}
}

func TestParsePrefersXAndFallsBackToLegacy(t *testing.T) {
	t.Run("X valid wins over legacy", func(t *testing.T) {
		data := buildFadt(t, func(d []byte) {
			putXPM1a(d, 1, 16, 0, 2, 0x1804)
			binary.LittleEndian.PutUint32(d[offsetPM1aCntLegacy:], 0x9999)
		})
		tab, err := Parse(data)
		if err != nil {
			t.Fatalf("Parse: %v", err)
		}
		if tab.PM1aCntBase != 0x1804 || !tab.PM1aFromX {
			t.Errorf("base=0x%x fromX=%v, want 0x1804 from X", tab.PM1aCntBase, tab.PM1aFromX)
		}
	})

	// ACPI spec: legacy field must be used when the X field is all zero.
	t.Run("X all zero falls back to legacy", func(t *testing.T) {
		data := buildFadt(t, func(d []byte) {
			binary.LittleEndian.PutUint32(d[offsetPM1aCntLegacy:], 0x1804)
		})
		tab, err := Parse(data)
		if err != nil {
			t.Fatalf("Parse: %v", err)
		}
		if tab.PM1aCntBase != 0x1804 || tab.PM1aFromX {
			t.Errorf("base=0x%x fromX=%v, want legacy fallback 0x1804", tab.PM1aCntBase, tab.PM1aFromX)
		}
	})

	// ACRPI spec: if X is nonzero-but-invalid it is firmware junk and the
	// legacy block is authoritative (rog's X_GAS neighbors are garbage;
	// only PM1a happens to be well-formed).
	t.Run("X invalid falls back to legacy", func(t *testing.T) {
		data := buildFadt(t, func(d []byte) {
			putXPM1a(d, spaceMemory, 32, 4, 3, 0xFE000000)
			binary.LittleEndian.PutUint32(d[offsetPM1aCntLegacy:], 0x1804)
		})
		tab, err := Parse(data)
		if err != nil {
			t.Fatalf("Parse: %v", err)
		}
		if tab.PM1aCntBase != 0x1804 || tab.PM1aFromX {
			t.Errorf("base=0x%x fromX=%v, want legacy fallback", tab.PM1aCntBase, tab.PM1aFromX)
		}
	})
}

func TestParseRejects(t *testing.T) {
	cases := []struct {
		name string
		mut  func(d []byte) // mutation over base(X valid @0x1804, legacy 0)
		late func(d []byte) // applied after checksum recomputation (breaks the checksum itself)
	}{
		{name: "checksum mismatch", late: func(d []byte) { d[200] ^= 0xFF }},
		{name: "length field mismatches data", mut: func(d []byte) {
			binary.LittleEndian.PutUint32(d[4:8], 128)
		}},
		{name: "length field larger than data", mut: func(d []byte) {
			binary.LittleEndian.PutUint32(d[4:8], 400)
		}},
		{name: "neither X nor legacy usable", mut: func(d []byte) {
			putXPM1a(d, 1, 16, 0, 2, 0) // X present but invalid address
			// legacy stays 0
		}},
		{name: "X wrong space", mut: func(d []byte) {
			putXPM1a(d, spaceMemory, 16, 0, 2, 0x1804)
		}},
		{name: "X wrong width", mut: func(d []byte) {
			putXPM1a(d, 1, 8, 0, 2, 0x1804)
		}},
		{name: "legacy wrong PM1_CNT_LEN", mut: func(d []byte) {
			putXPM1a(d, 1, 16, 0, 2, 0) // force fallback
			d[offsetPM1CntLen] = 4
			binary.LittleEndian.PutUint32(d[offsetPM1aCntLegacy:], 0x1804)
		}},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			data := buildFadt(t, tc.mut)
			// Recompute the checksum so ONLY the targeted defect breaks the
			// parse (the checksum-defect case patches after re-summing).
			var sum uint8
			for _, b := range data {
				sum += b
			}
			data[9] -= sum
			if tc.late != nil {
				tc.late(data)
			}
			_, err := Parse(data)
			wantErr(t, tc.name, err)
		})
	}
}

func TestParseShort_truncatedTable(t *testing.T) {
	_, err := Parse([]byte{0x46, 0x41, 0x43, 0x50}) // "FACP" only, no header
	wantErr(t, "truncated header", err)
}

// The design.md correction: 116 is RESET_REG. A broken parser reading the
// block there would see rog's reset register (SystemIO, 8-bit, 0xcf9) and
// mis-derive a totally different port. Pin it for rog's real table.
func TestParseDoesNotConfuseResetRegWithPM1a(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("testdata", "FADT.rog.bin"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	tab, err := Parse(data)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if tab.PM1aCntBase == 0xcf9 {
		t.Errorf("parser confused RESET_REG (0xcf9) with PM1a_CNT_BLK")
	}
}
