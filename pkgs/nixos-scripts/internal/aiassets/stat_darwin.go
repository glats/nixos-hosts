//go:build darwin

package aiassets

import (
	"io/fs"
	"syscall"
)

func inodeStat(info fs.FileInfo) (ctimeNs int64, ino uint64, ok bool) {
	st, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return 0, 0, false
	}
	return st.Ctimespec.Nano(), st.Ino, true
}
