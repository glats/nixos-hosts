# asus-fan-control
# Fan control for ASUS devices running Linux
# Source: https://github.com/dominiksalvet/asus-fan-control
{ lib
, stdenv
, makeWrapper
, dmidecode
, coreutils
, gnugrep
, gawk
, kmod
, asus-fan-control-src
,
}:

stdenv.mkDerivation rec {
  pname = "asus-fan-control";
  version = asus-fan-control-src.rev or "unstable";

  src = asus-fan-control-src;

  nativeBuildInputs = [
    makeWrapper
  ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/asus-fan-control
    mkdir -p $out/lib/systemd/system
    mkdir -p $out/share/bash-completion/completions

    # Main script and data
    cp src/asus-fan-control $out/share/asus-fan-control/
    cp src/data/models $out/share/asus-fan-control/models
    chmod +x $out/share/asus-fan-control/asus-fan-control

    # Patch hardcoded paths in the script
    substituteInPlace $out/share/asus-fan-control/asus-fan-control \
      --replace "/usr/share/asus-fan-control" "$out/share/asus-fan-control"

    # Wrapper script with proper PATH
    makeWrapper $out/share/asus-fan-control/asus-fan-control $out/bin/asus-fan-control \
      --prefix PATH : ${
        lib.makeBinPath [
          dmidecode
          coreutils
          gnugrep
          gawk
          kmod
        ]
      }

    # Systemd service
    substitute .install/afc.service $out/lib/systemd/system/afc.service \
      --replace "/usr/local/bin/asus-fan-control" "$out/bin/asus-fan-control"

    # Bash completion
    cp src/bash/afc-completion $out/share/bash-completion/completions/asus-fan-control
  '';

  meta = with lib; {
    description = "Fan control for ASUS devices running Linux";
    homepage = "https://github.com/dominiksalvet/asus-fan-control";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
