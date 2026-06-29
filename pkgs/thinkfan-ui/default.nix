# thinkfan-ui
# PyQt6 GUI for manual ThinkPad fan control.
# Writes to /proc/acpi/ibm/fan (mutually exclusive with services.thinkfan).
# Source: https://github.com/zocker-160/thinkfan-ui
{ lib
, stdenv
, makeWrapper
, wrapQtAppsHook
, python3
, qtbase
, hicolor-icon-theme
, lm_sensors
, thinkfan-ui-src
,
}:

let
  # Build a Python interpreter with PyQt6 baked into site-packages.
  # This is the standard nixpkgs pattern for Python GUI apps and avoids
  # the need to set PYTHONPATH at runtime.
  pythonEnv = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenv.mkDerivation {
  pname = "thinkfan-ui";
  version = thinkfan-ui-src.rev or "unstable";

  src = thinkfan-ui-src;

  nativeBuildInputs = [
    makeWrapper
    wrapQtAppsHook
  ];

  # qtbase must be in buildInputs so wrapQtAppsHook can resolve
  # `qtPluginPrefix` and set QT_PLUGIN_PATH for PyQt6 to discover the
  # xcb/wayland platform plugins.
  # hicolor-icon-theme provides share/icons/hicolor/index.theme so
  # QIcon.fromTheme("thinkfan-ui") can resolve the SVG icon at runtime.
  buildInputs = [ qtbase hicolor-icon-theme ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Python source tree (main.py, QSingleApplication.py, ui/)
    mkdir -p $out/share/thinkfan-ui
    cp -r src/* $out/share/thinkfan-ui/

    # Desktop file (from upstream linux_packaging/)
    install -Dm644 linux_packaging/thinkfan-ui.desktop \
      $out/share/applications/thinkfan-ui.desktop

    # SVG icon (from upstream linux_packaging/, installed into hicolor theme
    # so Freedesktop icon lookup finds it without any theme-specific config)
    install -Dm644 linux_packaging/thinkfan-ui.svg \
      $out/share/icons/hicolor/scalable/apps/thinkfan-ui.svg

    # Wrapper: replace the upstream /opt/thinkfan-ui shim with a Nix-relative
    # launcher. pythonEnv has PyQt6 baked in. PATH gets `sensors` from
    # lm_sensors (CPU temp reading) and `pkexec` from polkit (already in the
    # default PATH on NixOS, added here for explicitness).
    mkdir -p $out/bin
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/thinkfan-ui \
      --set PYTHONPATH "$out/share/thinkfan-ui" \
      --set QT_QPA_PLATFORM "wayland;xcb" \
      --prefix PATH : ${lib.makeBinPath [ lm_sensors ]} \
      --add-flags "$out/share/thinkfan-ui/main.py"

    runHook postInstall
  '';

  meta = with lib; {
    description = "PyQt6 GUI for manual ThinkPad fan control via /proc/acpi/ibm/fan";
    homepage = "https://github.com/zocker-160/thinkfan-ui";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "thinkfan-ui";
  };
}
