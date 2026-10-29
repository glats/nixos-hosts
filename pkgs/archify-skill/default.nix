{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "archify-skill";
  version = "3.2.0";

  src = fetchFromGitHub {
    owner = "tt-a1i";
    repo = "archify";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pejw78BgKDnttOAGcLvVtWa50azpCjTfESnmdYIjCoI=";
  };

  sourceRoot = "source/archify";
  npmDepsHash = "sha256-MubkY+0P5trSwb69/jOQC/TH0L/3tt/boLmXizfAIcE=";
  dontNpmBuild = true;

  installPhase = ''
    mkdir -p "$out"
    cp -r ./. "$out/"
  '';

  meta = with lib; {
    description = "Pinned, runnable Archify agent skill";
    homepage = "https://github.com/tt-a1i/archify";
    license = licenses.mit;
    platforms = platforms.all;
  };
})
