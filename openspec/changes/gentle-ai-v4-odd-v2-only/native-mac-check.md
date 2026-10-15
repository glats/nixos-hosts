# Native Mac evaluations and full build pass; no activation

The unchanged reviewed source now passes all three native Mac evaluations, the explicit Gentle binary/assets aggregate build, and the full Darwin system plus standalone Home Manager aggregate build through strict `juan@macm5.local` SSH. Nothing was activated. The initial renderer discovery failure remains unexplained historical evidence, followed by an unchanged renderer reprobe and this explicitly authorized acceptance rerun. Task 3.3 remains unchecked because full native Linux build criteria are not established. The relay failure and first native failure sections below are historical, not current gate results.

## Authorized native acceptance continuation — 2026-10-09

After #3952 proved the original unchanged renderer builds successfully with its actual three-second discovery check, the parent explicitly authorized one acceptance rerun. No product fix, CLI/SDK change, fabricated version, longer discovery timeout or prewarming step was introduced. Current baseline/all 31 owned entry hashes were verified locally before these commands; all 31 remote owned entry hashes, including three deletions, were verified again afterward. Source identity remains the reviewed fingerprint and archive below, at `/Users/juan/.cache/gentle-ai-v4-candidate.handoff-y0e7kmsg/source`.

| Native gate | Result / exact path |
|---|---|
| System drvPath | PASS: `/nix/store/7vds991736mhc0pdhxglv43r99xmrwb4-darwin-system-26.05.c3e90c8.drv` |
| Integrated juan HM drvPath | PASS: `/nix/store/0b0v1jy2vns1chvs5dydmsasjbih8fn0-home-manager-generation.drv` |
| Standalone macm5 HM drvPath | PASS: `/nix/store/lazw7dp973fisszpdzzpa0rdczah7hg2-home-manager-generation.drv` |
| Explicit native binary/assets aggregate | PASS: `/nix/store/67fvc0dr6y82skcwh9x8jib5wpyrb7hx-gentle-ai-4.0.0` and `/nix/store/0gzd3gg0fp9znbf38mvishyx2kycdd0r-gentle-ai-assets-4.0.0` |
| Full native system/standalone HM aggregate | PASS: `/nix/store/xg31yhyqfr02g5hdm220jlpf278rg237-darwin-system-26.05.c3e90c8` and `/nix/store/0dmwfnpgs2d9d9h4vxm6waii3irg8l90-home-manager-generation` |
| Integrated juan HM output, built as full-system dependency | `/nix/store/fk60sn8mxfvc8dcrk44i14yh1s5ad2a1-home-manager-generation` |

Each command returned exit 0. The smaller gates had individual 360-second watchdogs; the full build had a 1,500-second watchdog targeting only its own Nix client PID. All completed before their bounds; the timers were canceled. The full build scheduled 47 derivations, including the integrated HM generation. Standard public dependency fetching was permitted; these acceptance commands did not request offline mode and preserved the lock file. Actual commands from the private source directory:

```sh
NIX=/nix/var/nix/profiles/default/bin/nix
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.drvPath
"$NIX" eval --no-write-lock-file --raw path:.#homeConfigurations.macm5.activationPackage.drvPath
"$NIX" build --no-write-lock-file --no-link --print-out-paths path:.#gentle-ai path:.#gentle-ai-assets
"$NIX" build --no-write-lock-file --no-link --print-out-paths path:.#darwinConfigurations.macm5.config.system.build.toplevel path:.#homeConfigurations.macm5.activationPackage
```

Public logs alongside the local handoff bundle are `native-resume-gates.log`, `native-full-build.log`, and `native-final-source-check.log`. Engram #3957/#3958 record the successful native subgates. This is evaluation/build evidence, not organic CLI compatibility certification, deployment, model/MCP behavior or actual rollback. Activation scripts, launchd plists and relay definitions were only built as outputs, not executed or installed; no Mac services/policy changed. STOP #3934 remains effective, and no credential access/copy/login, model/provider/MCP call, existing checkout modification, Git index/ref mutation or publication occurred.

## Renderer investigation — 2026-10-09

Engram #3952 records this investigation. Public derivation metadata confirmed
the private PATH selects the actual pinned native executable:
`/nix/store/v65b8wibznsqq9qshdrilq3gc0wjdm7d-opencode-v2-2.0.14/bin/.opencode2-unwrapped`.
`file` reports Mach-O arm64; `otool -L` reports system libicucore, libresolv,
libc++ and libSystem dependencies, not a missing external Bun interpreter.
The upstream runtime probe uses `--version` with a three-second context; its
failure discards detailed command output before the renderer assertion at
`pkgs/gentle-ai-assets/render_test.go:60` reports the generic unavailable error.

