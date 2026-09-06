package main

import (
	"regexp"
	"testing"
)

func TestFilterLines(t *testing.T) {
	cases := []struct {
		name string
		in   string
		re   *regexp.Regexp
		want []string
	}{
		{
			name: "routing default and 172 subnets",
			in:   "default via 192.168.1.1 dev enp2s0f0\n172.16.0.0/24 dev enp5s0\n10.13.13.0/24 dev wg0\n192.168.1.0/24 dev enp2s0f0\n",
			re:   routeRe,
			want: []string{
				"default via 192.168.1.1 dev enp2s0f0",
				"172.16.0.0/24 dev enp5s0",
			},
		},
		{
			name: "routing dot is literal (172x must not match)",
			in:   "17216x nope\ndefault via 1.2.3.4 dev eth0\n",
			re:   routeRe,
			want: []string{"default via 1.2.3.4 dev eth0"},
		},
		{
			name: "no routing match is empty (bash: pipefail death)",
			in:   "10.0.0.0/24 dev eth0\n",
			re:   routeRe,
			want: nil,
		},
		{
			name: "empty input",
			in:   "",
			re:   routeRe,
			want: nil,
		},
		{
			name: "ethtool -i driver lines",
			in:   "driver: r8169\nversion: 6.2.0\nfirmware-version: rtl8168g-3_0.0.1\nbus-info: 0000:02:00.0\nexpansion-rom-version: \n",
			re:   ethtoolIRe,
			want: []string{
				"driver: r8169",
				"firmware-version: rtl8168g-3_0.0.1",
				"bus-info: 0000:02:00.0",
			},
		},
		{
			name: "ethtool -S error stats case-insensitive, read -r trims",
			in:   "NIC statistics:\n     rx_errors: 3\n     tx_dropped: 0\n     rx_crc_errors: 1\n     rx_bytes: 999\n     multicast: 5\n",
			re:   ethtoolSRe,
			want: []string{
				"rx_errors: 3",
				"tx_dropped: 0",
				"rx_crc_errors: 1",
			},
		},
		{
			name: "ip route trailing spaces are trimmed by read -r",
			in:   "default via 172.16.0.1 dev enp3s0 metric 100  \n",
			re:   routeRe,
			want: []string{"default via 172.16.0.1 dev enp3s0 metric 100"},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := filterLines(tc.in, tc.re)
			if len(got) != len(tc.want) {
				t.Fatalf("got %d lines %q, want %d %q", len(got), got, len(tc.want), tc.want)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("line %d = %q, want %q", i, got[i], tc.want[i])
				}
			}
		})
	}
}

func TestLastLine(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"", ""},
		{"\n", ""},
		{"round-trip: 0.3 ms\n", "round-trip: 0.3 ms"},
		{"line1\nline2\n", "line2"},
		{"line1\n\n", ""}, // tail -1 of "a\n\n" is an empty line
		{"no trailing newline", "no trailing newline"},
		{"a\n\nb", "b"},
		{"ping: send failure\n", "ping: send failure"},
	}
	for _, tc := range cases {
		if got := lastLine(tc.in); got != tc.want {
			t.Errorf("lastLine(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestBCScale1(t *testing.T) {
	// bc `scale=1` truncates instead of rounding — pinned here because
	// the throughput output must match the bash original byte-for-byte.
	cases := []struct {
		in   float64
		want string
	}{
		{10.4976 * 1048576 / 1048576, "10.4"}, // truncation, not 10.5
		{10485760.0 / 1048576, "10.0"},
		{524288.0 / 1048576, "0.5"},
		{0.05 * 1048576 / 1048576, "0.0"},
		{123456789.0 / 1048576, "117.7"},
		{104857599.0 / 1048576, "99.9"},
	}
	for _, tc := range cases {
		if got := bcScale1(tc.in); got != tc.want {
			t.Errorf("bcScale1(%v) = %q, want %q", tc.in, got, tc.want)
		}
	}
}
