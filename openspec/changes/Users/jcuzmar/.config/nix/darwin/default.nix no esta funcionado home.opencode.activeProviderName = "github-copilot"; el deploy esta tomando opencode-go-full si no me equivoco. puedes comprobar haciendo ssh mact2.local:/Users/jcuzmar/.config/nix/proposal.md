# Proposal: Fix mact2 OpenCode provider drift (darwin vs. standalone HM)

The deployed OpenCode config on mact2 resolves `opencode-go-medium` instead of `github-copilot`
because the host was last updated via the standalone `homeConfigurations.mact2` path, which does
not inherit the provider override declared in `darwin/default.nix`. This proposal aligns both
deployment paths so the drift cannot recur silently.

## Intent

Ensure `home.opencode.activeProviderName = "github-copilot"` is honoured on mact2 regardless
of which flake target was used for the last `home-manager switch`, and prevent silent provider
divergence going forward.

## Scope

| In scope | Out of scope |
|----------|-------------|
| mact2 provider selection in both flake targets | Other hosts or providers |
| Alignment of `homeConfigurations.mact2` with Darwin override | Changing the provider catalog |
| Guard against future standalone-HM drift on Darwin hosts | Linux HM deployment paths |

## Capabilities

1. `homeConfigurations.mact2` evaluates `activeProviderName` to `github-copilot`, matching `darwinConfigurations.mact2`.
2. A single re-deploy from either entry point produces an identical `opencode.json` provider tier.
3. Optional: divergence between the two targets is detectable at evaluation time (assertion or CI check).

## Approach

**Preferred — propagate override into standalone HM target** (`flake.nix`):

Extend the `extraModules` or `extraSpecialArgs` passed to `homeConfigurations.mact2` so the
same provider override applied in `darwin/default.nix` is also applied there. This can be a
direct inline `{ home.opencode.activeProviderName = "github-copilot"; }` module or a shared
per-host override module under `hosts/mact2/home/`.

**Alternative — drop standalone HM target for mact2**:

If `homeConfigurations.mact2` is not used intentionally (darwin-rebuild is the only supported
path), remove or mark the standalone target as unsupported and document that darwin-rebuild is
required for mact2.

## Affected Areas

| File | Change |
|------|--------|
| `flake.nix` | Add provider override to `homeConfigurations.mact2` extras, or remove target |
| `hosts/mact2/home/` (new, optional) | Per-host HM override module |
| `darwin/default.nix` | No change required — override is already correct |

## Risks

- Re-deploying with the wrong entry point before this fix re-writes the file to medium-tier.
- If the standalone target is kept, any future inline override in `flake.nix` duplicates logic from `darwin/default.nix` and must be kept in sync manually.
- Removing the standalone target blocks `home-manager switch --flake .#mact2` workflows if the user relies on it independently.

## Rollback Plan

1. On mact2: `darwin-rebuild switch --flake .#mact2` with the current repo restores `github-copilot` immediately (nix-darwin path is already correct).
2. If the flake change introduces a regression, revert the relevant commit and redeploy via darwin-rebuild.

## Dependencies

- Exploration artifact confirmed: `openspec/changes/.../exploration.md`
- No new inputs or packages required.

## Success Criteria

- [ ] `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName` returns `github-copilot`.
- [ ] `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName` returns `github-copilot`.
- [ ] Remote `/Users/jcuzmar/.config/opencode/opencode.json` on mact2.local contains `github-copilot/...` model assignments after redeploy.
- [ ] `nix flake check --no-build` passes.
