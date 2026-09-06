package main

import "testing"

func TestHexRGB(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		r, g, b int
	}{
		{name: "six digits", in: "f2201f", r: 242, g: 32, b: 31},
		{name: "leading hash stripped", in: "#0d73cc", r: 13, g: 115, b: 204},
		{name: "black", in: "000000", r: 0, g: 0, b: 0},
		{name: "white", in: "ffffff", r: 255, g: 255, b: 255},
		{name: "uppercase", in: "FF6600", r: 255, g: 102, b: 0},
		{name: "short input zeroes missing parts", in: "ff", r: 255, g: 0, b: 0},
		{name: "invalid digits yield zero", in: "zzzzzz", r: 0, g: 0, b: 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r, g, b := hexRGB(tt.in)
			if r != tt.r || g != tt.g || b != tt.b {
				t.Errorf("hexRGB(%q) = (%d,%d,%d), want (%d,%d,%d)", tt.in, r, g, b, tt.r, tt.g, tt.b)
			}
		})
	}
}

func TestSwatchString(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{
			// luminance of 000000 is 0 → white foreground
			name: "dark background gets white foreground",
			in:   "000000",
			want: "\x1b[48;2;0;0;0m\x1b[38;2;255;255;255m #000000 \x1b[0m",
		},
		{
			// luminance of ffffff is 255 → black foreground
			name: "bright background gets black foreground",
			in:   "ffffff",
			want: "\x1b[48;2;255;255;255m\x1b[38;2;0;0;0m #ffffff \x1b[0m",
		},
		{
			// luminance of 8a8a8a is (138*299+138*587+138*114)/1000 = 138 → white foreground
			name: "mid gray stays below threshold",
			in:   "8a8a8a",
			want: "\x1b[48;2;138;138;138m\x1b[38;2;255;255;255m #8a8a8a \x1b[0m",
		},
		{
			// luminance of a0a0a0 is 160 → above 145 → black foreground
			name: "light gray crosses threshold",
			in:   "a0a0a0",
			want: "\x1b[48;2;160;160;160m\x1b[38;2;0;0;0m #a0a0a0 \x1b[0m",
		},
		{
			name: "label drops a leading hash",
			in:   "#19cb00",
			want: "\x1b[48;2;25;203;0m\x1b[38;2;255;255;255m #19cb00 \x1b[0m",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := swatchString(tt.in); got != tt.want {
				t.Errorf("swatchString(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}
