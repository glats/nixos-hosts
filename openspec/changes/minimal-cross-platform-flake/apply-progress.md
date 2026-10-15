# Apply Progress: Minimal Cross-Platform Flake

## Status

20 of 21 tasks are complete. Task 7.6 remains intentionally pending because the user explicitly prohibited committing unless they later ask for it.

## Completed Tasks

1.1–1.2, 2.1, 3.1–3.4, 4.1–4.2, 5.1–5.4, 6.1–6.2, and 7.1–7.5.

## Work Unit Evidence

| Work unit | Focused test command and result | Runtime harness and result | Rollback boundary |
| --- | --- | --- | --- |
| Repository, flake, hosts, and shared module | `nix flake check --no-build` exited 0; no derivations built | Linux and Darwin toplevel selector evaluations both returned drvPaths; shared module evaluates to one package for x86_64-linux and aarch64-darwin | Delete `/home/glats/minimal-nix` |
| Installation documentation | Policy guard searches found no forbidden framework, secret-management, or truecolor configuration; three user-run Codex login commands found | N/A: the documents are manual first-install runbooks, not an executable runtime boundary | Delete `POST_INSTALL.md` and `PARTITIONING.md` |

## Verification Notes

- `nix eval` returned a Linux toplevel drvPath and a Darwin toplevel drvPath on the Linux runner; no Darwin environmental blocker occurred.
- The integrated Home Manager `home.packages` values contain Home Manager support packages in addition to Codex (nine entries on Linux, four on Darwin). The shared module itself evaluates to exactly one package on each platform, `pkgs.codex`; this is the applicable invariant.
- The Linux configuration uses a `lib.mkDefault` ext4 root declaration only to pass evaluation before the install-time generated hardware module exists. The conditional import receives the generated hardware configuration after partitioning, whose normal-priority filesystem entries override this default.
- The Linux password hash remains a redacted placeholder. Before installation, the user must replace it with fresh `mkpasswd -m sha-512` output; no password or cleartext was created or copied.

## Remaining Task

- [ ] 7.6 Create the initial commit — deferred by explicit user instruction.
