// Package fadt is a strict parser for the ACPI FADT (Fixed ACPI
// Description Table, signature "FACP") extracting the PM1a_CNT block
// register address needed to enter S5 through the fixed-hardware sleep
// path. Layout follows include/acpi/actbl.h (ACPICA):
//
//	Xfacs u64 @132, Xdsdt u64 @140, X_PM1a_CNT_BLK GAS @172,
//	X_PM1b_CNT_BLK @184, ..., RESET_REG GAS @116 (NOT PM1a — see the
//	design.md correction: offset 116 is the RESET register of the
//	Q35-era firmware whose PM1a lives elsewhere).
//
// The parser prefers X_PM1a_CNT_BLK (FADT revision >= 4) and falls back to
// the legacy 32-bit PM1a_CNT_BLK field at offset 64 when the extended
// field is invalid, mirroring how ACPICA itself resolves the block. It
// fails closed: any structural problem (signature, length, checksum,
// neither field usable) is an error, never a guess.
package fadt

import (
	"encoding/binary"
	"fmt"
)

// Signature is the ACPI table signature of the FADT.
const Signature = "FACP"

// Field offsets inside the FADT (acpica actbl.h, byte-packed).
const (
	offsetPM1aCntLegacy = 64        // u32 PM1a_CNT_BLK (legacy field)
	offsetPM1bCntLegacy = 68        // u32 PM1b_CNT_BLK (legacy field)
	offsetPM1CntLen     = 89        // u8  PM1_CNT_LEN (register width in bytes)
	offsetFlags         = 112       // u32 flags
	offsetResetReg      = 116       // GAS RESET_REG (12 bytes) — NOT PM1a
	offsetXfacs         = 132       // u64 pointer
	offsetXdsdt         = 140       // u64 pointer
	offsetXPM1aCnt      = 172       // GAS X_PM1a_CNT_BLK (12 bytes)
	offsetXPM1bCnt      = 184       // GAS X_PM1b_CNT_BLK
	gasLen              = 12        // sizeof acpi_generic_address: u8 + u8 + u8 + u8 + u64
)

// ACPI GenericAddressStructure space IDs that are meaningful here.
const (
	spaceSystemIO = 1
	spaceMemory   = 0
)

// GAS is the subset of acpi_generic_address this parser carries.
type GAS struct {
	SpaceID      uint8
	BitWidth     uint8
	BitOffset    uint8
	AccessSize   uint8
	AddrBase     uint64
	AddrValid    bool // Address field is nonzero
}

// Header is the ACPI table header the parser validates.
type Header struct {
	OemID      string
	OemTableID string
	Length     uint32
	Revision   uint8
}

// Table is the parsed FADT result.
type Table struct {
	Header Header

	PM1aCntBase uint64 // I/O port base of PM1a_CNT (16-bit register)
	PM1aFromX   bool   // true when the base came from X_PM1a_CNT_BLK (GAS @172)
	PM1bCntBase uint64 // 0 on this platform (legacy field read for completeness)

	// X_PM1aCntGas is the raw extended GAS. Populated even when rejected,
	// so breadcrumbs and tests can show WHY the fallback fired.
	XPM1aCntGas GAS
}

// Resolve PM1a_CNT the way the write stage needs it. Validation rules for
// a usable gas: SystemIO space, 16-bit register (PM1a_CNT is a 2-byte
// register: SLP_STS | SLP_EN/SLP_TYP word), BitOffset 0 within the
// register, AccessSize 0 (unspecified) or 2 (word), and a nonzero base.
//
// Return (gas, true) when the extended field is usable.
func xPM1aUsable(g GAS) bool {
	return g.SpaceID == spaceSystemIO &&
		g.BitWidth == 16 &&
		g.BitOffset == 0 &&
		(g.AccessSize == 0 || g.AccessSize == 2) &&
		g.AddrValid
}

