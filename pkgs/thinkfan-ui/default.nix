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
, lm_sensors
, thinkfan-ui-src
,
}:

let
  # Build a Python interpreter with PyQt6 baked into site-packages.
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

  buildInputs = [ qtbase ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Python source tree (main.py, QSingleApplication.py, ui/)
    mkdir -p $out/share/thinkfan-ui
    cp -r src/* $out/share/thinkfan-ui/

    # Install SVG icon for desktop file and tray patching
    install -Dm644 linux_packaging/thinkfan-ui.svg \
      $out/share/icons/thinkfan-ui.svg

    # Patch systray to use a direct icon path instead of QIcon.fromTheme().
    # QIcon.fromTheme("thinkfan-ui") relies on the hicolor icon theme
    # discovery mechanism, which is fragile on NixOS (multiple store paths,
    # missing caches, missing index.theme in the right directory).
    # A direct QIcon(path) bypasses the entire theme system.
    substituteInPlace $out/share/thinkfan-ui/ui/systray.py \
      --replace-fail \
        'QIcon.fromTheme("thinkfan-ui")' \
        'QIcon("'"$out"'/share/icons/thinkfan-ui.svg")'

    # Desktop file (from upstream linux_packaging/).  Use the direct icon
    # path so the .desktop file works without an icon theme.
    mkdir -p $out/share/applications
    sed "s|Icon=thinkfan-ui|Icon=$out/share/icons/thinkfan-ui.svg|" \
      linux_packaging/thinkfan-ui.desktop \
      > $out/share/applications/thinkfan-ui.desktop

    # Wrapper: pythonEnv has PyQt6 baked in. PATH gets `sensors` from
    # lm_sensors (CPU temp reading).
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
