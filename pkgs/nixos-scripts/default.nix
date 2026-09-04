{ lib
, buildGoModule
, makeWrapper
, qrencode
,
}:

buildGoModule {
  pname = "nixos-scripts";
  version = "1.0.0";

  # Whitelist: Go module sources ONLY. secrets/, .sops.yaml and every other
  # repo path must never enter the build sandbox.
  src = lib.fileset.toSource {
    root = ../../.;
    fileset = lib.fileset.unions [
      ../../go.mod
      ../../go.sum
      ../../cmd
      ../../internal
    ];
  };

  subPackages = [
    "cmd/ai-backup"
    "cmd/code-work"
    "cmd/compare-palette"
    "cmd/device-link"
    "cmd/export-mate-config"
    "cmd/format-nix"
    "cmd/git-id"
    "cmd/install-opencode-auth-seed"
    "cmd/linkctl"
    "cmd/netdiag"
    "cmd/nixos-build"
    "cmd/nixos-build-all"
    "cmd/opencode-home"
    "cmd/opencode2"
    "cmd/sops-rotate-keys"
    "cmd/sync-opencode-remote"
    "cmd/wg-peer"
  ];

  # Zero external dependencies so far — no vendor FOD needed. Revisit when a
  # go.mod dependency lands (fakeHash → `got:` loop, see gentle-ai/engram).
  vendorHash = null;

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    # qrencode is a runtime dep of device-link (terminal QR output).
    wrapProgram $out/bin/device-link \
      --prefix PATH : ${lib.makeBinPath [ qrencode ]}
  '';

  meta = with lib; {
    description = "Go operational scripts for the NixOS workflow (bash retired by bash-to-go-migration)";
    license = licenses.mit;
  };
}
