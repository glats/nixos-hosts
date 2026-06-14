{
  config,
  lib,
  pkgs,
  ...
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
      ];
      prompt.theme = "off";
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
      gcl = "git clone --recursive";
      gadd = "git add --all";
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

      # Redefine worktree functions. Use the `function NAME` syntax because
      # zsh refuses to define a function with `name()` syntax when an alias
      # with the same name already exists (e.g. ga='git add' from the
      # oh-my-zsh git plugin loaded via zplug). The omarchy bash worktrees
      # file fails for the same reason, so we override ga/gd here.
      function ga {
        if [[ -z "$1" ]]; then
          echo "Usage: ga [branch name]"
          return 1
        fi
        local branch="$1"
        local base="$(basename "$PWD")"
        local wt_path="../''${base}--''${branch}"
        git worktree add -b "$branch" "$wt_path"
        mise trust "$wt_path" 2>/dev/null || true
        cd "$wt_path"
      }

      function gd {
        if command -v gum >/dev/null && gum confirm "Remove worktree and branch?"; then
          local cwd worktree root branch
          cwd="$(pwd)"
          worktree="$(basename "$cwd")"
          root="''${worktree%%--*}"
          branch="''${worktree#*--}"
          if [[ "$root" != "$worktree" ]]; then
            cd "../$root"
            git worktree remove "$cwd" --force || return 1
            git branch -D "$branch"
          fi
        fi
      }

      function gaa { git add -A :/ "$@" }

      gpo() { git push origin "$(git branch --show-current)" "$@" }

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

    '';
  };
}
