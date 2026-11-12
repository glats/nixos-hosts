package gastown

import (
	"os"
	"testing"
)

func TestMain(m *testing.M) {
	for key, value := range map[string]string{
		"GIT_CONFIG_GLOBAL": os.DevNull, "GIT_CONFIG_NOSYSTEM": "1",
		"GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@localhost",
		"GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@localhost",
	} {
		os.Setenv(key, value)
	}
	os.Exit(m.Run())
}
