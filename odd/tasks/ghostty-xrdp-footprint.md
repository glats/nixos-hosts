# Ghostty low CPU/RAM footprint on XRDP hosts

Objective: make Ghostty consume little CPU and little RAM when it runs inside an XRDP
(X11 over RDP) session on the rog and thinkcentre hosts, using only the configuration
options Ghostty 1.3.1 actually exposes.
Branch: `feat/ghostty-opt` (worktree `feat-ghostty-opt`).
Delivery strategy: single work-unit commit on the feature branch; push/PR left to the user.
Test runner: `nix eval` over the affected home configurations, `ghostty +validate-config`,
and an A/B measurement of idle CPU and RSS on the live XRDP display `:10`.

## Specs

- S1: On the XRDP hosts Ghostty's scrollback buffer must be bounded by a sane value
  expressed in the unit Ghostty 1.3.1 uses.
  Acceptance: the generated Ghostty config for rog and thinkcentre sets
  `scrollback-limit = 10000000` (10 MB, the Ghostty default). The shared value in
  `shared/ghostty.nix` is left untouched for the local-desktop hosts (t14, samsung,
  macm5) because the request only covers the XRDP sessions.
  Checks: `nix eval .#homeConfigurations.rog.config.programs.ghostty.settings` and the
  same for thinkcentre.
- S2: On the XRDP hosts the Ghostty window must be fully opaque.
  Acceptance: `background-opacity = 1` and `background-blur = false` for rog and
  thinkcentre; the shared/translucent look stays for the non-XRDP hosts.
  Checks: `nix eval` of the two XRDP home configurations and of t14/samsung/macm5.
- S3: On the XRDP hosts Ghostty must not trigger continuous idle repaints, and must not
  pay for the alpha blending of a translucent window.
  Acceptance: `background-opacity = 1`, `background-blur = false`,
  `cursor-style-blink = false` and `link-url = false` for rog and thinkcentre.
  Checks: `nix eval` of the two XRDP home configurations.
- S4: The XRDP-specific Ghostty settings must apply only to the hosts that actually serve
  XRDP sessions, and must be opt-in per host through an explicit repository option.
  Acceptance: a documented option in the Linux Ghostty Home Manager module, enabled in
  `hosts/rog/home/default.nix` and `hosts/thinkcentre/home/default.nix`, disabled by
  default everywhere else.
  Checks: `nix eval` comparison of the rog/thinkcentre settings against t14/samsung.
- S5: The user-visible request is the original wording of the request:
  "como podemos hacer que ghotty consuma poca cpu y ojala poca rama en xrdp con las
  opcoines que tenga". The delivered change must reduce the resident memory of a
  Ghostty instance running on display `:10` (the XRDP display of rog) compared to the
  pre-change configuration, without breaking terminal behaviour.
  Measured idle CPU is reported as a separate, honest finding: it is NOT expected to
  improve, because the idle CPU on that display is dominated by the software OpenGL
  fallback of the XRDP X server, which no Ghostty option can influence.
  Checks: A/B measurement on display `:10`, interleaved baseline/candidate runs, peak
  RSS under 400k lines of output, and idle CPU grouped by X11 focus regime.
- S6: Every generated Ghostty configuration must stay valid for the Ghostty version that
  is actually installed.
  Acceptance: `ghostty +validate-config --config-file=<generated config>` exits zero for
  every affected host.
  Checks: `ghostty +validate-config` against the rendered config files.

## Tasks

- T1 (inline): profile the current Ghostty instance on display `:10` and identify the
  cost drivers. Linked: S1, S5. Status: done. Evidence: see Log L2.
- T2 (delegated): implement the opt-in XRDP profile in the Linux Ghostty Home Manager
  module and enable it on rog and thinkcentre. The shared `shared/ghostty.nix` keeps its
  current values for the local-desktop hosts.
  Linked: S1, S2, S3, S4. Status: done. Evidence: see Log L4.
- T3 (delegated): evaluate and validate every affected home configuration
  (rog, thinkcentre, t14, samsung, macm5) and run `ghostty +validate-config` on the
  rendered configs. Linked: S2, S3, S4, S6. Status: done. Evidence: see Log L4.
