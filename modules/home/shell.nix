{ config, lib, pkgs, ... }:

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
      glog = "git log --topo-order --pretty=format:%C\(auto\)%h%d %s %C\(8\)%cr %C\(bold blue\)%an";
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
      oc = "opencode --log-level DEBUG --print-logs 2> ~/.local/share/opencode/logs/opencode-$(date +%Y%m%d-%H%M%S).log";
    };

    sessionVariables = {
      VISUAL = "nvim";
      EDITOR = "nvim";
      LESS = "-g -i -M -R -S -w -X -z4";
      DOTNET_ROOT = "${pkgs.dotnet-sdk_8}/share/dotnet";
      PATH = "$HOME/.nixos/bin:$PATH";
    };

    initContent = ''
      mkdir -p ~/.local/share/opencode/logs

      gitNewBranchFeature() { git checkout -b feature/$1 }
      gitNewBranchBugfix() { git checkout -b bugfix/$1 }
      gitNewBranchHotfix() { git checkout -b hotfix/$1 }

      gaa() { git add -A :/ "$@" }

      gpo() { git push origin "$(git branch --show-current)" "$@" }

      code-work() {
        local repo_root="/home/glats/.nixos"
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
