# Apply Progress: Parallel Isolated OpenCode V2 Runtime

**Delivery**: stacked-to-main, slice 4 (no branch, commit, push, or PR created)
**Mode**: Standard (`strict_tdd: false`)
**Status**: The supervised V2 lifecycle is declared and evaluation-tested. Phase 4.2 and 4.3 remain open for native macm5 toplevel evaluation and deployed host smoke evidence.

## Completed Task Artifacts

- [x] 1.1–1.2 and 2.1–2.6: prior package/delivery slice completed V2 package delivery, stale launcher removal, V1 1.18.32 pin repair, and one-way `--v2` auth seed.
- [x] 1.3: evaluated generated V2 wrapper environment for all XDG roots, OpenCode config/DB/TMP paths, V2 binary execution, argument forwarding, and absence of `--standalone`.
- [x] 1.4: evaluated the activation hook for cmp-guarded changed-only restart, shared V2 environment, visible nonzero failure, and post-success stamping.
- [x] 1.5: evaluated default project-config disablement and the V1 SDK marker refusal before the V2-compatible wrapper execs.
- [x] 3.1: parameterized the runtime generator with V1/V2 records; V2 emits only `{"update":"disable"}` and does not create the V1 plugin, TUI, commands, skills, or npm tree.
- [x] 3.2: compared the generated Rog V1 `opencode.json` source against the HEAD baseline; it is byte-identical.
- [x] 3.3: centralized all V2 XDG, config, database, temporary, and default project-config-disable exports in `mkV2Environment`.
- [x] 3.4: added `opencode2` and `opencode2-project` zsh wrappers and `home.opencode.v2` enable/runtimeRoot/projectConfigCommand options.
- [x] 3.5: added a V2 activation restart hook that runs the native `opencode2 service restart` only when its generated config differs from the V2 stamp.
- [x] 4.1: Go suite passed, ten changed Nix files were formatter-idempotent, and `nix flake check --no-build` passed.
- [x] 5.1: static cleanup audit found no V2 `--standalone` or V2 managed daemon; the unrelated V1 `opencode-go-proxy` systemd user service remains intentionally. V1 branches remain intentionally to preserve the required fallback.
- [x] 5.2: documented that native GA V2 replaces the Phase 2 Docker launcher while V1 remains the default command.
- [x] 1.6: added declarative assertions for Linux systemd and Darwin launchd supervision, one rendered environment source, and activation's supervisor-only restart.
- [x] 3.6: replaced the internal V2 environment option with one attribute set rendered to a shell environment file and systemd/launchd service environments.
- [x] 3.7: declared the Linux `opencode2` systemd user service with `opencode2 serve`, `Restart=on-failure`, and `default.target` enablement.
- [x] 3.8: declared the macm5 `opencode2` launchd agent with the foreground `serve` command, V2 environment, `RunAtLoad`, and crash-only keep-alive.
- [x] 3.9: changed the cmp-guarded activation hook to restart the applicable supervisor and copy its stamp only after that command succeeds.
- [x] 3.10: ran the no-build flake gate and evaluated the rendered Linux unit, Darwin agent, and Linux activation command.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused Go test | `go -C pkgs/nixos-scripts test ./...` exited 0; the `install-opencode-auth-seed` package passed. |
| Nix formatting | `nix fmt --` over all ten changed Nix files and the new wrapper comment exited 0; each run reported `0 changed`. |
| Flake evaluation | `nix flake check --no-build` exited 0. It evaluated the Linux packages including `opencode-v2` and reported that aarch64-darwin is omitted on this x86_64-linux executor. |
| Linux host evaluation | `nix eval --raw .#nixosConfigurations.{rog,thinkcentre,t14}.config.system.build.toplevel.drvPath` passed (t14 was re-run independently after a timeout caused by concurrent eval-cache contention). Standalone Home Manager drvPath evaluations for `rog`, `thinkcentre`, and `t14` also passed. |
| Linux package smoke | `nix build --no-link --print-out-paths .#opencode` and `.#opencode-v2` passed. The built binaries reported `1.18.32` and `opencode v2.0.14`; V2 `service --help` exposed the native `start`, `restart`, `status`, and `stop` lifecycle commands. |
| Same-folder V1/V2 smoke | Not executed. The isolated temporary-home harness was stopped before execution by Warden because it wrote to a dynamic shell target. Its command was not retried. Therefore there is no claimed fresh-launch, shared-server, no-V1-write, seed, or simultaneous same-folder runtime evidence. |
| macm5 evaluation | Attempted both Darwin toplevel and standalone Home Manager drvPath evaluations. Both are blocked on this executor: evaluating `gentle-ai-assets` requires `aarch64-darwin`, while the current system is `x86_64-linux`. |
| macm5 reproduction | On macm5, run `nix eval --raw /Users/juan/.config/nix#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` and `nix eval --raw /Users/juan/.config/nix#homeConfigurations.macm5.activationPackage.drvPath`, then run the same-folder smoke matrix after activation. |
| Rollback boundary | Revert the documentation comment in `shared/shell-aliases.nix` and this task/progress evidence only; no runtime behavior changed in this slice. |

## Work Unit 4 Evidence

| Evidence | Result |
|---|---|
| RED → GREEN assertions | Before production, `nix eval --json .#homeConfigurations.rog.config.systemd.user.services.opencode2` failed because no service existed. The module now carries Linux/Darwin assertions for foreground service definitions, shared environment, recovery policy, and the supervisor-only activation path. |
| Focused test | `nix fmt -- shared/opencode.nix shared/shell-aliases.nix && nix flake check --no-build` exited 0. The flake gate evaluated all three Linux NixOS configurations; Darwin systems are omitted on this `x86_64-linux` executor. |
| Rendered configuration | `nix eval --impure --json --expr 'let f = builtins.getFlake "path:/home/glats/.nixos"; in { linux = f.homeConfigurations.rog.config.systemd.user.services.opencode2; darwin = f.homeConfigurations.macm5.config.launchd.agents.opencode2; }'` exited 0. Linux renders `opencode2 serve`, all eight V2 variables, `Restart=on-failure`, and `WantedBy=default.target`; Darwin renders the same binary/environment with `RunAtLoad` and crash-only `KeepAlive`. |
| Activation rendering | `nix eval --impure --raw --expr 'let f = builtins.getFlake "path:/home/glats/.nixos"; in f.homeConfigurations.rog.config.home.activation.restartOpencodeV2.data'` exited 0 and rendered cmp-guarded `systemctl --user restart opencode2`, a failure exit before the stamp copy, and no native `service restart`. The Darwin branch evaluates `launchctl kickstart -k gui/$(id -u)/org.nix-community.home.opencode2`. |
| Runtime harness | N/A: this executor has no deployed target user session, and starting/restarting either supervisor would mutate a host. Deployed discovery and crash recovery remain Phase 4.3 evidence. |
| Rollback boundary | Revert `shared/opencode.nix` and `shared/shell-aliases.nix`; this removes only V2 environment rendering, user supervisors, activation restart behavior, and their assertions. V1 remains untouched. |

## Remaining Tasks

- [ ] 4.2: complete native `darwinConfigurations.macm5` toplevel evaluation on macm5.
- [ ] 4.3: complete deployed per-host V1/V2 same-folder smoke evidence on rog, thinkcentre, t14, and macm5.

**Review boundary**: stacked-to-main slice 4 contains only V2 user-supervisor declarations, shared environment rendering, activation restart logic, wrapper sourcing, and declarative assertions.
