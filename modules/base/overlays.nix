{ self, inputs }:
final: prev:
let
  # Usar los inputs del flake en lugar de fetchgit/fetchFromGitHub hardcoded
  asus-fan-control-src = inputs.asus-fan-control-src;
  pipewire-module-xrdp-src = inputs.pipewire-module-xrdp-src;
in
{
  inherit (self.packages.${prev.stdenv.hostPlatform.system}) nixos-scripts gentle-ai engram gentle-ai-assets gentle-ai-assets-vanilla engram-assets engram-assets-vanilla opencode-npm-packages;

  asus-fan-control = final.stdenv.mkDerivation rec {
    pname = "asus-fan-control";
    version = inputs.asus-fan-control-src.rev or "unstable";
    src = asus-fan-control-src;

    nativeBuildInputs = with final; [
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
        --prefix PATH : ${final.lib.makeBinPath [ final.dmidecode final.coreutils final.gnugrep final.gawk final.kmod ]}

      # Systemd service
      substitute .install/afc.service $out/lib/systemd/system/afc.service \
        --replace "/usr/local/bin/asus-fan-control" "$out/bin/asus-fan-control"

      # Bash completion
      cp src/bash/afc-completion $out/share/bash-completion/completions/asus-fan-control
    '';

    meta = with final.lib; {
      description = "Fan control for ASUS devices running Linux";
      homepage = "https://github.com/dominiksalvet/asus-fan-control";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = [ ];
    };
  };

  libmateweather = prev.libmateweather.overrideAttrs (oldAttrs: {
    # Fix pointer offset bug in METAR parsing
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace libmateweather/weather-metar.c \
        --replace-fail 'p += WEATHER_LOCATION_CODE_LEN + 11;' 'p += WEATHER_LOCATION_CODE_LEN + 17;'
    '';
  });

  pipewire-module-xrdp = final.stdenv.mkDerivation rec {
    pname = "pipewire-module-xrdp";
    version = "0.2";
    src = pipewire-module-xrdp-src;

    nativeBuildInputs = with final; [
      autoreconfHook
      pkg-config
      automake
      autoconf
      libtool
    ];

    buildInputs = with final; [
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

      PIPEWIRE_MODULE_DIR="''${PIPEWIRE_MODULE_DIR:+''${PIPEWIRE_MODULE_DIR}:}$out/lib/pipewire-0.3:${final.pipewire}/lib/pipewire-0.3"
      export PIPEWIRE_MODULE_DIR

      if [ -n "''${XRDP_SESSION:-}" ]; then
        if [ -z "''${XRDP_SOCKET_PATH:-}" ]; then
          XRDP_SOCKET_PATH="/var/run/xrdp/$(id -u)"
        fi
        if [ -n "''${DISPLAY:-}" ]; then
          display_num="''${DISPLAY#*:}"
          display_num="''${display_num%%.*}"
          if [ -n "$display_num" ]; then
            : "''${XRDP_PULSE_SINK_SOCKET:=xrdp_chansrv_audio_out_socket_"$display_num"}"
            : "''${XRDP_PULSE_SOURCE_SOCKET:=xrdp_chansrv_audio_in_socket_"$display_num"}"
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

    meta = with final.lib; {
      description = "PipeWire sink and source modules for XRDP";
      homepage = "https://github.com/neutrinolabs/pipewire-module-xrdp";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = [ ];
    };
  };

  # Apply opencode PR #19328: fix(task): ignore invalid task_id when spawning subagents
  # https://github.com/anomalyco/opencode/pull/19328
  # Bug: Zod validation throws on malformed task_id before session creation fallback
  # Fix: validate task_id with safeParse before passing to Session.get()
  # Approach: sed substitution on the v1.14.30 source (not full file replacement)
  # The fix changes SessionID.make(taskID) to use SessionID.zod.safeParse() first
  # TODO: Remove once PR is merged into nixpkgs
  opencode = prev.opencode.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      sed -i 's/yield\* sessions\.get(SessionID\.make(taskID))\.pipe(Effect\.catchCause(() => Effect\.succeed(undefined)))/(() => { const p = SessionID.zod.safeParse(taskID); return p.success ? sessions.get(p.data).pipe(Effect.catchCause(() => Effect.succeed(undefined))) : Effect.succeed(undefined); })()/g' packages/opencode/src/tool/task.ts
    '';
  });
}
