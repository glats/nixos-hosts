# gpg-unlock

Cache the passphrase of each git signing key once, so signed commits stop
prompting. gpg-agent holds the unlocked passphrase (the cache TTL is high on
every host: 34560000 seconds, set in `linux/system/base/users.nix` and
`darwin/home/gpg.nix`), so after one run signed commits ask nothing again
until the agent restarts or the cache entry expires.

- Source: `pkgs/nixos-scripts/cmd/gpg-unlock/main.go` (thin entry point),
  logic in `pkgs/nixos-scripts/internal/gpgunlock/`.
- The key list is rendered at runtime by sops-nix from the SOPS managed
  signing fingerprints, at
  `$XDG_CONFIG_HOME/sops-nix/secrets/rendered/gpg-unlock-keys`
  (`$HOME/.config/sops-nix/secrets/rendered/gpg-unlock-keys` when
  `XDG_CONFIG_HOME` is unset). `NIXOS_SCRIPTS_GPG_KEYS_FILE` overrides that
  file, and an unreadable override is an error.
- Keys unlocked, in order: `git config user.signingkey` first (the current
  repo's key), then every key from the list, deduplicated.

## Signing keys

The personal and work signing keys are not part of the public configuration.
The Home Manager modules write them at activation time from the SOPS managed
fingerprints, one file per scope:

| Scope | Linux | macOS |
| --- | --- | --- |
| Everywhere | `~/.config/git/signing-personal` | `~/.config/git/signing-work` |
| Repository scope | `~/.config/git/signing-work` (`~/Work/**`) | `~/.config/git/signing-personal` (`~/Projects/**`) |

The static git configuration carries the `=unavailable-signing-key` sentinel
instead of a real key. The leading `=` asks GnuPG for an exact match on the
OpenPGP user ID, so the value can never select another key by a partial
match. When the runtime fingerprint is missing, empty or not a key id of 8,
16 or 40 hexadecimal digits, the activation writes that sentinel and points
`gpg.program` and `gpg.openpgp.program` at a program that always fails, so
git reports a signing failure instead of signing with another identity. A
scope with a valid fingerprint writes the real gpg program again, so an
unavailable scope never disables signing for the other one. The fingerprint is
never interpolated unchecked, so a malformed secret cannot inject
configuration.

The activation waits for the fingerprint files the same way it waits for the
name and email files, because sops-nix installs the secrets asynchronously.
A fingerprint that arrives late is still used; only a fingerprint that never
arrives falls back to the sentinel.

macOS keeps signing with the work key under `~/.config/nix/**`; that is the
pre-existing behaviour and it is unchanged.

## Usage

Run it with no arguments inside a regular terminal (never inside OpenCode):

```console
$ gpg-unlock
Unlocked: 0123456789ABCDEF0123456789ABCDEF01234567
Unlocked: 89ABCDEF0123456789ABCDEF0123456789ABCDEF
```

Any argument (`--help`, `--version`, ...) prints the usage text and exits
non-zero. For each key the command signs a scratch file inside a temporary
directory, which triggers the passphrase prompt in the current terminal, or a
pinentry dialog when a display is available. A wrong or cancelled passphrase
makes the run exit non-zero and name the key that failed; re-run it to retry.

## Behavior notes

- The passphrase prompt appears in your terminal because `GPG_TTY` is set
  from `tty` when stdin is a terminal, and pinentry-auto picks the flavor:
  with `DISPLAY`/`WAYLAND_DISPLAY` (or a `--display` argument from gpg-agent)
  it execs pinentry-qt; on a real tty without a display (kmscon, plain VT,
  SSH) it execs pinentry-curses, so the prompt is still available there and
  `gpg-unlock` works; with the `opencode` marker in `PINENTRY_USER_DATA` and
  no display, no flavor runs and the passphrase request fails immediately.
  The OpenCode wrapper sets that marker, so a passphrase request reaching
  from OpenCode can never draw curses over the TUI. Run `gpg-unlock` from a
  normal terminal instead.
- The cache lives in gpg-agent: entries expire after `default-cache-ttl`
  (400 days on this setup) or when the agent restarts, so re-running
  `gpg-unlock` after a reboot or agent restart is the regular recovery step.
