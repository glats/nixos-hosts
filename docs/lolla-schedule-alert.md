# Lollapalooza Chile 2027 schedule alert

On `rog`, `lolla-watch.timer` checks the official homepage hourly. It publishes
`/schedule.json` on the checklist hostname when it finds a current-edition
schedule image. The checklist reads this file on page load. The daily lineup,
other editions, and unrelated website changes do not trigger an alert. The
detector is based on the organizer's 2026 artwork naming; if the organizer
publishes elsewhere or changes that format, update the detector after checking
the actual publication.

The page does not require Telegram. To enable private delivery as the operator,
create root-readable files containing the existing DonBot token and the
recipient's positive private chat ID. Add a systemd drop-in for
`lolla-watch.service` using the actual absolute paths:

```ini
[Service]
LoadCredential=telegram-token:/path/to/don-bot-token
LoadCredential=telegram-chat-id:/path/to/private-chat-id
```

Do not put secret values in the drop-in, the Nix store, or the repository. The
recipient must have started a private chat with DonBot. The watcher only calls
Telegram's `sendMessage`; the existing bot keeps handling incoming updates.

After applying the configuration, inspect `systemctl status lolla-watch.timer`
and `journalctl -u lolla-watch.service`. A missing `/schedule.json` is normal
before a match; the checklist and its favorites still work. If Telegram is
configured after publication, the next run attempts delivery. The watcher
remembers confirmed delivery; an ambiguous network failure can still result in
a duplicate if Telegram accepted the message but the response was lost.
