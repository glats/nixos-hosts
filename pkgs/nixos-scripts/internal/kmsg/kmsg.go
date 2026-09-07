// Package kmsg writes breadcrumb lines to /dev/kmsg, the kernel message
// buffer. Breadcrumbs written here reach the journal, netconsole (once a
// target is configured), EFI pstore dumps (with printk.always_kmsg_dump=1)
// and shutdown-debug captures, so they are the ordered evidence trail for
// the rog S5 poweroff investigation.
//
// This package is shared: netconsole-setup (readiness probe + setup
// breadcrumbs) today, rog-poweroff-hook (rog-s5: shutdown breadcrumbs)
// later.
package kmsg

import (
	"fmt"
	"os"
)

// Path is the kernel message buffer device file.
const Path = "/dev/kmsg"

// Syslog priority values used by this module. PRI = facility*8 + severity;
// userspace breadcrumbs use facility 1 (user), matching the "<N>" printk
// prefixes the receiver tolerates in the netconsole contract.
const (
	// UserNotice is facility user (1) + severity notice (5): "<13>".
	UserNotice = 1*8 + 5
	// UserWarning is facility user (1) + severity warning (4): "<12>".
	UserWarning = 1*8 + 4
)

// Writer appends lines to a kernel message buffer device (Path, default
// /dev/kmsg). Every Write opens the device fresh so multiple breadcrumb
// writers in one process stay independent; tests inject a plain file path.
type Writer struct {
	Path string
}

// New returns a Writer targeting the real kernel message buffer.
func New() *Writer {
	return &Writer{Path: Path}
}

// Write emits one breadcrumb line at the given syslog priority. The "<N>"
// prefix is parsed by the kernel (facility/severity metadata, stripped from
// the stored message) and the trailing newline terminates the record, so
// the line appears in netconsole/kmsg as a standalone breadcrumb.
func (w *Writer) Write(prio int, msg string) error {
	f, err := os.OpenFile(w.device(), os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		return fmt.Errorf("kmsg: open %s: %w", w.device(), err)
	}
	line := fmt.Sprintf("<%d>%s\n", prio, msg)
	if _, err := f.WriteString(line); err != nil {
		f.Close()
		return fmt.Errorf("kmsg: write %s: %w", w.device(), err)
	}
	return f.Close()
}

func (w *Writer) device() string {
	if w.Path == "" {
		return Path
	}
	return w.Path
}
