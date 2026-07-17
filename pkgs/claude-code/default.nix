{ lib
, stdenvNoCC
, makeBinaryWrapper
, claude-code-unwrapped
}:

stdenvNoCC.mkDerivation {
  pname = "claude-code";
  version = claude-code-unwrapped.version or "unknown";

  nativeBuildInputs = [ makeBinaryWrapper ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    makeBinaryWrapper ${claude-code-unwrapped}/bin/claude $out/bin/claude \
      --add-flags "--model sonnet"
  '';

  meta = (claude-code-unwrapped.meta or { }) // {
    mainProgram = "claude";
    description = "Claude Code with Gentle AI default model (Opus plan mode, Sonnet execution)";
  };
}
