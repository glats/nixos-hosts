{
  buildGoModule,
  git,
  jq,
  lib,
  makeWrapper,
  qrencode,
  pkgs,
}:

let
  gitIdent = import ../../shared/git-identity.nix;
  gpgKeys = lib.concatStringsSep "\n" (
    lib.filter (k: k != "") [
      gitIdent.personal.signingKey
      gitIdent.work.signingKey
    ]
  );
in

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
    mkdir -p $out/share/nixos-scripts
    printf '%s\n' ${lib.escapeShellArg gpgKeys} > $out/share/nixos-scripts/gpg-unlock-keys
    wrapProgram $out/bin/gpg-unlock \
      --set NIXOS_SCRIPTS_GPG_KEYS_FILE $out/share/nixos-scripts/gpg-unlock-keys \
      --prefix PATH : ${lib.makeBinPath [ git ]}
    ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      mkdir -p $out/libexec/nixos-scripts
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
