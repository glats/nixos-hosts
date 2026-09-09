// Package dsdt is a strict AML scanner for the S5 sleep package. It finds
// ONE root `Name(\_S5, Package(){int, int, int, int})` definition in a DSDT
// and extracts SLP_TYPa (package element 0: the value OSPM writes into the
// PM1a_CNT.SLP_TYP bits before setting SLP_EN).
//
// The scanner is intentionally NARROW — it is not an AML interpreter. Root
// scope is approximated by matching DefName (0x08) followed by an optional
// RootChar (0x5C) and the 4-char name "_S5_"; relative names (namespaced
// under a Scope, prefix chars like '^') are skipped. This is fail-closed:
// if the live DSDT does not encode _S5 as a scoped-root literal package,
// the scan reports "missing _S5" and the write path stays off instead of
// guessing. Any deviation — a second \_S5 definition, non-literal elements
// (method results, named references, operator expressions), a _S5 that is
// not a 4-element package — is a hard error.
package dsdt

import (
	"fmt"
)

// AML opcodes used by the scanner (ACPI spec, AML grammar).
const (
	opName    = 0x08 // DefName
	opRoot    = 0x5C // RootChar '\' — name is in the root namespace
	opPackage = 0x12 // PackageOp (also 0x13 VarPackageOp, unsupported)
	opZero    = 0x00
	opOne     = 0x01
	opByte    = 0x0A
	opWord    = 0x0B
	opDWord   = 0x0C
	opQWord   = 0x0E // QWordConstOp
	opOnes    = 0xFF
)

// s5Name is the 4-char ACPI name of the S5 package ("_S5" padded).
var s5Name = [4]byte{'_', 'S', '5', '_'}

// Result is the recovered S5 data.
type Result struct {
	SLPTypA uint64 // element 0: PM1a_CNT SLP_TYP value
	SLPTypB uint64 // element 1: PM1b_CNT SLP_TYP value (unused when PM1b absent)
	// All four extracted elements (reserved elements 2-3 kept for tests
	// and diagnostics breadcrumbs).
	Elements [4]uint64
	Offset   int // byte offset of the NameOp in the DSDT
}

// Scan data (full AML of a DSDT's DefinitionBlock) for the root \_S5
// package described in the package doc. Errors name the reason: missing,
// ambiguous, or malformed/non-literal.
func Scan(data []byte) (Result, error) {
	var found int
	var res Result
	for i := 0; i < len(data)-6; i++ {
		if data[i] != opName {
			continue
		}
		j := i + 1
		// RootChar optional (a top-level DefName in the root namespace
		// may be encoded without the '\' prefix).
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

// parseS5Package parses "PackageOp PkgLength NumElements elements..." at p
// and requires ALL elements to be integer literals.
func parseS5Package(data []byte, p int) (Result, error) {
	if p >= len(data) {
		return Result{}, fmt.Errorf("truncated: no bytes after name")
	}
	if data[p] != opPackage {
		return Result{}, fmt.Errorf(
			"unsupported form: next byte 0x%02x is not PackageOp (methods/references are refused)", data[p])
	}
	p++ // consume the PackageOp
	ln, n, err := pkgLength(data, p)
	if err != nil {
		return Result{}, err
	}
	p += n
	// PkgLength counts its own encoding plus the following data, NOT the
	// opcode byte (ACPI spec, AML grammar). Data extent after the length
	// field is ln - n, so the package ends at p + (ln - n).
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
	// Tolerate NOTHING after the four declared elements inside the object.
	if p != end {
		return Result{}, fmt.Errorf("%d trailing bytes inside package object", end-p)
	}
	res.SLPTypA = res.Elements[0]
	res.SLPTypB = res.Elements[1]
	return res, nil
}

// pkgLength decodes a PkgLength (1-4 byte encoding; bit 6-7 of the first
// byte select the length-byte count, bits 0-3 participate in the value).
// Returns the decoded byte count and how many header bytes were consumed.
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
	// follow==0 is 1 header byte with 6 value bits; else follow+1 bytes.
	total += int(follow)
	return val, total, nil
}

// intConst parses one TermArg that must be an integer literal (IntObj
// encodings or Zero/One/Ones constants). Anything else — a method CALL,
// named reference, or nested term — is an error: the scanner cannot tell
// what such a value would be at runtime and must not guess a sleep type.
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

// intConst helper: op at data[p], then a little-endian integer of size n.
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
