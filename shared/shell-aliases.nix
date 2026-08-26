{ config
, lib
, pkgs
, ...
}:
{
  programs.zsh = {
    shellAliases = {
      la = "ls -la";
      ".." = "cd ..";
      vim = "nvim";
      vi = "nvim";
      v = "nvim";

      gst = "git status";
      gsts = "git status --short";
      gd = "git diff";
      gcl = "git clone --recursive";
      gadd = "git add --all";
      ga = "git add";
      gl = "git pull";
      glr = "git pull --rebase";
      gp = "git push";
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

      front = "cd ~/Work/frontend/";
      back = "cd ~/Work/backend/";
      infra = "cd ~/Work/infra/";
      srv = "cd ~/Work/srv/";

      ncf = "cd $NIXOS_REPO";
      spf = "superfile";
    };

    initContent = ''
      gitNewBranchFeature() { git checkout -b feature/$1 }
      gitNewBranchBugfix() { git checkout -b bugfix/$1 }
      gitNewBranchHotfix() { git checkout -b hotfix/$1 }

      gaa() { git add -A :/ "$@" }

      gpo() { git push origin "$(git branch --show-current)" "$@" }

      glog() {
        git log --topo-order --pretty='format:%C(auto)%h%d %s %C(8)%cr %C(bold blue)%an' "$@"
      }

      nix-switch() {
        nixos-build "''${1:-switch}"
      }

      nix-upgrade() {
        nixos-build upgrade
      }

      hms() {
        local flake="''${NIXOS_REPO:-/etc/nixos}"
        local host="$(hostname)"
        if [[ "$1" == "--help" || "$1" == "-h" ]]; then
          echo "Usage: hms"
          echo ""
          echo "Runs: home-manager switch --flake <flake>#<hostname>"
          echo ""
          echo "Flake path: $flake"
          echo "Host:       $host"
          return 0
        fi
        home-manager switch --flake "$flake#$host" "$@"
      }

      nix-format() {
        nix fmt -- "$NIXOS_REPO"
      }
    '';

    # Syntax highlighting styles via prezto's declarative option instead of
    # raw ZSH_HIGHLIGHT_STYLES assignments — the raw form ran before
    # zsh-syntax-highlighting loaded and failed with "invalid subscript
    # range". HM renders this as `zstyle ':prezto:module:syntax-highlighting'
    # styles ...`, applied by prezto AFTER the plugin loads.
    prezto.syntaxHighlighting.styles = {
      comment = "fg=#${config.colorScheme.palette.base03}";
      alias = "fg=#${config.colorScheme.palette.base0B}";
      builtin = "fg=#${config.colorScheme.palette.base0B}";
      function = "fg=#${config.colorScheme.palette.base0B}";
      command = "fg=#${config.colorScheme.palette.base0B}";
      path = "fg=#${config.colorScheme.palette.base0C}";
      single-quoted-argument = "fg=#${config.colorScheme.palette.base0A}";
      double-quoted-argument = "fg=#${config.colorScheme.palette.base0A}";
      unknown-token = "fg=#${config.colorScheme.palette.base08}";
      reserved-word = "fg=#${config.colorScheme.palette.base0E}";
      precommand = "fg=#${config.colorScheme.palette.base04}";
      commandseparator = "fg=#${config.colorScheme.palette.base03}";
      globbing = "fg=#${config.colorScheme.palette.base0D}";
      history-expansion = "fg=#${config.colorScheme.palette.base0D}";
      single-hyphen-option = "fg=#${config.colorScheme.palette.base09}";
      double-hyphen-option = "fg=#${config.colorScheme.palette.base09}";
      redirection = "fg=#${config.colorScheme.palette.base09}";
    };
  };
}
