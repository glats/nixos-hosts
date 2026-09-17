## Exploration: improve-macm5-remote-launchers

### Current State
`darwin/home/remote-desktop.nix` compiles one native Mach-O launcher per entry and copies its bundle into `~/Applications`, then registers it with LaunchServices (`darwin/home/remote-desktop.nix:134-176`, `213-240`). The requested launchers are currently `remote-rog.app` and `remote-oneplus5.app`; their metadata display names are `rog (rdp)` and `oneplus5 (rdp)` (`darwin/home/remote-desktop.nix:147-168`, `188-196`). The bundle directory names therefore remain technical even if only `CFBundleDisplayName` changes.

Apple documents `CFBundleDisplayName` as user-visible metadata and requires the icon named by `CFBundleIconFile` to reside in the bundle resources directory. macOS icons are multi-resolution `.icns` files ([Apple Core Foundation Keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html); [Apple Bundle Programming Guide](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html)).

### Affected Areas
- `darwin/home/remote-desktop.nix` — owns bundle names, `Info.plist`, icon resources, activation replacement, and all four remote launchers.
- `darwin/home/shared-modules.nix:30` — imports the module for Darwin Home Manager configurations.
- `darwin/home/default.nix:16-25` and `hosts/macm5/default.nix:67-88` — compose that Home Manager configuration for macm5.
- `darwin/home/packages.nix:22-77` and `darwin/system/homebrew.nix:38-63` — provide FreeRDP and the TigerVNC cask; neither is a suitable existing RDP launcher icon source.

### Approaches
1. **Explicit names plus a bundled native `.icns` asset** — add separate display/bundle-name fields for only `rog` and `oneplus5`, producing `Remote Rog.app` and `Remote oneplus.app`, with matching `CFBundleName` and `CFBundleDisplayName`; copy a purpose-made or licensed `.icns` to `Contents/Resources` and set `CFBundleIconFile`.
   - Pros: guarantees the requested Finder-visible filenames and portable, self-contained icon metadata; follows the Nixpkgs bundle convention of placing an icon in `Contents/Resources` and writing plist icon keys ([Nixpkgs `makeDarwinBundle`](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/build-support/make-darwin-bundle/default.nix), [`writeDarwinBundle`](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/build-support/make-darwin-bundle/write-darwin-bundle.nix)).
   - Cons: no suitable `.icns` exists in this repository (the only found image is a Linux Chrome PNG); introducing artwork or a conversion tool adds asset, licensing, and maintenance scope.
   - Effort: Medium.

2. **Explicit names plus a copied macOS generic network icon** — keep the present custom builder, copy the target system's `GenericNetworkIcon.icns` into each requested bundle during Home Manager activation, and set `CFBundleIconFile` to that local copy.
   - Pros: no repository asset, package, or new dependency; semantically suitable and visually native. The CoreServices API defines `kGenericNetworkIcon`, and the installed CoreTypes resource path is independently documented as `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns` ([Apple API reference surfaced by Exa](https://developer.apple.com/documentation/coreservices/kgenericnetworkicon); [path reference](https://docs.rs/alfrusco/latest/alfrusco/constant.ICON_GENERIC_NETWORK.html)).
   - Cons: this is an OS-provided asset rather than a hermetic Nix input; the path and icon presence must be checked on macm5, and the activation should fall back safely if absent. It must be copied into `Contents/Resources`; an `Info.plist` reference alone cannot point outside the bundle.
   - Effort: Low.

3. **Explicit names only, retaining the default app icon** — rename only the two `.app` directories and their name/display metadata.
   - Pros: smallest, no asset or OS-path risk.
   - Cons: does not meet the request for a decent icon; the current resources directory is empty (`darwin/home/remote-desktop.nix:147-150`).
   - Effort: Low.

### Recommendation
Use approach 2 for this narrowly scoped quality fix: add an optional `bundleName` to the app definitions and set it only to `Remote Rog` and `Remote oneplus`, preserving `t14-tigervnc` and `thinkcentre` unchanged. Set both bundle name plist keys to the friendly name, use the friendly name for the `.app` directory and activation destination, and remove the two old technical bundle directories once so Spotlight/Finder do not retain duplicates. Copy the verified macm5 `GenericNetworkIcon.icns` into each renamed bundle before its existing ad-hoc code signing and LaunchServices registration. If macm5 lacks that resource, retain the default icon rather than adding an unreviewed asset.

This is a small host-local configuration change, but it benefits from a named SDD change because it alters generated application identity, requires a stale-bundle migration, and has target-only macOS verification. It does not justify broader remote-desktop refactoring or changes to the other two launchers.

### Risks
- `LSUIElement` remains true (`darwin/home/remote-desktop.nix:169-170`); verify on macm5 that the renamed bundles appear and launch as intended in the requested Finder/Launchpad surfaces.
- x86_64 Linux can evaluate the Darwin configuration but cannot validate the Mach-O bundle, system icon resource, `codesign`, LaunchServices, Spotlight, or Finder rendering; target verification requires macm5.
- The current Nixpkgs `makeDarwinBundle` helper is not a direct drop-in: it derives executable names from the application name and explicitly does not support spaces in executable names, while the existing launcher is always `launcher` ([source](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/build-support/make-darwin-bundle/write-darwin-bundle.nix)).

### Ready for Proposal
Yes — propose a macm5-only, two-launcher change with explicit friendly bundle/display names, guarded use of the existing macOS generic network `.icns`, cleanup of the old `remote-rog.app` and `remote-oneplus5.app` directories, and macm5 visual/launch verification. Linux can run `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` only as an evaluation check.
