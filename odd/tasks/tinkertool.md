# tinkertool

Objective: package TinkerTool for macm5 the Nix way, like FinderSearch (38f40ea), fully automatic with no manual download.
Branch: `master` (repository convention: direct work-unit commits on master). Delivery strategy: `single-pr` waived, no push. Test runner: `nix build` of the package, `nix eval` of `darwinConfigurations.macm5`.

## Specs

S1. "quiero empqueter nnix way la herramienta tinknertool muy similar quizas a finder search como nse hizo en un comit." — `pkgs/tinkertool/default.nix` installs `TinkerTool.app` under `$out/Applications`, wired into macm5 `systemPackages` next to FinderSearch.
S2. "puedes hacer un explore para encontrar la mejor forma de hacerlo automatico?" / "bien. juzga tu y aplica la solcuion por mi. full odd ok?" — the DMG is fetched automatically by a fixed-output derivation that replays the upstream download form (GET download.php, POST its form with key1-key3, GET download3.php), pinned to the official SHA-256 `5e3d30d2daabc5462f4015d9921a2b6e93bec393e8803a15f19f69b6c989656c` (v11.71). No `requireFile`.
S3. The DMG is nested (Apple partition map, then HFS image); unpacking extracts twice so `TinkerTool.app` is found.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1-S3 | parent inline (one package file; no writer trigger) | done | RED/GREEN in L6; commit in git log (feat(macm5): fetch TinkerTool automatically) |

## Log

L1 (2026-10-16, user, verbatim): "quiero empqueter nnix way la herramienta tinknertool muy similar quizas a finder search como nse hizo en un comit."
L2 (2026-10-16, user, verbatim): "si hay homberew entonces la agregamos a homberew!" — no Homebrew cask exists (`brew search tinkertool` returns only `tinkerwell`).
L3 (2026-10-16, user choice): "Nix con requireFile (Recomendado)" — interim requireFile package created, eval passed.
L4 (2026-10-16, user, verbatim): "puedes hacer un explore para encontrar la mejor forma de hacerlo automatico?" — evidence: the three-step form flow downloads `TinkerTool.dmg` whose SHA-256 matches the published checksum; form action host varies (`bresink.eu`/`bresink.biz`); single `7zz x` yields only partitions, a second `7zz x -sns-` on `2.disk image` yields `TinkerTool 11.71/TinkerTool.app`.
L5 (2026-10-16, user, verbatim): "bien. juzga tu y aplica la solcuion por mi. full odd ok?"
L6 (2026-10-16, checks): RED — `nix build` of the requireFile package fails asking for `nix-store --add-fixed`. GREEN — fixed-output fetch plus two-stage unpack builds `/nix/store/2j3d66sc…-tinkertool-11.71`; `CFBundleShortVersionString` 11.71; `codesign --verify --deep --strict` OK; `spctl` accepted, "Notarized Developer ID"; macm5 toplevel `nix eval` passes; `nix fmt` no changes. Pending: activation via `nixos-build` on macm5 (user). Risk: none (new macm5-only package; fetch fails closed on hash or form change).
