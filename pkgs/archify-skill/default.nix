{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "archify-skill";
  version = "3.3.1";

  src = fetchFromGitHub {
    owner = "tt-a1i";
    repo = "archify";
    tag = "v${finalAttrs.version}";
    hash = "sha256-D8TPxxEmkeFrreN/vbmfvyHGKDef0cTzUIAXUrfBA60=";
  };

  sourceRoot = "source/archify";
  npmDepsHash = "sha256-93zNihmjw4OAUPqyFhUJMauraM6VzJgaA71jtvQPr18=";
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
