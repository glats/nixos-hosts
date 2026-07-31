{ lib, pkgs, ... }:

let
  script = pkgs.writeScriptBin "webcam" ''
    #!/usr/bin/env bash
    set -euo pipefail

    RES="''${2:-1280x720}"

    if [ -n "$1" ]; then
      DEVICE="$1"
    else
      DEVICE=""
      for d in /dev/video[0-9]*; do
        [ -e "$d" ] || continue
        DEVICE="$d"
        break
      done
    fi

    if [ -z "$DEVICE" ] || [ ! -e "$DEVICE" ]; then
      echo "Error: no webcam device found"
      exit 1
    fi

    exec ${lib.getExe pkgs.mpv} --no-osc --no-osd-bar --really-quiet \
      --demuxer-lavf-format="video4linux2" \
      --demuxer-lavf-o="input_format=mjpeg,video_size=$RES,framerate=30" \
      "av://v4l2:$DEVICE"
  '';
in
{
  home.packages = [ script ];

  xdg.desktopEntries.webcam = {
    name = "Webcam";
    comment = "Open webcam video feed";
    exec = "${script}/bin/webcam";
    icon = "camera-web";
    terminal = true;
    categories = [ "AudioVideo" ];
  };
}
