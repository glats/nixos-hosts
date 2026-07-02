# Proposal: Verify t14 Hardware Video Acceleration

## Intent

Confirm that the T14 (AMD Gen 4) has working VA-API hardware video acceleration and document the verification recipe so future sessions don't re-investigate the same question. The stack _looks_ complete from config alone (`hardware.graphics.enable`, `amdgpu` KMS, `libva-utils`, `mpv`, `ffmpeg`), but no live `vainfo` check has been recorded.

## Scope

### In Scope
- Add a verification comment block in `modules/hardware/amd-laptop.nix` documenting the recipe: `vainfo`, `mpv --hwdec=vaapi`, `intel_gpu_top` / `radeontop`
- Run `vainfo` on live t14 to confirm which driver loads
- **Conditionally** add `libva-mesa-driver` to `modules/base/profiles/media.nix` only if `vainfo` shows a missing or wrong driver
- Add per-user mpv `hwdec=vaapi` default in `hosts/t14/home/omarchy.nix` (independent polish)

### Out of Scope
- Hyprland DMA-BUF screen-capture tuning (separate concern)
- Brave/Chromium `--enable-features=VaapiVideoDecodeLinuxGL` flags (already working, no change needed)
- Any `hardware-configuration.nix` edits (auto-generated, never manual)

## Capabilities

### New Capabilities
None — this is a documentation + conditional config change, no new spec-level behavior.

### Modified Capabilities
None — existing media and hardware modules keep their contracts.

## Approach

**Option A (primary)**: Document the verification recipe as Nix comments in `amd-laptop.nix`. No runtime change. Zero rebuild risk.

**Option B (conditional)**: If live `vainfo` on t14 reports no VA-API entrypoints or the wrong driver, add `libva-mesa-driver` to `media.nix`. This is a one-line package add.

**Option C (independent polish)**: Set `hwdec=vaapi` in t14's mpv config so hardware decode is the default, not opt-in.

All three are independent and can be delivered in a single commit or split.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/hardware/amd-laptop.nix` | Modified | Add verification comment block (lines 7-9 area) |
| `modules/base/profiles/media.nix` | Conditionally modified | Add `libva-mesa-driver` only if `vainfo` shows it's missing |
| `hosts/t14/home/omarchy.nix` | Modified | Add mpv `hwdec=vaapi` default |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `libva-mesa-driver` conflicts with existing `intel-vaapi-driver` | Low | Mesa driver is AMD-specific; Intel driver is a no-op on AMD. Both can coexist. |
| `vainfo` shows unexpected output | Low | That's the whole point of the check — we adapt based on output. |
| mpv `hwdec=vaapi` breaks software-decoded files | Very Low | mpv falls back to software decode automatically if VA-API fails. |

## Rollback Plan

Trivial:
- Remove comment block from `amd-laptop.nix` (or `git revert`)
- Remove `libva-mesa-driver` from `media.nix` if added
- Remove mpv config line from `omarchy.nix`
- Run `nixos-build` to rebuild

## Dependencies

- Live access to t14 to run `vainfo` and confirm driver state
- No external package or flake input changes required

## Success Criteria

- [ ] `vainfo` output on t14 is recorded (screenshot or pasted into commit message)
- [ ] Verification recipe is documented as comments in `amd-laptop.nix`
- [ ] If `vainfo` shows missing driver, `libva-mesa-driver` is added to `media.nix`
- [ ] mpv plays a test video with `hwdec=vaapi` without errors
- [ ] `nix flake check --no-build` passes
