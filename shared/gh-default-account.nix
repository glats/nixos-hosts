# Host-aware GitHub CLI account priority.
#
# Reasserts the preferred active `gh` account after Home Manager
# activation without replacing either stored GitHub account or
# affecting explicit MCP account selection.
#
# The platform-derived default is `glats` on Linux hosts and
# `jcuzmar-Falabella_FTC` on Darwin hosts, so all four current hosts
# (rog, t14, thinkcentre on Linux; mact2 on Darwin) receive the
# intended policy through their existing shared module lists. The
# option is overridable per host without duplicating the activation
# entry.
#
# IMPORTANT:
# - This module only changes the active-account selection. It does
#   NOT own, validate, or provision credentials. The `users:` map
#   in `~/.config/gh/hosts.yml`, OAuth tokens, and keyring entries
#   remain user- and `gh`-managed.
# - Each Home Manager activation reasserts the host policy. A
#   manual `gh auth switch` between activations persists only until
#   the next activation runs.
# - The `github-personal` and `github-work` MCP wrappers remain
#   authoritative; they resolve tokens through
#   `gh auth token --user <account>` and are independent of the
#   active account. Do not add `programs.gh.hosts`, fake hostnames,
#   or token/PAT management here.
{ config, lib, pkgs, ... }:

{
  options.home.github.defaultAccount = lib.mkOption {
    type = lib.types.str;
    default =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "jcuzmar-Falabella_FTC"
      else "glats";
    description = ''
      Existing github.com `gh` login selected as the active account
      after Home Manager activation. The default is the work account
      on Darwin hosts and the personal account on Linux hosts, so
      rog/t14/thinkcentre activate as `glats` and mact2 activates as
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
    # Reassert the configured active account after `writeBoundary`
    # (which includes `migrateGhAccounts`). The guard is filesystem
    # only: it inspects `~/.config/gh/hosts.yml` for the configured
    # user key and, if present, invokes the absolute
    # `${pkgs.gh}/bin/gh auth switch` with quoted arguments.
    #
    # The guard MUST NOT call `gh auth status` or `gh auth token`
    # because those commands resolve credentials and would touch the
    # keyring. Both the guard and the switch are non-fatal: missing
    # `hosts.yml` or missing target user becomes a successful no-op,
    # and a failed `gh auth switch` is suppressed with `|| true`. This
    # keeps first-run hosts (no `gh` logins yet) activating cleanly.
    home.activation.ghDefaultAccount = lib.hm.dag.entryAfter [ "writeBoundary" ]
      (
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
