{ lib
, buildGoModule
, makeWrapper
, qrencode
,
}:

let
  # Bash scripts still awaiting their Go port (bash-to-go-migration).
  # Deleted from this list wave-by-wave as cmd/ entries reach parity.
  bashScripts = [
    "code-work"
    "add-wireguard-peer"
    "ai-backup"
    "compare-palette"
    "export-mate-config"
    "generate-thinkpad-wireguard"
    "linkctl"
    "nixos-build"
    "nixos-build-all"
    "opencode2"
    "opencode-home"
    "remove-wireguard-peer"
    "sops-rotate-keys"
    "sync-opencode-remote"
    "wg-peer"
    "device-link"
  ];
in
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
    "cmd/git-id"
    "cmd/format-nix"
  ];

  # Zero external dependencies so far — no vendor FOD needed. Revisit when a
  # go.mod dependency lands (fakeHash → `got:` loop, see gentle-ai/engram).
  vendorHash = null;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # Bash originals pending migration (parallel-run until Go parity).
    mkdir -p $out/bin/lib
    ${lib.concatStringsSep "\n" (
      map (s: "install -m755 ${../../bin}/${s} $out/bin/${s}") bashScripts
    )}
    install -m755 ${../../bin}/lib/common.sh $out/bin/lib/common.sh
  '';

  postFixup = ''
    # qrencode is a runtime dep of device-link (terminal QR output).
    wrapProgram $out/bin/device-link \
      --prefix PATH : ${lib.makeBinPath [ qrencode ]}
  '';

  meta = with lib; {
    description = "Go + bash operational scripts for the NixOS workflow (Go-only after bash-to-go-migration)";
    license = licenses.mit;
  };
}
