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
      ls = "ls --color=auto";
      ll = "ls -la";
      "wt-done" = "finish-work";
      "wt-discard" = "abort-work";

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

    initContent = lib.mkAfter ''
      code-work() {
        local repo_root="${config.home.homeDirectory}/.nixos"
        local worktree_name="''${1:-}"

        if [[ -n "$worktree_name" ]]; then
          "$repo_root/bin/work-flow" start "$worktree_name"
        else
          "$repo_root/bin/work-flow" start
          worktree_name=$(git -C "$repo_root" worktree list --porcelain 2>/dev/null | \
            grep "worktree $repo_root/.worktrees/" | tail -1 | sed "s|worktree $repo_root/.worktrees/||")
        fi

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
