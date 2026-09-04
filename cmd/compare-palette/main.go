// Command compare-palette renders a side-by-side truecolor palette table
// comparing the nix-colors theme against the MATE terminal and
// Ghostty/Kitty bright-color slots, plus a decision guide.
//
// Port of bin/compare-palette: byte-identical terminal output. Pure stdout
// rendering — no subprocesses, no arguments; run in any truecolor terminal
// (Ghostty, Kitty, MATE Terminal).
package main

import (
	"fmt"
	"strconv"
	"strings"
)

// ── palette definitions ─────────────────────────────────────────────────────

// nix-colors (theme.nix) — source of truth.
const (
	nc00 = "000000"
	nc01 = "0a0a0a"
	nc02 = "505050"
	nc03 = "8a8a8a"
	nc04 = "a0a0a0"
	nc05 = "dddddd"
	nc06 = "d0d0d0"
	nc07 = "ffffff"
	nc08 = "cc0403"
	nc09 = "f2201f"
	nc0a = "cecb00"
	nc0b = "19cb00"
	nc0c = "0dcdcd"
	nc0d = "0d73cc"
	nc0e = "cb1ed1"
	nc0f = "ff6600"
)

// Terminal color slots (0–15): normals 0–8 and slot 15 are identical in all
// apps (from nix-colors). nc01 and nc06 stay declared above to mirror the
// documented nix-colors palette even though the color slots never reference
// them (bash parity).
var norm = [9]string{nc00, nc08, nc0b, nc0a, nc0d, nc0e, nc0c, nc05, nc03}

// nix-colors brights (9–14): reuse palette, no separate bright variant.
var nixBright = [6]string{nc09, nc0b, nc0a, nc0d, nc0e, nc0c}

// MATE terminal brights 9–14 (hardcoded in mate.nix, decoded from
// RRRRGGGGBBBB).
var mateBright = [6]string{"ff2211", "22ff00", "ffff00", "1188ff", "ff22ff", "11ffff"}

// Ghostty + Kitty brights 9–14 (identical in both, hardcoded).
var gkBright = [6]string{"f2201f", "23fd00", "fffd00", "1a8fff", "fd28ff", "14ffff"}

var roles = [16]string{
	"black", "red", "green", "yellow",
	"blue", "magenta", "cyan", "white",
	"bright black",
	"bright red", "bright green", "bright yellow",
	"bright blue", "bright magenta", "bright cyan",
	"bright white",
}

// hexRGB parses #rrggbb / rrggbb into components. Bash computed the pairs
// with $((16#...)); short or invalid input yields zeros here.
func hexRGB(hex string) (r, g, b int) {
	hex = strings.TrimPrefix(hex, "#")
	part := func(s string) int {
		n, err := strconv.ParseUint(s, 16, 32)
		if err != nil {
			return 0
		}
		return int(n)
	}
	if len(hex) >= 2 {
		r = part(hex[0:2])
	}
	if len(hex) >= 4 {
		g = part(hex[2:4])
	}
	if len(hex) >= 6 {
		b = part(hex[4:6])
	}
	return r, g, b
}

// swatchString renders a colored swatch with the hex value as label,
// matching the bash printf exactly (48;2 background, luminance-chosen
// 38;2 foreground).
func swatchString(raw string) string {
	hex := strings.TrimPrefix(raw, "#")
	r, g, b := hexRGB(hex)
	lum := (r*299 + g*587 + b*114) / 1000
	fgR, fgG, fgB := 255, 255, 255
	if lum > 145 {
		fgR, fgG, fgB = 0, 0, 0
	}
	return fmt.Sprintf("\x1b[48;2;%d;%d;%dm\x1b[38;2;%d;%d;%dm #%s \x1b[0m", r, g, b, fgR, fgG, fgB, hex)
}

// swatch prints a colored swatch.
func swatch(hex string) {
	fmt.Print(swatchString(hex))
}

// sep prints the separator line (72 box-drawing dashes, as in the original).
func sep() {
	fmt.Printf("  %s\n", strings.Repeat("─", 72))
}

