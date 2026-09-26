# Apply Progress: Port OpenCode V2 Provider Allowlist

## Status

Partial: 20 of 22 tasks are complete. The only remaining tasks are the cross-platform evaluation aggregate and the mandatory rog runtime deny smoke.

## Completed Tasks

- [x] 1.1-1.4 RED baseline assertions
- [x] 2.1-2.5 GROQ re-home and export removal
- [x] 3.1-3.4 central allowlist, V1 deny derivation, V2 policy emission, and option removal
- [x] 4.1-4.2 inactive export pruning
- [x] 5.1 formatting
- [x] 5.2 Go regression suite
- [x] 5.4 generated V1/V2 configuration assertions
- [x] 6.1-6.2 contract documentation and stale-reference removal

## Pending Tasks

- [ ] 5.3 Cross-platform evaluation aggregate: Linux evaluations passed; the local Linux Nix evaluator cannot evaluate the aarch64-darwin `macm5` Home Manager activation due to a platform mismatch.
- [ ] 5.5 Rog runtime deny smoke: `opencode2 models` produced no output and exceeded the 120-second safe command timeout before the GROQ rejection could be tested.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused configuration test | `nix eval --json --impure --expr '...providers...{ providerAllowlist; disabledProviders; }'` passed. The allowlist is `opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia`; the V1 deny set is the required nine catalog IDs and excludes NVIDIA. |
| Generated V2 configuration | `nix build --no-link --print-out-paths .#homeConfigurations.rog.activationPackage` passed. The generated V2 JSON starts with `deny provider.use *`, followed by ordered allow entries for the six IDs. |
| Linux evaluation | `nix eval` passed for the rog, thinkcentre, and t14 Home Manager activation packages and NixOS toplevel derivations. |
| Repository checks | `nix fmt` formatted six touched Nix files; `nix flake check --no-build` passed; `go -C pkgs/nixos-scripts test ./...` passed. |
| Runtime harness | Blocked: `opencode2 models` exceeded 120 seconds with no output. No activation was performed and no GROQ run was attempted. |
| Rollback boundary | Revert `linux/home/groq-dictation.nix`, `linux/home/shared-modules.nix`, and the four `shared/opencode*.nix` files. Sops declarations and encrypted secrets were not changed. |

## Deviations

None. The implementation follows the design: GROQ was re-homed before removal, NVIDIA remains untouched, and policy ordering is deny-first then the canonical allowlist.

## Blockers

The local host cannot perform the macm5 aarch64-darwin evaluation, and the required rog runtime command timed out. The runtime deny smoke must run after a healthy rog V2 service is available.
