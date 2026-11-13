{
  buildGoModule,
  git,
  jq,
  lib,
  makeWrapper,
  qrencode,
  pkgs,
}:

buildGoModule {
  pname = "nixos-scripts";
  version = "1.0.0";

  src = ./.;

  subPackages = [
    "cmd/adguard-tunnel"
    "cmd/ai-backup"
    "cmd/ai-assets-reconcile"

    "cmd/code-work"
    "cmd/compare-palette"
    "cmd/device-link"
    "cmd/export-mate-config"
    "cmd/format-nix"
    "cmd/rtk-init"
    "cmd/relayctl"
    "cmd/relay-client"
    "cmd/relay-policy"
    "cmd/gastown-run"
    "cmd/git-id"
    "cmd/gpg-unlock"
    "cmd/install-opencode-auth-seed"
    "cmd/linkctl"
    "cmd/netconsole-log"
    "cmd/netconsole-setup"
    "cmd/pinentry-auto"
    "cmd/rog-poweroff-hook"
    "cmd/netdiag"
    "cmd/nix-cache"
    "cmd/nixos-build"
    "cmd/nixos-build-all"
    "cmd/opencode-home"
    "cmd/opencode-harness-init"
    "cmd/opencode-login-bridge"
    "cmd/opencode-layout-migrate"
    "cmd/sops-rotate-keys"
    "cmd/sync-opencode-remote"
    "cmd/test-shutdown"
    "cmd/wol-relay"
    "cmd/wg-peer"
  ];

  vendorHash = null;

  nativeBuildInputs = [
    git
    makeWrapper
  ];

  nativeCheckInputs = [ jq ];

  postFixup = ''
    # qrencode is a runtime dep of device-link (terminal QR output).
    wrapProgram $out/bin/device-link \
      --prefix PATH : ${lib.makeBinPath [ qrencode ]}
    wrapProgram $out/bin/gpg-unlock \
      --prefix PATH : ${lib.makeBinPath [ git ]}
    mkdir -p $out/libexec/nixos-scripts
    mv $out/bin/gastown-run $out/libexec/nixos-scripts/gastown-run
    ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      ln -s ${pkgs.pinentry-qt}/bin/pinentry-qt $out/libexec/nixos-scripts/pinentry-qt
      ln -s ${pkgs.pinentry-qt}/bin/pinentry-curses $out/libexec/nixos-scripts/pinentry-curses
      ln -s pinentry-auto $out/bin/pinentry
    ''}
  '';

  doCheck = true;

  meta = with lib; {
    description = "Go operational tools for the NixOS workflow (source co-located with derivation)";
    license = licenses.mit;
    mainProgram = "pinentry-auto";
  };
}
