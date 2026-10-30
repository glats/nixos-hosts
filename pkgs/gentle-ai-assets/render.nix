{
  lib,
  buildGoModule,
  opencode,
  gentle-ai-src,
  vendorHash ? "sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=",
}:

buildGoModule {
  pname = "gentle-ai-rendered-prompts";
  version = "4.3.1";
  src = gentle-ai-src;
  inherit vendorHash;

  postPatch = ''
    mkdir -p internal/nixexport
    cp ${./render_test.go} internal/nixexport/render_test.go
  '';

  buildPhase = ''
    runHook preBuild
    mkdir -p "$TMPDIR/native-v2"
    ln -s ${opencode}/bin/opencode "$TMPDIR/native-v2/opencode"
    export PATH="$TMPDIR/native-v2:$PATH"
    export HOME="$TMPDIR/renderer-home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    mkdir -p "$HOME"
    export GENTLE_AI_RENDER_OUTPUT="$TMPDIR/rendered"
    go test -mod=vendor -count=1 -v ./internal/nixexport
    runHook postBuild
  '';
  doCheck = false;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/gentle-ai"
    cp -r "$GENTLE_AI_RENDER_OUTPUT"/. "$out/share/gentle-ai/"
    runHook postInstall
  '';

  meta = {
    description = "Build-only canonical Gentle AI v4 runtime prompts";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