- T4 (delegated): run the A/B measurement on display `:10` for the pre-change and
  post-change configurations and record idle CPU and RSS. Linked: S5. Status: done.
  Evidence: see Log L6.
- T5 (inline): document the change and the measured result. Linked: S5. Status: done.
  Evidence: see Log L7.

## Log

- L1 (2026-11-11): "como podemos hacer que ghotty consuma poca cpu y ojala poca rama en
  xrdp con las opcoines que tenga"
- L2 (2026-11-11): profiling of the live XRDP session on rog (display `:10`, Ghostty
  1.3.1 from nixpkgs 26.05, single-instance process PID 254597).
  Measured idle CPU over 25 s: Ghostty 23% of one core, Xorg 3%, every other desktop
  process ~0%. RSS: Ghostty 441 MB (heap 233 MB, Mesa LLVM JIT 50 MB, NVIDIA EGL libs
  20 MB).
  Root cause of the CPU cost: the XRDP X server runs the `xrdpdev` driver with
  `DRMAllowList = amdgpu i915 msm radeon`, so NVIDIA is not exposed to the session.
  Ghostty logs `libEGL warning: DRI3 error: Could not get DRI3 device` and falls back to
  software OpenGL (Mesa `libgallium` + `libLLVM` mapped in the process, `nvidia-smi`
  shows no client). Every frame is therefore rasterised on the same CPU that also
  encodes the RDP frames.
  Root cause of the RAM cost: `shared/ghostty.nix` sets `scrollback-limit = 4294967295`.
  Since Ghostty 1.0 this option is measured in BYTES per terminal surface (default
  10_000_000 = 10 MB), not lines; the value was carried over from the pre-1.0 line-based
  semantics and now authorises 4 GiB of scrollback per surface.
  Measured A/B on a virtual display with 400k lines of output: RSS 555 MB with the 4 GiB
  limit versus 282 MB with a 10 MB limit.
  Alpha blending is the second CPU cost: with `background-opacity = 0.8` the compositor
  has to blend a translucent window on every frame.
- L3 (2026-11-11): user asked to move the work into a formal ODD flow because the
  inline investigation was consuming too much context: "oye papi vamos por un odd mejor
  dale? porque esta gastando como logo". Scope of the implementation was frozen at the
  specs above; T2, T3 and T4 are delegated to a bounded worker to keep the parent
  context small.
- L4 (2026-11-11): T2 and T3 implemented. `linux/home/ghostty.nix` gained the opt-in
  option `home.ghostty.xrdp-optimized` (bool, default `false`) which feeds the existing
  `extraSettings` parameter of `shared/ghostty.nix`, so the merge order is the shared
  settings first and the XRDP overrides second, and `shared/ghostty.nix` is untouched.
  The overrides are `scrollback-limit = 10000000`, `background-opacity = 1`,
  `background-blur = false`, `cursor-style-blink = false` and `link-url = false`.
  The option is enabled only in `hosts/rog/home/default.nix` and
  `hosts/thinkcentre/home/default.nix`.
  Evidence: `nix eval --json .#homeConfigurations.{rog,thinkcentre}.config.programs.ghostty.settings`
  returns the five overrides; the same evaluation for t14, samsung and macm5 is
  byte-identical to the base commit (still `background-opacity = 0.8` and
  `scrollback-limit = 4294967295`).
  The rendered config for rog is `/nix/store/6rbmnf6y2mwn790rq05bdp5x84l2xhf3-ghostty-config`
  (`xdg.configFile."ghostty/config".source`); `ghostty +validate-config --config-file=<that path>`
  exits 0, and so does the validation of the `nix-colors` theme file.
  The macm5 derivation is `aarch64-darwin` only and cannot be realised on this Linux
  host, so its rendered text was extracted from the derivation and validated from a
  scratch file: exit 0.
  `nix flake check --no-build` and `nix build .#checks.x86_64-linux.format` both pass.
- L5 (2026-11-11): remaining risk to confirm in T4. The XRDP profile removes the
  per-frame alpha blending and the scrollback over-allocation, but the dominant cost
  measured in L2 was the software OpenGL fallback caused by the `xrdpdev` driver not
  exposing NVIDIA (`DRMAllowList = amdgpu i915 msm radeon`). No Ghostty configuration
  option can fix that, so T4 should expect a partial, not a total, CPU reduction.
