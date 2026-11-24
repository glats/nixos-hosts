# Lollapalooza 2027 schedule alert
Objective: show confirmed schedule publication on the existing checklist and notify the owner via the existing Telegram bot. Branch: `feat/lolla-2027`; delivery: local changes only pending explicit delivery authorization.
Runners: Go tests and vet, renderer tests, Nix `rog` evaluation and Linux lint. Forecast: approximately 350–450 authored lines.

## Specs

S1. “podemos armar como un subscridotr? hahaha en golang” — run a Go watcher against the official festival site; the daily lineup alone is not a schedule. Use the previous edition as a fixture, not a positive result for 2027.
S2. “hm  por la misma pagina . pero si puede ser el telmgra. tengo un bot.~ /PRoject/don-bot” and “Página y Telegram” — display the announcement and official link on `lolla.glats.org` without rebuilding the page, and send the same announcement to the owner's chat using the existing bot. Preserve favorites and do not modify the bot or start a second poller. Normal subsequent runs must not resend a confirmed delivery.
S3. Owner-operated deployment: no credential access, live messaging, activation, commit, or push without applicable authorization. Verify locally against representative inputs and mock HTTP.

## Tasks

- T1 · S1–S3 · inline · locally verified · Go watcher; focused tests, suite, vet, and bounded independent recheck passed; real 2027 artwork and Telegram delivery pending.
- T2 · S2–S3 · inline · locally verified · renderer, Chromium, pinned evaluation and lint passed; native review and operator-owned deployment pending.

## Log

L1. User: “podemos armar como un subscridotr? hahaha en golang”
L2. User: “hm  por la misma pagina . pero si puede ser el telmgra. tengo un bot.~ /PRoject/don-bot”
L3. User selected “Página y Telegram”.
L4. Baseline `152d0916`; current official homepage has 2027 lineup art, while the official 2026 archive has an actual `LOLLACL26-Horarios_1080x1440-DOM15.jpg` image. The future 2027 file format is not yet known. Use an explicit current-edition schedule marker on official artwork and fail closed. The bot need not change: an outbound-only Bot API call can reuse its identity with credentials supplied by the operator. The website must work without Telegram credentials.
L5. Go focused RED: missing watcher implementation; GREEN: detection fixtures, web-first publication, mocked Telegram retry, redaction and confirmed-delivery persistence. A credential-free CLI run successfully fetched the official site and found no matching 2027 schedule.
L6. Renderer RED: the hidden notice was absent; GREEN: all three renderer tests passed. Local headless Chromium verified hidden before publication, visible with an official link after a fixture publication, hidden with a foreign origin, and all 86 checklist inputs retained in each case. A first browser probe counted the script's selector as an input; the corrected probe counts only input tags and passed.
L7. Risk items 2 and 5: a new public nginx location, outbound bot credential and deployed systemd service. Scope the public location to one generated JSON file; use operator-supplied systemd credentials, not the Home Manager token path. No don-bot or secret changes, stage, commit, push, or activation.
L8. Linux `nix flake check --no-build --no-write-lock-file "path:$PWD"` passed (existing Home Manager version warning; omitted Darwin). Separate `macm5` evaluation failed because this runner is Linux and an existing asset derivation requires `aarch64-darwin`; the exact baseline commit reproduced both failing derivation paths.
L9. `go -C pkgs/nixos-scripts test ./...`, `go -C pkgs/nixos-scripts vet ./...`, pinned `rog` toplevel evaluation, Linux lint and check-only format passed. Rendered NixOS units and exact nginx alias confirmed; nginx configuration derivation passed its check. Parent's uncached focused Go spot check passed. Independent verifier launched; operator-owned Telegram provisioning and live HTTPS remain pending.
L10. Independent verification found that the detector could read a URL quoted inside `alt` as the actual `src`, invalidating the S1/S2 trigger. S3 passed within authorized local scope; recipient validation, Telegram redaction and persistence, and baseline favorites preservation also passed. Parent reproduced the false match and two adjacent attribute-boundary cases before changing extraction. Uncached focused Go tests, the Go suite, vet, and `git diff --check` passed after the correction; bounded independent recheck pending.
L11. Post-correction Linux lint rebuilt both lint derivations and completed without a reported error. The bounded independent recheck passed all nine worktree detection cases and all nine scratch probes, including the original `alt` failure. Verifier scratch was removed.
L12. Native assessment with explicit source/doc inventory returned `high` / `high_risk`. Native STATUS requires a bound `gentle-ai.review-intended-untracked-selection/v1` JSON submission but did not provide the JSON value shape in the collection result or CLI help. No START, consent, native approval, staging, or delivery was performed. Telegram provisioning, live delivery and production HTTPS remain operator-owned.
L13. User: “hay que tener en cuenta que este computador se apaga durante s noches y tiene que ser un servicio que solamente funciona cuando el computador est encendido prcticamente” — confirmed the current machine is `rog`; the timer checks five minutes after boot and hourly while running, without waking the machine.
L14. User: “dejalo commit en master push y Sync remoto y local. admeas agrega al lado de los links YouTube Spotify igual” — authorizes this feature's local commit and Git synchronization to `master`, not service activation. The renderer pairs every YouTube Music link with a labeled Spotify search; it preserves the artist substitutions and fallback. The new renderer test failed before implementation; all four renderer tests and the focused Go watcher suite passed afterward.