One isolated HOME/XDG/DB version-only probe outside the build sandbox, bounded
to 12 seconds, returned exit 0 in **0.419 seconds**, stdout
`opencode v2.0.14`, empty stderr. This was not a server/model/auth invocation.
A temporary derivation override added a bounded native `--version` diagnostic
before the unchanged Go exporter tests, without modifying remote source or
upstream admission. Its build log records exit 0 and `opencode v2.0.14`;
`TestExportManagedPrompts` then passed in **0.11 seconds**. The diagnostic
derivation is `m3p7508a98wcngaqvb1mlkk6i4v13yxd`; it is not a shipping fix or
proof that prewarming is required.

One explicit reprobe built the original unchanged derivation:

```sh
/nix/var/nix/profiles/default/bin/nix build --no-link -L \
  /nix/store/96y0z559qvj02w1ba9v4jq7x1xqsfim9-gentle-ai-rendered-prompts-4.0.0.drv^out
```

Both tests passed: missing-executable refusal in 0.00 seconds and export with
actual three-second runtime admission in **0.33 seconds**. The output is
`/nix/store/dd9x7ff96yy62pl47lidk5lxlmh8s1ni-gentle-ai-rendered-prompts-4.0.0`.
Local `native-version-diagnostic.log`, `native-renderer-reprobe.log`, and
`renderer-derivation.json` preserve public evidence alongside the handoff bundle.

The initial timeout is now nonreproducing. First-execution/OS caching or cold
startup is a hypothesis, not an established root cause: no initial stderr or
OS trace identifies that mechanism. No product code was edited, no timeout
increased, no fake version/admission bypass introduced, and no production
prewarm/cache added. Therefore no new source fingerprint/transfer or Linux
regression run is claimed. The reviewed source identity below stays unchanged.
At that investigation checkpoint, system/integrated/standalone evaluations and
binary/assets aggregate builds remained pending; renderer-only success did not
satisfy them. The subsequent separately authorized acceptance results are above.
No credentials, providers, MCP, activation, services, Git index/refs or existing
checkout were accessed or modified by these version/build diagnostics.

## Historical first direct Mac execution — superseded by acceptance results above

The user explicitly requested `ssh macm5.local` after the relay failure. Existing public SSH configuration resolves `juan@macm5.local` to `clftclgv2fhww0w.local`, port 22. The direct connection used BatchMode, ConnectTimeout 10, StrictHostKeyChecking yes and the existing known-host files; no new key acceptance, known-host/key edits or relay changes were made.

Read-only preflight observed `Darwin`, `arm64`, user `juan` and `/nix/var/nix/profiles/default/bin/nix`. Before transfer, actual HEAD and all 31 owned entry hashes were checked again and still matched the reviewed source identity. A local logging wrapper hit zsh's read-only `status` variable after successful preflight; this was not an SSH failure and no connection retry was needed.

The archive was transferred through SSH stdin into a newly created mode-0700 directory outside the habitual checkout. Remote archive checksum passed before extraction, the relative-member allowlist passed, and the extracted manifest checksum passed. No existing candidate directory was overwritten. The source-on-Mac prerequisite is now fulfilled at:

```text
/Users/juan/.cache/gentle-ai-v4-candidate.handoff-y0e7kmsg/source
```

| Native gate | Actual result |
|---|---|
| Direct connection / Darwin arm64 / juan / Nix presence | PASS |
| Source archive and manifest checksum | PASS, matching identity below |
| macm5 system drvPath evaluation | FAIL, exit 1: renderer IFD build failure |
| Integrated juan activation drvPath evaluation | NOT RUN after first candidate error |
| Standalone macm5 activation drvPath evaluation | NOT RUN after first candidate error |
| Explicit native Gentle binary/assets build | NOT RUN; no aggregate PASS inferred from intermediate builds |
| Full native system/HM build | NOT RUN |

Executed native command:

```sh
cd /Users/juan/.cache/gentle-ai-v4-candidate.handoff-y0e7kmsg/source
/nix/var/nix/profiles/default/bin/nix eval --offline --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath
```

The evaluation attempted native dependency builds, then the renderer failed:

