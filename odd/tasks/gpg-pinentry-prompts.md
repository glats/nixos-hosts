# gpg-pinentry-prompts

Objective: GPG/SSH passphrase prompts never corrupt the OpenCode TUI; prompts are graphical when a desktop exists, on every host (rog, thinkcentre, t14, macm5).
Branch: `fix/gpg-pinentry` (worktree `/home/glats/.nixos-worktrees/gpg-pinentry`, based on `master`). Delivery: ask-on-risk. Test runner: `go -C pkgs/nixos-scripts test ./...` plus Nix evaluation.

## Specs

- S1. The original symptom must disappear: "aveces me aparece un ncurses que me pide abrir el gpg y se abre en el tui de openode y se estropea". It must hold on any host, including a newly configured one: "arregla por mi y que nunca mas pase para un hosts que no lo tenga configuado".
- S2. SSH must never prompt. The user does not know the passphrases: "djemos configurado para que no se vuelvan a pedir esos datos. la contraseña para gpg y sshh no se". The SSH keys in `~/.ssh` have no passphrase. gpg-agent held no SSH identities, and prezto's `ssh` module ran `ssh-add` in every pane, which made gpg-agent open pinentry. Fix: remove prezto `ssh` from `linux/home/shell.nix` pmodules and set `programs.gnupg.agent.enableSSHSupport = false` in `linux/system/base/users.nix`. That also drops the `updatestartuptty` `Match host * exec` from the ssh config.
- S3. The user can enter the GPG passphrase once with a command, and then it stops asking: "dejame poner la contraseña con algun comando para que no reclame mas". gpg-agent caches for `default-cache-ttl 34560000` and `max-cache-ttl 34560000` on Linux and on macm5. The command is an operational Go tool in `pkgs/nixos-scripts/`, per the repository rules (no shell scripts). It must cache the passphrase of each git signing key.
- S4. The prompt is graphical: "en vez de que sea curses sea algo visual como unanventa del desktop que estoy usando nose. entiendes? pero hagamos algo para todos los hosts de nixos incluso para macm5". Linux uses `pkgs.pinentry-qt`, which works on X11/XRDP (MATE) and Wayland (Hyprland). macm5 keeps `pinentry-mac`.
- S5. No-display terminals: "no se si habra una vairable de entorno que cubra todos los casos. siempre y cuando este en una temrinal o temrinal emular. pero si es kmscon, creo que sera un problema." Without DISPLAY/WAYLAND_DISPLAY (kmscon, a plain VT, SSH), pinentry falls back to a text prompt in that terminal. Inside OpenCode, pinentry must never draw curses on OpenCode's TTY. Assumption: the OpenCode wrapper in `shared/opencode.nix` neutralizes `GPG_TTY` (for example `--set GPG_TTY /dev/null`). The graphical prompt still works when a display exists. With no display, the signing operation fails cleanly and the user runs the S3 command in a normal terminal. This behavior must be proven with a throwaway GNUPGHOME before relying on it.
- S6. Process: "ojo que no quiero que sigas haciendo cosas inline. vamos con un odd". The work is delegated.

## Tasks

- T1 [S1,S2] route: delegated (user instruction S6). Commit the already-applied SSH-prompt removal. Status: done (fix(gpg): stop ssh-add from triggering pinentry).
- T2 [S1,S4,S5] route: delegated. pinentry-qt on Linux (already applied in the worktree, uncommitted), the OpenCode `GPG_TTY` neutralization, and a curses fallback proof. Status: pending.
- T3 [S3] route: delegated. Cache TTL (already applied in the worktree, uncommitted) plus the Go unlock command, its tests, and docs. Status: pending.
- T4 [S1-S5] route: delegated independent verifier (high risk: items 2 and 5). Status: pending.

## Log

- L1 (2026-10-16) "aveces me aparece un ncurses que me pide abrir el gpg y se abre en el tui de openode y se estropea"
- L2 (2026-10-16) "arregla por mi y que nunca mas pase para un hosts que no lo tenga configuado"
- L3 (2026-10-16) "djemos configurado para que no se vuelvan a pedir esos datos. la contraseña para gpg y sshh no se"
- L4 (2026-10-16) "dejame poner la contraseña con algun comando para que no reclame mas"
- L5 (2026-10-16) "oye o que por ultimo en vez de que sea curses sea algo visual como unanventa del desktop que estoy usando nose. entiendes? pero hagamos algo para todos los hosts de nixos incluso para macm5. entiendes?"
- L6 (2026-10-16) "no se si habra una vairable de entorno que cubra todos los casos. siempre y cuando este en una temrinal o temrinal emular. pero si es kmscon, creo que sera un problema. ojo que no quiero que sigas haciendo cosas inline. vamos con un odd"
- L7 Evidence: `~/.gnupg/sshcontrol` has only comments, and `ssh-add -l` returns "The agent has no identities". The SSH keys id_ed25519, id_ed25519_lan, and rog have no passphrase. The git signing keys (personal `CFD6C7FE…D39580F75062BEFC`, work `…A1D4ECB0118566C8`) need a passphrase. Recent commits are signed (`%G?` = U).
- L8 Evidence: the edits were moved out of the shared `~/.nixos` checkout, which holds another session's work (`fix/sonic-win-unwrap`), into this worktree. Before the move, rog and t14 toplevel evaluated OK. thinkcentre failed only because of the other session's untracked `linux/home/suites/sonicde`, and it evaluates OK without that edit. macm5 evaluation fails on the Linux host with "Cannot build ...cli-darwin-arm64-2.0.14.tgz.drv" (environmental, pre-existing).
- L9 Next: one delegated writer runs T1 to T3 sequentially, then an independent verifier runs T4.
- L10 (2026-10-16) T1 evidence: `linux/home/zsh.nix` pmodule list no longer contains `ssh`, and `linux/system/base/users.nix` sets `programs.gnupg.agent.enableSSHSupport = false`. The `updatestartuptty Match host * exec` line named in S2 does not exist anywhere in the repository, so no removal was needed; it only lived in the user's mutable `~/.ssh/config`, outside repo scope.
