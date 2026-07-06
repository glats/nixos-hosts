{ config, pkgs, lib, ... }:
{
  home.packages = [ pkgs.nixos-scripts ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    prezto = {
      enable = true;
      pmodules = [
        "environment"
        "terminal"
        "editor"
        "history"
        "directory"
        "spectrum"
        "utility"
        "completion"
        "history-substring-search"
        "ssh"
        "syntax-highlighting"
        "git"
        "fasd"
        "autosuggestions"
        "prompt"
      ];
      prompt.theme = "suse";
    };

    shellAliases = {
      spf = "superfile";
    };

    sessionVariables = {
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    };

    initContent = lib.mkAfter ''
      # Activate mise (tool version manager) for zsh so shims resolve.
      MISE_BIN="${pkgs.mise}/bin/mise"
      if [ ! -x "$MISE_BIN" ] && command -v mise >/dev/null 2>&1; then
        MISE_BIN="$(command -v mise)"
      fi
      if [ -x "$MISE_BIN" ]; then
        export PATH="$HOME/.local/share/mise/shims:$PATH"
        eval "$("$MISE_BIN" activate zsh)"
      fi

      COLIMA_SOCKET="$HOME/.colima/default/docker.sock"
      if [ -S "$COLIMA_SOCKET" ]; then
        export DOCKER_HOST="unix://$COLIMA_SOCKET"
        export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="$COLIMA_SOCKET"
        export DOCKER_CONTEXT=colima
        export TESTCONTAINERS_RYUK_DISABLED=true
      fi

      # Prezto options
      zstyle ':prezto:*:*' color 'yes'
      zstyle ':prezto:module:editor' key-bindings 'emacs'
      zstyle ':prezto:module:terminal' auto-title 'yes'

      if [ -x "$MISE_BIN" ]; then
        "$MISE_BIN" install >/dev/null 2>&1 || true
        "$MISE_BIN" reshim >/dev/null 2>&1 || true
      fi

      path=(
        /etc/profiles/per-user/jcuzmar/bin
        /run/current-system/sw/bin
        /nix/var/nix/profiles/default/bin
        $HOME/.nix-profile/bin
        $HOME/.local/share/mise/shims
        ''${path[@]}
      )
      export PATH
    '';
  };
}