```text
Derivation: /nix/store/96y0z559qvj02w1ba9v4jq7x1xqsfim9-gentle-ai-rendered-prompts-4.0.0.drv
=== RUN   TestNativeV2DiscoveryRefusesMissingExecutable
--- PASS: TestNativeV2DiscoveryRefusesMissingExecutable (0.00s)
=== RUN   TestExportManagedPrompts
    render_test.go:60: truthful native OpenCode V2 discovery required: major=0 error=OpenCode runtime version unavailable or unsupported; managed runtime assets were not selected
--- FAIL: TestExportManagedPrompts (3.00s)
FAIL github.com/gentleman-programming/gentle-ai/v4/internal/nixexport 3.541s
```

The dependent assets derivation `/nix/store/z61kwablf8d6a304dbwpazkmmw6j3x4l-gentle-ai-assets-4.0.0.drv` was blocked; no final system drvPath was returned. Read-only `nix log` of the renderer confirmed the full result: one exporter test PASS, one FAIL. This is not a missing-cache-only result, so no online retry was attempted.

The responsible source boundary is `pkgs/gentle-ai-assets/render_test.go:37–60` (`DetectRuntimeMajor` and its truthful V2 assertion), with `pkgs/gentle-ai-assets/render.nix:27–37` supplying the private native runtime symlink/PATH and isolated HOME/XDG. The reason native discovery returned unavailable/unsupported is not established by this log; no CLI incompatibility, authentication problem or version-bump requirement is inferred. No ad-hoc Mac snapshot fix was made. Return this exact evidence to the parent for a responsible source investigation/fix and re-review before replacing the reviewed fingerprint or rerunning gates.

Local logs alongside the bundle: `ssh-direct-preflight.log`, `ssh-direct-transfer.log`, `native-system-eval-offline.log`, and `native-renderer-build.log`. Engram #3946 records verified transfer; #3949 records native failure. No activation, model request, credential copy/login, service/policy mutation, index/ref change or publication occurred.

## Source identity and exclusions

| Item | Observed value |
|---|---|
| Actual committed master baseline | `4750736cd68f517a871ac7448639c94546472390` |
| Reviewed owned fingerprint | `3229f4238f8a9071e4790e8db6f781c60f80aff29e86f2083f9f471d8f783ed3` |
| Owned paths | All 31 entry hashes match `final-v4-fingerprint.json`; three deleted files remain absent |
| Candidate source files | 845 regular files, baseline archive plus only reviewed owned overlays/deletions |
| Source manifest SHA-256 | `01d05cd0c5934aa123ab56a5ee4a82d519710544a18b8b4fdbf0b288379f41bb` |
| Archive SHA-256 | `aac45d91867b3f53ee22ee01e3521c7a671826e7d4c26a32761b69bdf30a9b34` |
| Prior ownership bootstrap | Preserved `github:glats/nixos-hosts/4750736cd68f517a871ac7448639c94546472390` source pointer and complete candidate lock |

Local private handoff directory:

```text
/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-mac-candidate/handoff-y0e7kmsg
```

It contains `gentle-ai-v4-candidate.tar.gz`, its checksum file, `source-manifest.json`, `handoff-identity.json`, the extracted `source/`, and `ssh-preflight.log`. The temporary packaging fixture lives outside the repository at `/home/glats/.local/opencode-v2/tmp/opencode/package-gentle-mac.py`; it is not a shipped operational CLI.

Packaging used `git archive` of actual HEAD, not a dirty checkout copy, then exactly the 31 reviewed owned paths. All new candidate files are included and obsolete files removed. Foreign dirty tracked changes and unrelated untracked OpenSpec work are excluded. The bundle does not include this subsequently authored tracking report. It contains no `.git`, runtime databases, auth files, home directory copy, private keys or `.env` files. Tracked SOPS ciphertext required by the baseline flake was copied as opaque bytes; it was not decrypted, displayed or interpreted. Filename/mode checks rejected unsafe paths, symlinks, nonregular files, private-key/database filenames and special permission bits. Tar members are deterministic relative regular files under `source/`, plus `source-manifest.json`, with normalized uid/gid 0 and modes 0644/0755.

## Historical relay probe — superseded by direct access above

Existing `shared/ssh/lan-mesh.nix` declares `macm5-relay` for rog with `juan`, hostname `127.0.0.1`, port `22220` and host-key alias `macm5`. Sanitized `ssh -G` confirms these public settings and the existing known-host files. No private key bytes were inspected. The command was:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes \
  -o 'UserKnownHostsFile=/home/glats/.ssh/known_hosts /home/glats/.ssh/known_hosts2' \
  macm5-relay 'uname -s; uname -m; command -v nix; id -un'
