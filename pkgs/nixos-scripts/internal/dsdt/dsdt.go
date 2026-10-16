package dsdt

import (
	"fmt"
)

const (
	opName    = 0x08
	opRoot    = 0x5C
	opPackage = 0x12
	opZero    = 0x00
	opOne     = 0x01
	opByte    = 0x0A
	opWord    = 0x0B
	opDWord   = 0x0C
	opQWord   = 0x0E
	opOnes    = 0xFF
)

var s5Name = [4]byte{'_', 'S', '5', '_'}

type Result struct {
	SLPTypA uint64
	SLPTypB uint64

	Elements [4]uint64
	Offset   int
}

func Scan(data []byte) (Result, error) {
	var found int
	var res Result
	for i := 0; i < len(data)-6; i++ {
		if data[i] != opName {
			continue
		}
		j := i + 1

		if data[j] == opRoot {
			j++
		}
		if j+4 > len(data) || data[j] != s5Name[0] {
			continue
		}
		if string(data[j:j+4]) != string(s5Name[:]) {
			continue
		}
		found++
		if found > 1 {
			return Result{}, fmt.Errorf("dsdt: ambiguous \\_S5: second NameOp at offset %d (first at %d)", i, res.Offset)
		}
		r, err := parseS5Package(data, j+4)
		if err != nil {
			return Result{}, fmt.Errorf("dsdt: \\_S5 at offset %d: %w", i, err)
		}
		res = r
		res.Offset = i
	}
	switch {
	case found == 0:
		return Result{}, fmt.Errorf("dsdt: no root \\_S5 NameOp found")
	case res.SLPTypA > 7 || res.SLPTypB > 7:
		return Result{}, fmt.Errorf("dsdt: _S5 SLP_TYP values (%d, %d) exceed the 3-bit field", res.SLPTypA, res.SLPTypB)
	}
	return res, nil
}

func parseS5Package(data []byte, p int) (Result, error) {
	if p >= len(data) {
		return Result{}, fmt.Errorf("truncated: no bytes after name")
	}
	if data[p] != opPackage {
		return Result{}, fmt.Errorf(
			"unsupported form: next byte 0x%02x is not PackageOp (methods/references are refused)", data[p])
	}
	p++
	ln, n, err := pkgLength(data, p)
	if err != nil {
		return Result{}, err
	}
	p += n

	end := p + ln - n
	if end > len(data) {
		return Result{}, fmt.Errorf("package length %d exceeds table size", ln)
	}
	if p >= end {
		return Result{}, fmt.Errorf("truncated package")
	}
	numElements := int(data[p])
	p++
	if numElements != 4 {
		return Result{}, fmt.Errorf("package has %d elements, _S5 requires exactly 4 (SLP_TYPa, SLP_TYPb, 2 reserved)", numElements)
	}
	var res Result
	for k := 0; k < numElements; k++ {
		v, n, err := intConst(data, p, end)
		if err != nil {
			return Result{}, fmt.Errorf("element %d: %w", k, err)
		}
		res.Elements[k] = v
		p += n
	}

	if p != end {
		return Result{}, fmt.Errorf("%d trailing bytes inside package object", end-p)
	}
	res.SLPTypA = res.Elements[0]
	res.SLPTypB = res.Elements[1]
	return res, nil
}

func pkgLength(data []byte, p int) (int, int, error) {
	if p >= len(data) {
		return 0, 0, fmt.Errorf("truncated PkgLength")
	}
	follow := data[p] >> 6
	val := int(data[p] & 0x0F)
	total := 1
	for k := 0; k < int(follow); k++ {
		if p+1+k >= len(data) {
			return 0, 0, fmt.Errorf("truncated PkgLength multi-byte encoding")
		}
		val |= int(data[p+1+k]) << uint(4+8*k)
	}

	total += int(follow)
	return val, total, nil
}

func intConst(data []byte, p, end int) (uint64, int, error) {
	if p >= end {
		return 0, 0, fmt.Errorf("truncated element")
	}
	switch data[p] {
	case opZero:
		return 0, 1, nil
	case opOne:
		return 1, 1, nil
	case opOnes:
		return 0xFFFFFFFFFFFFFFFF, 1, nil
	case opByte:
		return intOf(data, p, end, 1)
	case opWord:
		return intOf(data, p, end, 2)
	case opDWord:
		return intOf(data, p, end, 4)
	case opQWord:
		return intOf(data, p, end, 8)
	default:
		return 0, 0, fmt.Errorf("non-literal element (op 0x%02x): only integer constants are supported", data[p])
	}
}

func intOf(data []byte, p, end, n int) (uint64, int, error) {
	if p+1+n > end {
		return 0, 0, fmt.Errorf("truncated %d-byte constant", n)
	}
	var v uint64
	for k := n - 1; k >= 0; k-- {
		v = v<<8 | uint64(data[p+1+k])
	}
	return v, 1 + n, nil
}
