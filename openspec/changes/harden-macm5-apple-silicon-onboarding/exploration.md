## Exploration: harden-macm5-apple-silicon-onboarding

### Current State
`macm5` is an `aarch64-darwin` Home Manager host. `darwin/home/packages.nix` installs nixpkgs `flameshot`, and `darwin/home/default.nix` enables `targets.darwin.linkApps`; the existing Spotlight helper only processes actual `.app` bundles exposed by that Home Manager application directory. NixHub confirms the current nixpkgs Flameshot package supports `aarch64-darwin` (14.0.0 in the queried channel). No Darwin Qt theme module, `QT_*` environment override, Flameshot launch agent, or declarative Flameshot configuration exists.

The host globally forces `AppleInterfaceStyle = "Dark"` and auto-hides the menu bar in `darwin/system/settings.nix`. `darwin/home/theme.nix` deliberately provides only the repository palette, not GTK/Qt configuration. That is appropriate: on macOS the Qt Cocoa platform theme, not Home Manager's Linux-oriented `qt` module, owns native widget appearance. Qt documents Aqua as AppKit-backed but not as a one-to-one native-control wrapper, and its Cocoa integration follows macOS menu-bar conventions automatically.

Flameshot is a Qt Widgets application with macOS-specific code. Upstream builds a `Flameshot.app` with bundle identifier `org.flameshot.Flameshot`, a Retina-capable `.icns`, and the Cocoa platform plugin in a distributable bundle. At runtime it uses a monochrome `QSystemTrayIcon` status item on Big Sur and newer, requests Screen Recording access through `CGPreflightScreenCaptureAccess`/`CGRequestScreenCaptureAccess`, and temporarily shows a Dock icon while its launcher/configuration windows are visible. However, it applies a custom global stylesheet for capture buttons and exposes colours rather than a system light/dark theme setting. Therefore a native Qt platform theme can improve ordinary Qt surfaces, but cannot make Flameshot's custom capture overlay or toolbar identical to Tahoe's Liquid Glass.

Qt's Tahoe guidance says Qt is generally forward-compatible with macOS 26, while Liquid Glass introduced native-style issues. The documented compatibility escape hatches are rebuilding with Xcode 16 or setting `UIDesignRequiresCompatibility=YES` in the app bundle's `Info.plist`; neither adds Liquid Glass, and the latter intentionally retains pre-Tahoe metrics. Qt also handles Retina scaling automatically from macOS display preferences; it advises against persistent scale environment overrides. These facts rule out a repository-level Qt theme or HiDPI workaround as the path to polish.

Upstream evidence makes permission and status-item behavior the practical risks. Tahoe/Apple Silicon reports show Screen & System Audio Recording grants can become stale and repeatedly prompt; the upstream recovery is to remove the app's permission entry and grant it again. An open upstream PR reports a Qt/Cocoa status-menu crash after capture on macOS 27/Qt 6.11 and proposes a manual popup workaround, so local tray rewrites would be fragile and should remain upstream-owned. Apple documents that screen capture requires user consent recorded in Screen Recording privacy settings.

### Affected Areas
- `darwin/home/packages.nix` — current nixpkgs package declaration; retain it as the sole installation source.
- `darwin/home/default.nix` — `targets.darwin.linkApps.enable` is the existing app-discovery path, but it cannot turn a non-bundled executable into a fully signed, LaunchServices-managed application.
- `darwin/home/spotlight-index.nix` — indexes only `.app` bundles and copies bundle metadata/icons for Spotlight; do not extend it to synthesize a Flameshot bundle.
- `darwin/home/theme.nix` and `darwin/system/settings.nix` — establish the intentional macOS-only palette boundary and forced dark system appearance; no Qt setting belongs here.
- `openspec/changes/harden-macm5-apple-silicon-onboarding/tasks.md` — a future task may record native macm5 visual/permission acceptance, but no production configuration is justified by this exploration.

### Approaches
1. **Keep the native Cocoa defaults and validate the packaged app on macm5** — Retain nixpkgs `flameshot`, the system-selected dark appearance, normal macOS display scaling, and upstream tray behavior; grant Screen Recording interactively for the actual launch entry point.
   - Pros: Uses the supported `aarch64-darwin` package; lets Qt select Cocoa/Aqua and Retina behavior; avoids unsupported environment forcing, unsigned bundle copies, and TCC/LaunchServices manipulation; smallest reversible scope.
   - Cons: The custom Flameshot overlay remains recognizably Flameshot rather than fully Liquid Glass; native proof must happen on macm5.
   - Effort: Low.