func main() {
	fmt.Print("\n")
	fmt.Print("  \x1b[1mPalette Comparison\x1b[0m\n")
	fmt.Print("\n")
	fmt.Print("  \x1b[32m✅ fully on nix-colors:\x1b[0m  conky  rofi  btop  tmux\n")
	fmt.Print("  \x1b[33m⚠️  brights hardcoded:\x1b[0m   MATE terminal  Ghostty  Kitty  kmscon (not set)\n")
	fmt.Print("\n")
	sep()
	fmt.Printf("  \x1b[1m%-3s  %-14s   %-12s   %-12s   %-12s\x1b[0m\n",
		"#", "role", "nix-colors", "MATE term", "Ghostty/Kitty")
	sep()

	// ── normals 0–8 (all identical) ──────────────────────────────────────

	fmt.Print("\n  \x1b[2mNormals — same in all apps:\x1b[0m\n\n")

	for i := 0; i <= 8; i++ {
		fmt.Printf("  \x1b[2m%2d\x1b[0m  %-14s   ", i, roles[i])
		swatch(norm[i])
		fmt.Print("   \x1b[2m(all equal)\x1b[0m")
		fmt.Print("\n")
	}

	// ── brights 9–14 (the interesting part) ──────────────────────────────

	fmt.Print("\n")
	sep()
	fmt.Print("\n  \x1b[1mBrights 9–14 — here's the difference:\x1b[0m\n\n")
	fmt.Printf("  \x1b[1m%-3s  %-14s   %-12s   %-12s   %-12s\x1b[0m\n",
		"#", "role", "nix-colors", "MATE term", "Ghostty/Kitty")
	fmt.Print("\n")

	for i := 0; i <= 5; i++ {
		idx := i + 9
		nc := nixBright[i]
		mate := mateBright[i]
		gk := gkBright[i]

		fmt.Printf("  %2d  %-14s   ", idx, roles[idx])
		swatch(nc)
		fmt.Print("   ")
		swatch(mate)
		fmt.Print("   ")
		swatch(gk)

		// Flag if all three differ.
		if nc != mate && nc != gk && mate != gk {
			fmt.Print("   \x1b[31m← all differ\x1b[0m")
		} else if nc == mate && nc == gk {
			fmt.Print("   \x1b[32m← equal\x1b[0m")
		} else if mate == gk {
			fmt.Print("   \x1b[33m← MATE≠nix, Ghostty=MATE\x1b[0m")
		}
		fmt.Print("\n")
	}

	// ── slot 15 ──────────────────────────────────────────────────────────

	fmt.Print("\n")
	fmt.Printf("  \x1b[2m15  %-14s   \x1b[0m", "bright white")
	swatch(nc07)
	fmt.Print("   \x1b[2m(all equal)\x1b[0m\n")

	// ── decision guide ───────────────────────────────────────────────────

	fmt.Print("\n")
	sep()
	fmt.Print("\n  \x1b[1mWhat each option means:\x1b[0m\n\n")
	fmt.Print("  \x1b[1m1. Pure nix-colors\x1b[0m    → brights = same as normals. Bold text: no extra \"pop\".\n")
	fmt.Print("  \x1b[2m                       Advantage: one place to change everything (theme.nix).\x1b[0m\n\n")
	fmt.Print("  \x1b[1m2. MATE brights\x1b[0m       → more saturated/neon. Bold stands out from normal text.\n")
	fmt.Print("  \x1b[2m                       Today: MATE and Ghostty/Kitty differ slightly from each other.\x1b[0m\n\n")
	fmt.Print("  \x1b[1m3. Ghostty/Kitty brights\x1b[0m → same as option 2, same values in both apps.\n")
	fmt.Print("  \x1b[2m                           Bringing MATE to these values = perfect sync across the three.\x1b[0m\n\n")
	fmt.Print("  \x1b[1m4. Define brights in theme.nix\x1b[0m → extend the palette with base17–base1B.\n")
	fmt.Print("  \x1b[2m                                   Maximum control, a single source of truth.\x1b[0m\n\n")
	sep()
	fmt.Print("\n")
}
