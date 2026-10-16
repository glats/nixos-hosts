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

      Example per-host override:
        { home.github.defaultAccount = "glats"; }
    '';
  };

  config = {
    home.activation.ghDefaultAccount = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        account = config.home.github.defaultAccount;
      in
      ''
        if [ -f "$HOME/.config/gh/hosts.yml" ] \
           && grep -qE "^[[:space:]]+${account}:" "$HOME/.config/gh/hosts.yml"; then
          ${pkgs.gh}/bin/gh auth switch --hostname github.com --user "${account}" >/dev/null 2>&1 || true
        fi
      ''
    );
  };
}
