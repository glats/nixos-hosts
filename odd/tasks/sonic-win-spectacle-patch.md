# sonic-win Spectacle authorization patch
Objective: let Spectacle capture on thinkcentre SonicDE by completing sonic-flake's truncated NixOS unwrap patch for sonic-win.
Branch: fix/sonic-win-unwrap. Delivery: single-pr (small). Runner: Nix evaluation test (tests/rog-sonicde.nix); build and runtime proof user-authorized separately.

## Specs
S1. "podemos hacer un odd para el parche de spectacle ?" Spectacle must no longer fail with "KWin screenshot request failed: The process is not authorized to take a screenshot" (Method: CaptureScreen, "rdp0") on thinkcentre.
S2. Patch only sonic-win, only for thinkcentre's SonicDE module; rog/t14 unaffected; no permission-check bypass (no KWIN_SCREENSHOT_NO_PERMISSION_CHECKS). Assumption: keeping Flameshot on Print is unchanged by this feature.
S3. Checks: RED/GREEN eval predicate that the module's kwin_x11 wrapper and package use the patched sonic-win; thinkcentre system evaluates; build forecast before compiling KWin; runtime proof `spectacle -b -n -f -o <file>` produces a file after deployment.

## Tasks
- T1 [S1-S3] inline, implemented, commit f606bccc: serviceutils.h patch, sonic-win override via `_module.args.sonic-de`, regression predicate. RED then GREEN (12/12), patch applies after sonic 0001, flake check passes, independent verifier: no blockers. KWin build and runtime Spectacle proof pending (user-owned). Risk items 2 and 5.

## Log
L1. User: "podemos hacer un odd para el parche de spectacle ?"
L2. Root cause: KWin ScreenShot2 authorizes by matching /proc/<pid>/exe against .desktop Exec; Spectacle runs as `.spectacle-wrapped`. sonic-flake d779fe69 sonic-win/default.nix applies `0001-NixOS-Unwrap-executable-name-for-.desktop-search.patch` "modified to remove all wayland references", but it only adds src/nixos_utils.h and drops the src/utils/serviceutils.h hunk, so unwrapExecutablePath is never called. nixpkgs kwin 6.6.6 applies the full hunk. RED reproduced: `spectacle -b -n -f` exit 0 without file; journal shows the authorization error.
L3. Mechanism: sonic-de.nix resolves packages from `_module.args.sonic-de`; overriding `packages.<system>.sonic-win` there rebuilds only KWin. Dependents (sonic-workspace) keep build-time references to the unpatched sonic-win, but the running kwin comes from the module's package list, plasma-kwin_x11.service (absolute ExecStart in the sonic-win package) and the kwin_x11 security wrapper, all from the overridden attribute. Screenshot authorization lives in sonic-win's own screenshot plugin.
L4. RED: thinkcentreKwinUnwrapPatch failed; GREEN after override, all 12 predicates true. `patch -p1 --dry-run` applies after sonic 0001. `nix flake check --no-build` passes. Dry run: 26 derivations, only compile is sonic-win-6.6.5 (KWin); rest are wrappers/generations. Commit attempt failed: GPG signing needs a passphrase; signing not bypassed, changes staged on fix/sonic-win-unwrap.
L5. Independent verifier: S1-S2 met at eval level, S3 met for predicate; no blockers. Screenshot authorization is linked into .kwin_x11-wrapped. Advisory: unpatched sonic-win remains in sonic-workspace wrapper env paths. Parent check: plasma-kwin_x11.service resolves from /run/current-system/sw/share/systemd/user, which after switch comes from the only (patched) sonic-win in systemPackages. Post-deploy proof: `readlink /proc/$(pgrep -f kwin_x11 | head -1)/exe` is the patched store path and `spectacle -b -n -f -o /tmp/opencode/s.png` writes a file.
L6. Work-unit commit f606bccc on fix/sonic-win-unwrap (user authorized). Pending: KWin build, switch, runtime Spectacle proof.