```

Actual result:

```text
ssh: connect to host 127.0.0.1 port 22220: Connection refused
SSH_EXIT=255
```

There were no alternate connection attempts, relay-policy changes, wake/restart/sudo operations, new host-key acceptance, remote directory creation or transfer. The relay is unavailable; the native OS/architecture/Nix/user remain unobserved. This does not establish that direct LAN access is unavailable.

## Initial manual-transfer instructions — source now present; do not repeat transfer

The following instructions were supplied before direct access succeeded and are retained as reproducibility guidance, not commands to rerun against the failed snapshot. The source is now at the exact remote path above. After a responsible source fix and fresh reviewed handoff, use its new identity, not this archive as if the failure had been fixed. The archive basename is **`gentle-ai-v4-candidate.tar.gz`**. The original optional Mac-side retrieval was:

```sh
scp -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes \
  rog:/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-mac-candidate/handoff-y0e7kmsg/gentle-ai-v4-candidate.tar.gz \
  "$HOME/Downloads/gentle-ai-v4-candidate.tar.gz"
```

Do not replace an existing download of that name without checking it first. No transfer command above was run by this worker. Once the archive is present, run these commands on native macOS as `juan`; use a fresh private directory outside the existing checkout:

```sh
test "$(uname -s)" = Darwin && test "$(uname -m)" = arm64 && test "$(id -un)" = juan
cd "$HOME/Downloads"
printf '%s\n' 'aac45d91867b3f53ee22ee01e3521c7a671826e7d4c26a32761b69bdf30a9b34  gentle-ai-v4-candidate.tar.gz' | shasum -a 256 -c -
# Continue only if the checksum and native identity checks pass.
umask 077
mkdir -p "$HOME/.cache"
candidate=$(mktemp -d "$HOME/.cache/gentle-ai-v4-candidate.XXXXXX")
chmod 700 "$candidate"
tar -xzf "$HOME/Downloads/gentle-ai-v4-candidate.tar.gz" -C "$candidate"
cd "$candidate"
printf '%s\n' '01d05cd0c5934aa123ab56a5ee4a82d519710544a18b8b4fdbf0b288379f41bb  source-manifest.json' | shasum -a 256 -c -
cd source
printf 'Candidate source: %s\n' "$PWD"
NIX=$(command -v nix)
if test -z "$NIX"; then NIX=/nix/var/nix/profiles/default/bin/nix; fi
test -x "$NIX"
# If Nix is absent, stop; do not install it or alter ~/.config/nix.
```

Run checks one at a time, stopping on the first genuine candidate error. These are build/evaluation commands only; they do not activate the outputs:

```sh
"$NIX" eval --offline --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath
"$NIX" eval --offline --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.drvPath
"$NIX" eval --offline --no-write-lock-file --raw path:.#homeConfigurations.macm5.activationPackage.drvPath
"$NIX" build --offline --no-write-lock-file --no-link --print-out-paths path:.#gentle-ai path:.#gentle-ai-assets
# After the smaller native gates pass, the optional heavier build gate is:
"$NIX" build --offline --no-write-lock-file --no-link --print-out-paths path:.#darwinConfigurations.macm5.config.system.build.toplevel path:.#homeConfigurations.macm5.activationPackage
```

An unavailable cached input/dependency is **UNAVAILABLE**, not candidate FAIL. For that specific condition only, rerun the affected command once with `--offline` removed, retaining `--no-write-lock-file` and build `--no-link`; ordinary public dependency fetching/building is in scope. Do not change pins, use alternate models or fix product code within this source snapshot. Note that Nix `--offline` disables substituters but is not a network sandbox for fixed-output builds. Record command exit status, output paths and errors with this source identity before claiming any subgate PASS. A native Darwin error should be returned to the parent for a responsible source fix and re-review.

## Remaining boundary

Stop #3934 remains effective: no models, login, auth/runtime copying, activation, commits, push, index changes, feature toggles or relay-policy edits. There is no new permission interview or credential workaround. Native proof can close only platform evaluation/build subgates; missing full Linux builds and all organic/fleet/activation/rollback criteria keep task 3.3 and other acceptance gates partial. Returning to the existing checkout is the source-handoff rollback; no installed generation or runtime state was changed. The private source directory/archive may be retained as evidence.
