# pipewire-module-xrdp
# PipeWire sink and source modules for XRDP
# Source: https://github.com/neutrinolabs/pipewire-module-xrdp
{ lib
, stdenv
, autoreconfHook
, pkg-config
, automake
, autoconf
, libtool
, pipewire
, pipewire-module-xrdp-src
,
}:

stdenv.mkDerivation rec {
  pname = "pipewire-module-xrdp";
  version = "0.2";

  src = pipewire-module-xrdp-src;

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    automake
    autoconf
    libtool
  ];

  buildInputs = [
    pipewire
  ];

  configureFlags = [
    "--with-module-dir=${placeholder "out"}/lib/pipewire-0.3"
    "--with-xdgautostart-dir=${placeholder "out"}/etc/xdg"
  ];

  postInstall = ''
    mkdir -p $out/libexec/pipewire-module-xrdp
    install -Dm755 instfiles/load_pw_modules.sh \
      $out/libexec/pipewire-module-xrdp/load_pw_modules.sh
    install -Dm644 instfiles/pipewire-xrdp.desktop \
      $out/etc/xdg/autostart/pipewire-xrdp.desktop

    cat > $out/libexec/pipewire-module-xrdp/load_pw_modules-wrapper.sh <<EOF
    #!/bin/sh

    PIPEWIRE_MODULE_DIR="\''${PIPEWIRE_MODULE_DIR:+\''${PIPEWIRE_MODULE_DIR}:}$out/lib/pipewire-0.3:${pipewire}/lib/pipewire-0.3"
    export PIPEWIRE_MODULE_DIR

    if [ -n "\''${XRDP_SESSION:-}" ]; then
      if [ -z "\''${XRDP_SOCKET_PATH:-}" ]; then
        XRDP_SOCKET_PATH="/var/run/xrdp/$(id -u)"
      fi
      if [ -n "\''${DISPLAY:-}" ]; then
        display_num="\''${DISPLAY#*:}"
        display_num="\''${display_num%%.*}"
        if [ -n "$display_num" ]; then
          : "\''${XRDP_PULSE_SINK_SOCKET:=xrdp_chansrv_audio_out_socket_"$display_num"}"
          : "\''${XRDP_PULSE_SOURCE_SOCKET:=xrdp_chansrv_audio_in_socket_"$display_num"}"
        fi
      fi
      export XRDP_SOCKET_PATH XRDP_PULSE_SINK_SOCKET XRDP_PULSE_SOURCE_SOCKET
    fi

    exec $out/libexec/pipewire-module-xrdp/load_pw_modules.sh "$@"
    EOF
    chmod +x $out/libexec/pipewire-module-xrdp/load_pw_modules-wrapper.sh

    substituteInPlace $out/etc/xdg/autostart/pipewire-xrdp.desktop \
      --replace "Exec=$out/libexec/pipewire-module-xrdp/load_pw_modules.sh" \
                "Exec=$out/libexec/pipewire-module-xrdp/load_pw_modules-wrapper.sh"
  '';

  meta = with lib; {
    description = "PipeWire sink and source modules for XRDP";
    homepage = "https://github.com/neutrinolabs/pipewire-module-xrdp";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
