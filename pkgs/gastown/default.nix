{
  lib,
  buildGoModule,
  fetchFromGitHub,
  icu,
  makeWrapper,
  pkg-config,
  beads,
  dolt,
  git,
  tmux,
}:

buildGoModule {
  pname = "gastown";
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "gastown";
    rev = "466aa41c83ee73b1fa0eb79eb9d172fb1eca9476";
    hash = "sha256-AXbyFAXiyup6I1Xmb/6a/pRdJg7Um+OdxIrAMSIuDUQ=";
  };

  subPackages = [ "cmd/gt" ];

  vendorHash = "sha256-1ZzA/crpwA2DleEyo+iIr2rQ+U+rRxNDneIBBWe++bo=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];
  buildInputs = [ icu ];

  env.CGO_ENABLED = "1";

  doCheck = false;

  postFixup = ''
    wrapProgram $out/bin/gt \
      --prefix PATH : ${
        lib.makeBinPath [
          beads
          dolt
          git
          tmux
        ]
      }
  '';

  meta = with lib; {
    description = "Gas Town multi-agent workspace coordinator (pinned commit)";
    homepage = "https://github.com/steveyegge/gastown";
    license = licenses.mit;
    mainProgram = "gt";
    platforms = [ "x86_64-linux" ];
  };
}