2. **Add a Flameshot-specific user configuration** — Declaratively write `~/.config/flameshot/flameshot.ini` only to choose harmless user preferences such as UI accent colour, shortcut, or native-fullscreen behavior.
   - Pros: Can make a consciously chosen interaction preference repeatable.
   - Cons: Upstream offers no light/dark or Cocoa-style switch; `useNativeFullscreen` changes capture behavior, not Tahoe styling; an owned INI can conflict with user edits and upstream option validation. It does not solve permissions, bundle identity, or the tray.
   - Effort: Low, but unjustified without a concrete requested preference.

3. **Force Qt, patch the bundle, or manufacture a LaunchServices app** — Set `QT_QPA_PLATFORMTHEME`/scale/style variables, alter `Info.plist`, wrap/copy an `.app` into `/Applications`, or add a custom status/menu integration.
   - Pros: Could alter individual visual details or app discovery in a local experiment.
   - Cons: Cocoa is already Qt's native platform path; forcing Linux-oriented platform themes or scale variables can bypass native behavior. A Nix store-backed package cannot safely be made into a stable signed/notarized distribution by a Home Manager wrapper. TCC consent is user-controlled and tied to the launched application identity; changing bundle/signing/LaunchServices registration is a common source of stale permission state. `UIDesignRequiresCompatibility` opts out of Tahoe styling rather than improving it, and tray fixes belong upstream.
   - Effort: Medium/High and not advisable.

### Recommendation
Adopt Approach 1. Keep nixpkgs Flameshot as the only macm5 package declaration and add no Qt environment variables, app-specific Flameshot INI, bundle wrapper, LaunchAgent, Homebrew cask, Gatekeeper bypass, Info.plist mutation, or tray patch. The forced dark macOS setting supplies the system appearance; Cocoa/Qt and normal macOS display settings supply native dark-mode and HiDPI behavior where upstream permits them.

Native acceptance should launch exactly the installed Flameshot entry point, confirm a sharp Retina status icon/overlay and normal menu-bar interaction, take a capture, then grant **System Settings → Privacy & Security → Screen & System Audio Recording** if prompted and relaunch before retesting. If access appears granted but capture is blank or it repeatedly prompts, remove Flameshot's permission entry, relaunch the same entry point, and grant it again; do not automate `tccutil`, copy the bundle, or re-register it with LaunchServices. The app-specific config answer is therefore **no**, unless the user later requests a specific non-visual Flameshot preference.

Non-goals are Liquid Glass parity, a global macOS Qt theming layer, changing the system dark/light policy, overriding Retina scaling, modifying upstream Flameshot, managing TCC declaratively, changing code signing/notarization, and adding a login/background-service integration. Those need upstream or a separately scoped packaged-app change, not onboarding hardening.

### Risks
- Qt's Aqua/Cocoa widgets are native-looking but not individual AppKit controls; Flameshot's custom stylesheet prevents a guarantee of Tahoe/Liquid Glass parity.
- The global hidden menu bar may reduce the visibility of normal macOS menu-bar UI; verify the status item on the physical host instead of changing either the host default or Flameshot tray code.
- Screen Recording consent can remain stale after package/bundle identity changes; the user must grant it for the actual launched app and may need the upstream remove-and-regrant recovery.
- The current upstream status-item implementation has a pending macOS 27 crash report; avoid carrying an unmerged workaround locally and monitor upstream when upgrading Flameshot/Qt.

### Sources
- [Qt: Qt on macOS 26 Tahoe](https://www.qt.io/blog/qt-on-macos-26-tahoe) — Tahoe support and compatibility-mode trade-off.
- [Qt: macOS-specific issues](https://doc.qt.io/qt-6/macos-issues.html) — Aqua, native menu-bar behavior, and Qt/macOS limits.
- [Qt: High DPI](https://doc.qt.io/qt-6/highdpi.html) — automatic Retina support and native display-settings guidance.
- [Qt: macOS deployment](https://doc.qt.io/qt-6/macos-deployment.html) — bundle and Cocoa platform-plugin requirements.
- [Apple: Meet ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2022/10156/) — consent is stored in Screen Recording privacy settings.
- [Flameshot source: macOS lifecycle and permission request](https://github.com/flameshot-org/flameshot/blob/master/src/core/flameshot.cpp), [tray implementation](https://github.com/flameshot-org/flameshot/blob/master/src/widgets/trayicon.cpp), and [bundle build](https://github.com/flameshot-org/flameshot/blob/master/src/CMakeLists.txt).
- [Flameshot #4940](https://github.com/flameshot-org/flameshot/issues/4940) and [#4810](https://github.com/flameshot-org/flameshot/issues/4810) — Tahoe/Apple Silicon permission recovery reports; [PR #4739](https://github.com/flameshot-org/flameshot/pull/4739) — pending Qt/Cocoa tray crash workaround.

### Ready for Proposal
Yes — the active change can record a macm5-only native acceptance check, but no production edit is recommended for this visual polish request. The proposal should explicitly preserve nixpkgs packaging and system-managed appearance, and treat upstream limitations as acceptance boundaries rather than configuration defects.
