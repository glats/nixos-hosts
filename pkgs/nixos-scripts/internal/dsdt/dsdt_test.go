package dsdt

import (
	"os"
	"path/filepath"
	"testing"
)

// Helper builders. A four-element _S5 package reads
// "SLP_TYPa SLP_TYPb reserved reserved"; two(A, B) appends the element
// encodings and pads the two reserved entries with ZeroOp.
func elements(a, b []byte) []byte {
	res := append([]byte{}, a...)
	res = append(res, b...)
	res = append(res, opZero, opZero)
	return res
}

func byteConst(v uint8) []byte  { return []byte{opByte, v} }
func wordConst(v uint16) []byte { return []byte{opWord, byte(v), byte(v >> 8)} }
func dwordConst(v uint32) []byte {
	return []byte{opDWord, byte(v), byte(v >> 8), byte(v >> 16), byte(v >> 24)}
}

// buildS5 crafts a NameOp + package with the given element encodings so
// tests can exercise the exact AML forms.
func buildS5(t *testing.T, withRoot bool, elems []byte) []byte {
	t.Helper()
	body := append([]byte{4}, elems...)
	b := []byte{opName}
	if withRoot {
		b = append(b, opRoot)
	}
	b = append(b, s5Name[:]...)
	b = append(b, opPackage)
	// 1-byte PkgLength counts itself (1) + NumElements (1) + the elements.
	if len(elems)+2 > 63 {
		t.Fatalf("test fixture too large for 1-byte PkgLength")
	}
	b = append(b, byte(len(elems)+2))
	b = append(b, body...)
	return b
}

func TestScanLiveROGDsdt(t *testing.T) {
	// Checkpoint B: rog's real DSDT. The live _S5 is a single root NameOp
	// with a literal Package — SLP_TYPa=7, SLP_TYPb=0, reserved 0,0
	// (kernel-verified 3-bit SLP_TYP; see apply-progress for the policy
	// discussion around value 7).
	data, err := os.ReadFile(filepath.Join("testdata", "DSDT.rog.bin"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	res, err := Scan(data)
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	if res.Offset != 36414 {
		t.Errorf("Offset = %d, want 36414 (live scan)", res.Offset)
	}
	want := [4]uint64{7, 0, 0, 0}
	if res.Elements != want {
		t.Errorf("Elements = %v, want %v", res.Elements, want)
	}
	if res.SLPTypA != 7 || res.SLPTypB != 0 {
		t.Errorf("SLP_TYP a/b = %d/%d, want 7/0", res.SLPTypA, res.SLPTypB)
	}
}

func TestScanAcceptsLiteralForms(t *testing.T) {
	cases := []struct {
		name     string
		withRoot bool
		elems    []byte
		wantA    uint64
	}{
		{"byte consts with root prefix", true, elements(byteConst(5), byteConst(5)), 5},
		{"byte consts without root prefix", false, elements(byteConst(0), byteConst(0)), 0},
		{"word consts", true, elements(wordConst(7), wordConst(7)), 7},
		{"dword consts", true, elements(dwordConst(3), dwordConst(3)), 3},
		{"zero/one constants", true, elements([]byte{opZero}, []byte{opOne}), 0},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			data := buildS5(t, tc.withRoot, tc.elems)
			res, err := Scan(data)
			if err != nil {
				t.Fatalf("Scan: %v", err)
			}
			if res.SLPTypA != tc.wantA {
				t.Errorf("SLPTypA = %d, want %d", res.SLPTypA, tc.wantA)
			}
		})
	}
}

func TestScanRejects(t *testing.T) {
	filler := byteConst(5)

	cases := []struct {
		name  string
		build func() []byte
	}{
		{"missing _S5", func() []byte {
			return []byte{opName, '_'}
		}},
		{"two _S5 definitions", func() []byte {
			first := buildS5(t, true, elements(byteConst(5), byteConst(5)))
			return append(first, first...)
		}},
		{"named reference element", func() []byte {
			// Package(){PCI0, ...} — a NameString is any letter-led name,
			// not an integer constant.
			elems := append([]byte{'P', 'C', 'I', '0'}, filler...)
			return buildS5(t, true, elems)
		}},
		{"method-like element", func() []byte {
			// 0x5B is the ExtOpPrefix (e.g. MethodOp follows it) — not a
			// literal integer constant.
			elems := append([]byte{0x5B, 0x84}, filler...)
			return buildS5(t, true, elems)
		}},
		{"three elements only", func() []byte {
			return buildS5(t, true, []byte{opByte, 5, opByte, 5, opZero})
		}},
		{"five elements", func() []byte {
			return buildS5(t, true, []byte{opByte, 5, opByte, 5, opZero, opZero, opZero})
		}},
		{"not a package (integer arg)", func() []byte {
			// NameOp _S5, then a bare integer constant instead of Package.
			var b []byte
			b = append(b, opName, opRoot)
			b = append(b, s5Name[:]...)
			b = append(b, opByte, 5)
			return b
		}},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			data := tc.build()
			if _, err := Scan(data); err == nil {
				t.Errorf("%s: expected error, got none", tc.name)
			}
		})
	}
}

// A package element that references a name (e.g. \_SB.PCI0's result) is
// refused — the scanner cannot know its runtime value and must not guess.
func TestScanRefusesReferenceForm(t *testing.T) {
	elems := []byte{opRoot, 'S', 'B', '.', 'P'}
	if _, err := Scan(buildS5(t, true, elems)); err == nil {
		t.Errorf("reference form: expected error, got none")
	}
}

func TestSLPTypAbove3BitsRefused(t *testing.T) {
	// SLP_TYP is a 3-bit field; a bogus word constant 8 must fail loudly.
	data := buildS5(t, true, elements(wordConst(8), wordConst(8)))
	if _, err := Scan(data); err == nil {
		t.Errorf("SLP_TYP 8: expected error, got none")
	}
}
