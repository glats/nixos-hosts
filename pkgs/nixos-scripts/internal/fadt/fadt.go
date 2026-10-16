package fadt

import (
	"encoding/binary"
	"fmt"
)

const Signature = "FACP"

const (
	offsetPM1aCntLegacy = 64
	offsetPM1bCntLegacy = 68
	offsetPM1CntLen     = 89
	offsetFlags         = 112
	offsetResetReg      = 116
	offsetXfacs         = 132
	offsetXdsdt         = 140
	offsetXPM1aCnt      = 172
	offsetXPM1bCnt      = 184
	gasLen              = 12
)

const (
	spaceSystemIO = 1
	spaceMemory   = 0
)

type GAS struct {
	SpaceID    uint8
	BitWidth   uint8
	BitOffset  uint8
	AccessSize uint8
	AddrBase   uint64
	AddrValid  bool
}

type Header struct {
	OemID      string
	OemTableID string
	Length     uint32
	Revision   uint8
}

type Table struct {
	Header Header

	PM1aCntBase uint64
	PM1aFromX   bool
	PM1bCntBase uint64

	XPM1aCntGas GAS
}

func xPM1aUsable(g GAS) bool {
	return g.SpaceID == spaceSystemIO &&
		g.BitWidth == 16 &&
		g.BitOffset == 0 &&
		(g.AccessSize == 0 || g.AccessSize == 2) &&
		g.AddrValid
}

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

	if xPM1aUsable(t.XPM1aCntGas) {
		t.PM1aCntBase = t.XPM1aCntGas.AddrBase
		t.PM1aFromX = true
	} else {

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

func cstr(b []byte) string {
	for i, c := range b {
		if c == 0 {
			return string(b[:i])
		}
	}
	return string(b)
}
