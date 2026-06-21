{ config
, lib
, pkgs
, ...
}:

{
  home.packages = [ pkgs.nixos-scripts ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
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
        "prompt"
        "syntax-highlighting"
        "history-substring-search"
        "autosuggestions"
        "ssh"
        "git"
      ];
      prompt.theme = "suse";
      editor = {
        keymap = "emacs";
        dotExpansion = true;
      };
    };
    shellAliases = {
      la = "ls -la";
      ".." = "cd ..";
      vim = "nvim";
      vi = "nvim";
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
      v = "nvim";
      ls = "ls --color=auto";
      ll = "ls -la";
      # Worktree aliases (new names are clearer)
      "wt-done" = "finish-work";
      "wt-discard" = "abort-work";

      # NixOS build shortcuts
      nrs = "nixos-build switch";
      nrt = "nixos-build test";
      nrb = "nixos-build boot";
      nrd = "nixos-build dry";
      hm = "home-manager";
      hmg = "home-manager generations";
      nfu = "nixos-build upgrade";
      ngc = "nix-collect-garbage";
      ngd = "nix-collect-garbage --delete-old";
      ncf = "cd ~/.nixos";
    };

    sessionVariables = {
      VISUAL = "nvim";
      EDITOR = "nvim";
      LESS = "-g -i -M -R -S -w -X -z4";
      DOTNET_ROOT = "${pkgs.dotnet-sdk_8}/share/dotnet";
      PATH = "$HOME/.nixos/bin:$PATH";
    };

    initContent = ''
      gitNewBranchFeature() { git checkout -b feature/$1 }
      gitNewBranchBugfix() { git checkout -b bugfix/$1 }
      gitNewBranchHotfix() { git checkout -b hotfix/$1 }

      function gaa { git add -A :/ "$@" }

      function gpo { git push origin "$(git branch --show-current)" "$@" }

      function glog {
        git log --topo-order --pretty='format:%C(auto)%h%d %s %C(8)%cr %C(bold blue)%an' "$@"
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

      code-work() {
        local repo_root="${config.home.homeDirectory}/.nixos"
        local worktree_name="''${1:-}"
        
        # Create worktree
        if [[ -n "$worktree_name" ]]; then
          "$repo_root/bin/work-flow" start "$worktree_name"
        else
          "$repo_root/bin/work-flow" start
          worktree_name=$(git -C "$repo_root" worktree list --porcelain 2>/dev/null | \
            grep "worktree $repo_root/.worktrees/" | tail -1 | sed "s|worktree $repo_root/.worktrees/||")
        fi
        
        # Enter worktree and open opencode
        local worktree_path="$repo_root/.worktrees/$worktree_name"
        cd "$worktree_path"
        opencode
        
        echo ""
        echo "> Staying in worktree: $worktree_name"
        echo "> Run 'finish-work' to save or 'abort-work' to discard"
      }

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
