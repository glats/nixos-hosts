{ config, pkgs, ... }:
{
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
      la = "ls -la";
      ".." = "cd ..";
      "nix-switch" = "sudo darwin-rebuild switch --flake \"$HOME/.config/nix#mact2\"";
      "nix-format" = "sh ~/.config/nix/scripts/format-nix.sh";
      "nix-config" = "cd ~/.config/nix";
      "home-switch" = "home-manager switch --flake \"$HOME/.config/nix#mact2\"";
      "nix-upgrade" =
        "nix flake update --flake \"$HOME/.config/nix\" && sudo darwin-rebuild switch --flake \"$HOME/.config/nix#mact2\" && home-manager switch --flake \"$HOME/.config/nix#mact2\"";
      vim = "nvim";
      vi = "nvim";
      gst = "git status";
      gsts = "git status --short";
      gd = "git diff";
      gcl = "git clone --recursive";
      gadd = "git add --all";
      ga = "git add";
      glog = "git log --topo-order --pretty='%C(auto)%h%d %s %C(8)%cr %C(bold blue)%an'";
      gl = "git pull";
      glr = "git pull --rebase";
      gp = "git push";
      gpo = "git push origin \"$(git rev-parse --abbrev-ref HEAD)\"";
      "gc!" = "gc --amend";
      "gcn!" = "gc! --no-edit";
      "gca!" = "gca --amend";
      "gcan!" = "gca! --no-edit";
      grb = "git rebase";
      grbc = "git rebase --continue";
      grba = "git rebase --abort";
      grbs = "git rebase --skip";
      grbi = "git rebase --interactive";
      gco = "git checkout";
      gcb = "git checkout -b";
      gnbf = "gitNewBranchFeature";
      gnbb = "gitNewBranchBugfix";
      gnbh = "gitNewBranchHotfix";
      front = "cd ~/Work/frontend/";
      back = "cd ~/Work/backend/";
      infra = "cd ~/Work/infra/";
      srv = "cd ~/Work/srv/";
      spf = "superfile";
    };

    # Extra prezto/zsh configuration and helper functions
    initContent = ''
          # Activate mise (tool version manager) for zsh so shims resolve.
          MISE_BIN="${pkgs.mise}/bin/mise"
          if [ ! -x "$MISE_BIN" ] && command -v mise >/dev/null 2>&1; then
            MISE_BIN="$(command -v mise)"
          fi
          if [ -x "$MISE_BIN" ]; then
            # Prepend shims early (activation handles PATH adjustments but ensure fallback)
            export PATH="$HOME/.local/share/mise/shims:$PATH"
            eval "$("$MISE_BIN" activate zsh)"
          fi

          # SOPS age key location for secrets management
          export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

          # Point Docker tooling to Colima's socket when it exists (needed for testcontainers).
          # Use shell expansion; avoid Nix interpolation.
          COLIMA_SOCKET="$HOME/.colima/default/docker.sock"
          if [ -S "$COLIMA_SOCKET" ]; then
            export DOCKER_HOST="unix://$COLIMA_SOCKET"
            export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="$COLIMA_SOCKET"
            export DOCKER_CONTEXT=colima
            export TESTCONTAINERS_RYUK_DISABLED=true
          fi

          # Git branch helpers
          gitNewBranchFeature() { git checkout -b feature/$1 }
          gitNewBranchBugfix() { git checkout -b bugfix/$1 }
          gitNewBranchHotfix() { git checkout -b hotfix/$1 }

          # 'gaa' needs parameters; implement as function instead of alias
          gaa() { git add -A :/ "$@" }

          # Prezto options (translated from provided block)
          zstyle ':prezto:*:*' color 'yes'
          zstyle ':prezto:module:editor' key-bindings 'emacs'
          zstyle ':prezto:module:terminal' auto-title 'yes'

          # Module load order is managed by Home Manager's pmodules

          # Keep current theme managed by HM (redhat); do not override here
          # zstyle ':prezto:module:prompt' theme 'powerlevel10k'

          # Misc examples kept from provided config (disabled by default)
          # zstyle ':prezto:module:history' histsize 10000
          # zstyle ':prezto:module:history' savehist 10000
      # Ensure global tools declared via activation are installed & shims current (non-blocking)
      if [ -x "$MISE_BIN" ]; then
        "$MISE_BIN" install >/dev/null 2>&1 || true
        "$MISE_BIN" reshim >/dev/null 2>&1 || true
      fi

      # Prepend nix-managed paths so they take priority over homebrew /usr/local/bin.
      # Prezto's zprofile prepends /opt/homebrew and /usr/local paths AFTER .zshenv,
      # so we must re-prepend nix paths here in .zshrc (initContent) to win.
      # 'typeset -gU path' (set by prezto) deduplicates, so no duplicate entries.
      path=(
        /etc/profiles/per-user/jcuzmar/bin
        /run/current-system/sw/bin
        /nix/var/nix/profiles/default/bin
        $HOME/.nix-profile/bin
        $HOME/.local/share/mise/shims
        ''${path[@]}
      )
      export PATH

      # Base16 syntax highlighting styles (explicit hex to avoid bold=bright issues)
      ZSH_HIGHLIGHT_STYLES[comment]="fg=#${config.colorScheme.palette.base03}"
      ZSH_HIGHLIGHT_STYLES[alias]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[builtin]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[function]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[command]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[path]="fg=#${config.colorScheme.palette.base0C}"
      ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=#${config.colorScheme.palette.base0B}"
      ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=#${config.colorScheme.palette.base0B}"
      ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#${config.colorScheme.palette.base08}"
      ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=#${config.colorScheme.palette.base0E}"
      ZSH_HIGHLIGHT_STYLES[precommand]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=#${config.colorScheme.palette.base0E}"
      ZSH_HIGHLIGHT_STYLES[globbing]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=#${config.colorScheme.palette.base0E}"
      ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=#${config.colorScheme.palette.base09}"
      ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=#${config.colorScheme.palette.base09}"
      ZSH_HIGHLIGHT_STYLES[redirection]="fg=#${config.colorScheme.palette.base09}"
    '';
  };
}
