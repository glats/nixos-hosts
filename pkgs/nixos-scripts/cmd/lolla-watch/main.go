package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/glats/nixos-scripts/internal/lollawatch"
)

func main() {
	client := &http.Client{
		Timeout: 20 * time.Second,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	if err := lollawatch.Run(context.Background(), client, os.Getenv("STATE_DIRECTORY"), os.Getenv("CREDENTIALS_DIRECTORY")); err != nil {
		log.Fatal(err)
	}
}
