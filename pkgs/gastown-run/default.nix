{
  lib,
  runCommand,
  makeWrapper,
  nixos-scripts,
  gastown,
  beads,
  tmux,
  bubblewrap,
  codex,
  bash,
  coreutils,
  git,
  gnugrep,
  gnused,
  findutils,
  diffutils,
  gnumake,
  toolPackages ? [ ],
}:

let
  systemPath = lib.makeBinPath [
    bubblewrap
    coreutils
    bash
    git
  ];
  toolPath = lib.makeBinPath (
    [
      bash
      coreutils
      git
      gnugrep
      gnused
      findutils
      diffutils
      gnumake
    ]
    ++ toolPackages
  );
in
runCommand "gastown-run"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "Run project tasks through Gas Town with a sandboxed Codex executor";
      mainProgram = "gastown-run";
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    mkdir -p $out/bin
    makeWrapper ${nixos-scripts}/bin/gastown-run $out/bin/gastown-run \
      --set GASTOWN_GT ${gastown}/bin/gt \
      --set GASTOWN_BD ${beads}/bin/bd \
      --set GASTOWN_TMUX ${tmux}/bin/tmux \
      --set GASTOWN_BWRAP ${bubblewrap}/bin/bwrap \
      --set GASTOWN_CODEX ${codex}/bin/codex \
      --set GASTOWN_BASH ${bash}/bin/bash \
      --set GASTOWN_SYSTEM_PATH ${systemPath} \
      --set GASTOWN_TOOL_PATH ${toolPath} \
      --prefix PATH : ${lib.makeBinPath [ git ]}
  ''
