{ config, lib, pkgs, ... }:
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
        local cmd="''${1:-switch}"
        if [[ "$(uname)" == "Darwin" ]]; then
          sudo darwin-rebuild switch --flake "$NIXOS_REPO#$(hostname)"
        else
          nixos-build "$cmd"
        fi
      }

      nix-upgrade() {
        nix flake update --flake "$NIXOS_REPO"
        if [[ "$(uname)" == "Darwin" ]]; then
          sudo darwin-rebuild switch --flake "$NIXOS_REPO#$(hostname)"
        fi
        home-manager switch --flake "$NIXOS_REPO#$(hostname)"
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

      ZSH_HIGHLIGHT_STYLES[comment]="fg=#${config.colorScheme.palette.base03}"
      ZSH_HIGHLIGHT_STYLES[alias]="fg=#${config.colorScheme.palette.base0B}"
      ZSH_HIGHLIGHT_STYLES[builtin]="fg=#${config.colorScheme.palette.base0B}"
      ZSH_HIGHLIGHT_STYLES[function]="fg=#${config.colorScheme.palette.base0B}"
      ZSH_HIGHLIGHT_STYLES[command]="fg=#${config.colorScheme.palette.base0B}"
      ZSH_HIGHLIGHT_STYLES[path]="fg=#${config.colorScheme.palette.base0C}"
      ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=#${config.colorScheme.palette.base0A}"
      ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=#${config.colorScheme.palette.base0A}"
      ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#${config.colorScheme.palette.base08}"
      ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=#${config.colorScheme.palette.base0E}"
      ZSH_HIGHLIGHT_STYLES[precommand]="fg=#${config.colorScheme.palette.base04}"
      ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=#${config.colorScheme.palette.base03}"
      ZSH_HIGHLIGHT_STYLES[globbing]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=#${config.colorScheme.palette.base0D}"
      ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=#${config.colorScheme.palette.base04}"
      ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=#${config.colorScheme.palette.base04}"
      ZSH_HIGHLIGHT_STYLES[redirection]="fg=#${config.colorScheme.palette.base09}"
    '';
  };
}
