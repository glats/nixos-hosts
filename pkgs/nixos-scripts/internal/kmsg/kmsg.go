package kmsg

import (
	"fmt"
	"os"
)

const Path = "/dev/kmsg"

const (
	UserNotice = 1*8 + 5

	UserWarning = 1*8 + 4
)

type Writer struct {
	Path string
}

func New() *Writer {
	return &Writer{Path: Path}
}

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