- L6 (2026-11-11): T4 A/B measurement on display `:10`, interleaved baseline/candidate
  runs, both configs isolated with `XDG_CONFIG_HOME` pointing at an empty scratch dir
  because Ghostty 1.3.1 still reads `$XDG_CONFIG_HOME/ghostty/config` even when
  launched with `--config-default-files=false`.
  RESIDENT MEMORY, the confirmed win. Peak RSS under 400k lines of output:
  baseline 955.2 / 954.8 / 955.8 MB, candidate 319.4 / 319.0 / 324.4 MB
  (median 955.2 MB versus 319.4 MB, about -66%). Idle RSS stays flat at about
  309 MB for both, because the bound only matters once the scrollback actually fills.
  IDLE CPU, NOT confirmed. The measurement is bimodal because it depends on X11 input
  focus: a focused Ghostty window burns 23-33% of a core, an unfocused one 0-1%.
  Pooled over 9 focused samples per configuration the medians are baseline 27.20%
  versus candidate 26.05%, and the sign flips between the 20 s and the 60 s series,
  so the difference is inside noise. This matches L2: the cost is the llvmpipe
  software OpenGL fallback forced by the `xrdpdev` driver, not a Ghostty setting.
  Two of the five overrides are no-ops on their own: `background-opacity = 1` and
  `background-blur = false` are already the Ghostty 1.3.1 defaults, but they still
  differ from the SHARED repository value (`background-opacity = 0.8`), so setting
  them is what removes the alpha blending in the XRDP session.
- L7 (2026-11-11): user-visible behaviour change to document. On the XRDP hosts the
  scrollback history is now bounded at 10 MB per surface, so a long-running session
  discards old scrollback instead of keeping up to 4 GiB. This is the intended trade
  and it is what produces the -66% peak RSS, but it is not free: anything the user
  relied on for deep scrollback history on rog/thinkcentre is now capped.
  Recommended follow-up, NOT implemented here because it changes the XRDP X server
  rather than Ghostty: give the XRDP session hardware GL. SUPERSEDED (2026-11-11): this
  recommendation was WRONG about the mechanism. The GPU to use is the Intel i915 iGPU,
  not NVIDIA (upstream xorgxrdp does not support the proprietary driver with a virtual
  monitor, and kmscon already holds the NVIDIA DRM device), and the blocker was not the
  `xrdpdev` configuration but the fact that nixpkgs compiles xorgxrdp without
  `--enable-glamor`, which makes every DRMDevice/DRI3 option dead code. See
  `odd/tasks/xrdp-dri3-acceleration.md` for the root cause, the proof and the fix.
- L8 (2026-11-11): work-unit commit `69adaf5e` on `feat/ghostty-opt` (4 files, 187
  insertions, 3 deletions). Risk line: none. The change only ADDS an optional field
  (`home.ghostty.xrdp-optimized`, default `false`) to a shared module and preserves the
  previous behaviour byte for byte for every host that does not enable it, which the
  differential against the base commit proved for t14, samsung and macm5; no item of the
  high-risk list fires.
  Native risk assessment: `gentle-ai review assess --cwd <repo> --agent opencode
  --base-ref HEAD~1 --committed-only --json` returned `risk = medium`
  (`executable_change` on `hosts/rog/home/default.nix`), `review_due = false`,
  `review_due_reason = under_budget`. The commit therefore stays pending in this slice
  until a later commit reaches the review budget; no native review was started.
  Parent spot check after the writer returned: `nix eval --json
  .#homeConfigurations.rog.config.programs.ghostty.settings` returns scrollback-limit
  10000000, background-opacity 1, background-blur false, cursor-style-blink false,
  link-url false; the same evaluation for t14 returns scrollback-limit 4294967295 and
  background-opacity 0.8; `ghostty +validate-config --config-file=/nix/store/6rbmnf6y2mwn790rq05bdp5x84l2xhf3-ghostty-config`
  exits 0; `nix fmt` reports 0 files changed.
  NOT done, left to the user: push, pull request, and `home-manager switch` /
  `nixos-rebuild` on rog and thinkcentre. The change is inert until it is activated on
  those two hosts.
