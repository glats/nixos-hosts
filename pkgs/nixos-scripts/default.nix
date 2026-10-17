{
  buildGoModule,
  git,
  jq,
  lib,
  makeWrapper,
  qrencode,
}:

buildGoModule {
  pname = "nixos-scripts";
  version = "1.0.0";

  src = ./.;

  subPackages = [
    "cmd/adguard-tunnel"
    "cmd/ai-backup"
    "cmd/ai-assets-reconcile"

    "cmd/browsermcp-broker"
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
    "cmd/install-opencode-auth-seed"
    "cmd/linkctl"
    "cmd/netconsole-log"
    "cmd/netconsole-setup"
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
  '';

  doCheck = true;

  meta = with lib; {
    description = "Go operational tools for the NixOS workflow (source co-located with derivation)";
    license = licenses.mit;
  };
}
