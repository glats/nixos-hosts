package lollawatch

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

const source = "https://lollapaloozacl.com/"

var (
	ignoredMarkup = regexp.MustCompile(`(?is)<!--.*?(?:-->|$)|<(?:script|template)\b[^>]*>.*?</(?:script|template)\s*>`)
	startTag      = regexp.MustCompile(`(?i)<([a-z][^\s/>]*)(\s(?:[^'"<>]|"[^"]*"|'[^']*')*)?/?>`)
	tagAttribute  = regexp.MustCompile(`^\s+([^\s"'<>/=\x60]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>\x60]+)))?`)
	scheduleImage = regexp.MustCompile(`(?i)(?:^|[-_])lollacl(?:20)?27[-_]horarios[-_][a-z0-9_-]*?(?:vie(?:rnes)?[-_]?12|sab(?:ado)?[-_]?13|dom(?:ingo)?[-_]?14)(?:[-_][a-z0-9_-]+)?\.(?:jpe?g|png|webp)$`)
	botToken      = regexp.MustCompile(`^[0-9]+:[A-Za-z0-9_-]+$`)
)

type schedule struct {
	URL string `json:"url"`
}

func validArtwork(u *url.URL) bool {
	return u.Scheme == "https" && u.Host == "lollapaloozacl.com" && u.User == nil &&
		strings.HasPrefix(u.Path, "/wp-content/uploads/") && scheduleImage.MatchString(path.Base(u.Path)) &&
		u.RawQuery == "" && u.Fragment == ""
}

func detectSchedule(body []byte) string {
	base, _ := url.Parse(source)
	for _, tag := range startTag.FindAllSubmatch(ignoredMarkup.ReplaceAll(body, nil), -1) {
		if !bytes.EqualFold(tag[1], []byte("img")) {
			continue
		}
		for attrs := tag[2]; len(attrs) > 0; {
			attr := tagAttribute.FindSubmatch(attrs)
			if attr == nil {
				break
			}
			attrs = attrs[len(attr[0]):]
			if !bytes.EqualFold(attr[1], []byte("src")) {
				continue
			}
			src := string(attr[2]) + string(attr[3]) + string(attr[4])
			link, err := base.Parse(html.UnescapeString(src))
			if err == nil && validArtwork(link) {
				return link.String()
			}
			break
		}
	}
	return ""
}

func Run(ctx context.Context, client *http.Client, stateDir, credentialsDir string) error {
	if stateDir == "" {
		return errors.New("STATE_DIRECTORY is required")
	}
	publicPath := filepath.Join(stateDir, "schedule.json")
	data, err := os.ReadFile(publicPath)
	var publication schedule
	switch {
	case errors.Is(err, os.ErrNotExist):
		link, err := fetchSchedule(ctx, client)
		if err != nil || link == "" {
			return err
		}
		publication.URL = link
		data, err := json.Marshal(publication)
		if err != nil {
			return err
		}
		if err := writeAtomic(publicPath, data, 0644); err != nil {
			return fmt.Errorf("publish schedule: %w", err)
		}
	case err != nil:
		return fmt.Errorf("read publication: %w", err)
	default:
		if err := json.Unmarshal(data, &publication); err != nil {
			return fmt.Errorf("decode publication: %w", err)
		}
		link, err := url.Parse(publication.URL)
		if err != nil || !validArtwork(link) {
			return errors.New("saved publication does not contain an official schedule URL")
		}
	}

	delivered := filepath.Join(stateDir, "telegram-delivered")
	if _, err := os.Stat(delivered); err == nil || credentialsDir == "" {
		return nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("read Telegram delivery marker: %w", err)
	}
	token, tokenErr := os.ReadFile(filepath.Join(credentialsDir, "telegram-token"))
	chat, chatErr := os.ReadFile(filepath.Join(credentialsDir, "telegram-chat-id"))
	if errors.Is(tokenErr, os.ErrNotExist) && errors.Is(chatErr, os.ErrNotExist) {
		return nil
	}
	if tokenErr != nil || chatErr != nil {
		return errors.New("Telegram requires both readable credentials: telegram-token and telegram-chat-id")
	}
	id, err := strconv.ParseInt(strings.TrimSpace(string(chat)), 10, 64)
	key := strings.TrimSpace(string(token))
	if err != nil || id <= 0 || !botToken.MatchString(key) {
		return errors.New("invalid Telegram token or private chat ID")
	}
	if err := sendTelegram(ctx, client, key, id, publication.URL); err != nil {
		return err
	}
	if err := writeAtomic(delivered, nil, 0600); err != nil {
		return fmt.Errorf("persist Telegram delivery: %w", err)
	}
	return nil
}

func fetchSchedule(ctx context.Context, client *http.Client) (string, error) {
	const maxBody = 4 << 20
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, source, nil)
	if err != nil {
		return "", err
	}
	response, err := client.Do(request)
	if err != nil {
		return "", fmt.Errorf("fetch official site: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("official site returned HTTP %d", response.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, maxBody+1))
	if err != nil {
		return "", fmt.Errorf("read official site: %w", err)
	}
	if len(body) > maxBody {
		return "", errors.New("official site response exceeds size limit")
	}
	return detectSchedule(body), nil
}

func sendTelegram(ctx context.Context, client *http.Client, token string, chatID int64, link string) error {
	payload, err := json.Marshal(struct {
		ChatID int64  `json:"chat_id"`
		Text   string `json:"text"`
	}{chatID, "Ya se publicaron horarios de Lollapalooza Chile 2027:\n" + link + "\nhttps://lolla.glats.org/"})
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.telegram.org/bot"+token+"/sendMessage", bytes.NewReader(payload))
	if err != nil {
		return errors.New("build Telegram notification request")
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := client.Do(request)
	if err != nil {
		return errors.New("Telegram notification request failed")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("Telegram returned HTTP %d", response.StatusCode)
	}
	var result struct{ OK bool }
	if err := json.NewDecoder(io.LimitReader(response.Body, 65536)).Decode(&result); err != nil || !result.OK {
		return errors.New("Telegram did not confirm delivery")
	}
	return nil
}

func writeAtomic(name string, data []byte, mode os.FileMode) error {
	file, err := os.CreateTemp(filepath.Dir(name), ".lolla-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err := file.Write(data); err != nil {
		file.Close()
		return err
	}
	if err := file.Chmod(mode); err != nil {
		file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), name)
}
