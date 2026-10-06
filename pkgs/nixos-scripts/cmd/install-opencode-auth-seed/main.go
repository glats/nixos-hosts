package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "install-opencode-auth-seed: legacy auth seeding is retired; sign in with `opencode2-home auth login openai` on macm5")
	os.Exit(1)
}
