{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.home.github.defaultAccount = lib.mkOption {
    type = lib.types.str;
    default = if pkgs.stdenv.hostPlatform.isDarwin then "jcuzmar-Falabella_FTC" else "glats";
    description = ''
      Existing github.com `gh` login selected as the active account
      after Home Manager activation. The default is the work account
      on Darwin hosts and the personal account on Linux hosts, so
      rog/t14/thinkcentre activate as `glats` and macm5 activates as
      `jcuzmar-Falabella_FTC`.

      This option is a host policy, not an authentication option. It
      only changes the active marker via `gh auth switch`; the
      `users:` map in `~/.config/gh/hosts.yml` and the keyring-backed
      tokens remain managed by `gh` and the user.

      Account selection is best-effort: activation continues with a warning
      if the command fails or exceeds five seconds, with a two-second
      forced-termination grace period. On Linux, activation only attempts the
      switch when a user session bus exists (so boot-time activation never
      waits on a locked keyring); a user service retries the switch every minute
      until the keyring is available, which may only happen at graphical login
      on hosts with lingering enabled.

      Example per-host override:
        { home.github.defaultAccount = "glats"; }
    '';
  };

  config =
    let
      account = config.home.github.defaultAccount;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      switchAccount = onFailure: ''
        if [ -f "$HOME/.config/gh/hosts.yml" ] \
           && grep -qE "^[[:space:]]+${account}:" "$HOME/.config/gh/hosts.yml"; then
          if ! ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=2s 5s \
            ${pkgs.gh}/bin/gh auth switch --hostname github.com --user "${account}" >/dev/null 2>&1; then
            ${onFailure}
          fi
        fi
      '';
      warn = ''echo "Warning: GitHub default account selection failed or timed out; continuing activation. Select the account manually after unlocking the keyring." >&2'';
      sessionGuard = ''
        if [ -e "''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/bus" ]; then
      '';
    in
    {
      home.activation.ghDefaultAccount = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        if isLinux then sessionGuard + switchAccount warn + "fi\n" else switchAccount warn
      );
    }
    // {
      systemd.user.services.gh-default-account = lib.mkIf isLinux {
        Unit = {
          Description = "Select the default GitHub CLI account once the keyring is available";
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScript "gh-default-account" (switchAccount "exit 1")}";
          Restart = "on-failure";
          RestartSec = "60s";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