// Parse validates the FADT structure and resolves PM1a_CNT_BLK: prefer the
// X_PM1a_CNT_BLK GAS (offset 172), fall back to the legacy 32-bit field at
// offset 64, reject otherwise. The legacy fallback also requires
// PM1_CNT_LEN == 2 because the writer performs a 16-bit access into the
// block; a different register length means the firmware layout is not what
// the write path assumes.
func Parse(data []byte) (Table, error) {
	if len(data) < 36 {
		return Table{}, fmt.Errorf("fadt: table too short for header: %d bytes", len(data))
	}
	sig := string(data[0:4])
	if sig != Signature {
		return Table{}, fmt.Errorf("fadt: signature %q, want %q", sig, Signature)
	}
	length := binary.LittleEndian.Uint32(data[4:8])
	if length < 36 || int(length) > len(data) {
		return Table{}, fmt.Errorf("fadt: table length field %d outside data size %d", length, len(data))
	}
	data = data[:length]
	var sum uint8
	for _, b := range data {
		sum += b
	}
	if sum != 0 {
		return Table{}, fmt.Errorf("fadt: checksum mismatch (byte sum %d, want 0)", sum)
	}

	t := Table{
		Header: Header{
			OemID:      cstr(data[10:16]),
			OemTableID: cstr(data[16:24]),
			Length:     length,
			Revision:   data[8],
		},
	}
	t.XPM1aCntGas = gas(data[offsetXPM1aCnt : offsetXPM1aCnt+gasLen])

	// Preferred: X_PM1a_CNT_BLK (FADT rev >= 4 explains the X fields;
	// per ACPI spec the legacy field must be used if X is all zero).
	if xPM1aUsable(t.XPM1aCntGas) {
		t.PM1aCntBase = t.XPM1aCntGas.AddrBase
		t.PM1aFromX = true
	} else {
		// Fallback: legacy 32-bit PM1a_CNT_BLK at offset 64.
		if length < 68 {
			return Table{}, fmt.Errorf("fadt: length %d too small for legacy PM1a_CNT_BLK", length)
		}
		legacy := uint64(binary.LittleEndian.Uint32(data[offsetPM1aCntLegacy:]))
		pm1CntLen := uint8(0)
		if length > offsetPM1CntLen {
			pm1CntLen = data[offsetPM1CntLen]
		}
		if legacy == 0 {
			return Table{}, fmt.Errorf(
				"fadt: no usable PM1a_CNT_BLK: X_PM1a invalid (space=%d width=%d offset=%d access=%d addr=0x%x) and legacy field is 0",
				t.XPM1aCntGas.SpaceID, t.XPM1aCntGas.BitWidth, t.XPM1aCntGas.BitOffset,
				t.XPM1aCntGas.AccessSize, t.XPM1aCntGas.AddrBase)
		}
		if pm1CntLen != 2 {
			return Table{}, fmt.Errorf(
				"fadt: legacy PM1a_CNT_BLK=0x%x requires PM1_CNT_LEN=2, got %d", legacy, pm1CntLen)
		}
		t.PM1aCntBase = legacy
	}
	if length > offsetPM1bCntLegacy+3 {
		t.PM1bCntBase = uint64(binary.LittleEndian.Uint32(data[offsetPM1bCntLegacy:]))
	}
	return t, nil
}

// gas decodes 12 bytes of acpi_generic_address.
func gas(b []byte) GAS {
	return GAS{
		SpaceID:    b[0],
		BitWidth:   b[1],
		BitOffset:  b[2],
		AccessSize: b[3],
		AddrBase:   binary.LittleEndian.Uint64(b[4:12]),
		AddrValid:  binary.LittleEndian.Uint64(b[4:12]) != 0,
	}
}

// cstr trims NUL padding from a fixed-width ACPI string field.
func cstr(b []byte) string {
	for i, c := range b {
		if c == 0 {
			return string(b[:i])
		}
	}
	return string(b)
}
