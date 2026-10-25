let
  flake = builtins.getFlake ("path:" + toString ../.);
  pkgs = flake.nixosConfigurations.rog.pkgs;
  scanner = builtins.head (
    builtins.filter (
      package: (package.pname or "") == "simple-scan"
    ) flake.nixosConfigurations.rog.config.environment.systemPackages
  );
  darkProbe = pkgs.writeText "scanner-dark-preference.c" ''
    #include <adwaita.h>
    #include <stdio.h>

    int main(void) {
      adw_init();
      AdwStyleManager *style = adw_style_manager_get_default();
      gboolean supported = adw_style_manager_get_system_supports_color_schemes(style);
      gboolean dark = adw_style_manager_get_dark(style);
      printf("supports-color-schemes=%d dark=%d\n", supported, dark);
      return supported && dark ? 0 : 1;
    }
  '';
in
pkgs.runCommand "simple-scan-launcher-test"
  {
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.stdenv.cc
      pkgs.strace
      pkgs.xvfb-run
      pkgs.dbus
      pkgs.glib
    ];
    buildInputs = [ pkgs.libadwaita ];
  }
  ''
    mkdir -p "$TMPDIR/home" "$TMPDIR/config" "$TMPDIR/runtime"
    chmod 700 "$TMPDIR/runtime"
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"

    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      LD_LIBRARY_PATH=/test/preserved-library-path \
      strace -f -v -s 65536 -e trace=execve -o launcher.trace \
      ${scanner}/bin/simple-scan --help > wrapped-help.txt
    scannerConfig=$(sed -n 's/.*"SANE_CONFIG_DIR=\([^"]*\)".*/\1/p' launcher.trace | sort -u)
    test -n "$scannerConfig"
    if [ "$scannerConfig" = /etc/sane-config ]; then
      echo "Document Scanner still uses the global SANE backend list"
      exit 1
    fi
    test "$(cat "$scannerConfig/dll.conf")" = brother4
    test "$(ls -A "$scannerConfig")" = dll.conf
    printf 'SANE backends: %s\n' "$(cat "$scannerConfig/dll.conf")"
    grep -Fq 'LD_LIBRARY_PATH=/etc/sane-libs:/test/preserved-library-path' launcher.trace
    grep -Fq 'ADW_DISABLE_PORTAL=1' launcher.trace
    grep -Fxq 'Exec=simple-scan' ${scanner}/share/applications/org.gnome.SimpleScan.desktop
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      ${pkgs.simple-scan}/bin/simple-scan --help > original-help.txt
    diff -u original-help.txt wrapped-help.txt

    export GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}/glib-2.0/schemas
    export GSETTINGS_BACKEND=keyfile
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    cc ${darkProbe} $(pkg-config --cflags --libs libadwaita-1) -o dark-preference
    if dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- xvfb-run -a env -u ADW_DISABLE_PORTAL ./dark-preference; then
      echo "Expected the isolated session without a portal to lack a dark preference"
      exit 1
    fi
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- xvfb-run -a env ADW_DISABLE_PORTAL=1 ./dark-preference

    mkdir "$out"
    cp original-help.txt wrapped-help.txt "$out/"
  ''
