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
      "wt-done" = "code-work --done";
      "wt-abort" = "code-work --abort";
      "wt-list" = "code-work --list";

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
        case "''${1:-}" in
          --done|--abort|--list|--prune|--help|-h)
            "''${HOME}/.nixos/bin/code-work" "$@"
            ;;
          "")
            "''${HOME}/.nixos/bin/code-work" --help
            ;;
          *)
            local wt_name="$1"
            "''${HOME}/.nixos/bin/code-work" "$wt_name" || return
            if [[ -d "''${HOME}/.nixos/.worktrees/$wt_name" ]]; then
              cd "''${HOME}/.nixos/.worktrees/$wt_name"
              opencode || true
              echo ""
              echo "> Run 'code-work --done' to save and cleanup"
              echo "> Run 'code-work --abort' to discard everything"
            fi
            ;;
        esac
      }

      if [ -f "${config.sops.secrets."github/pat".path}" ]; then
        export GH_TOKEN="$(cat ${config.sops.secrets."github/pat".path})"
      fi
    '';
  };
}
