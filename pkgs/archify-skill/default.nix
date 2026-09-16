{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage {
  pname = "archify-skill";
  version = "2.17.0-dev.1";

  src = fetchFromGitHub {
    owner = "tt-a1i";
    repo = "archify";
    rev = "d673e8300df60a5c8166abe78787fdc78f6b8000";
    hash = "sha256-0GKYLvKBGJ5Skwm2vOrdAQ1x9PfMqzXpmRsT+UMRaN4=";
  };

  sourceRoot = "source/archify";
  npmDepsHash = "sha256-yKsABEczUQhfBUDp85XEwH26aDlKXWcOdR6TOH7/9uE=";
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
}
