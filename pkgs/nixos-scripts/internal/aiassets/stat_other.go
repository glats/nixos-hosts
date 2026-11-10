//go:build !linux && !darwin

package aiassets

import "io/fs"

func inodeStat(fs.FileInfo) (int64, uint64, bool) { return 0, 0, false }
