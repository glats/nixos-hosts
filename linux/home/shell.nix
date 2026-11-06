{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = [
    pkgs.nixos-scripts
    pkgs.qrencode
  ];

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
      ls = "ls --color=auto";

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
      if [[ -o interactive && -o login && -t 0 && -t 1 \
            && -n "''${SSH_CONNECTION:-}" && -n "''${SSH_TTY:-}" \
            && -z "''${SSH_ORIGINAL_COMMAND:-}" \
            && "''${PINENTRY_USER_DATA:-}" != opencode ]]; then
        () {
          setopt localtraps
          trap ':' INT
          ${pkgs.nixos-scripts}/bin/ssh-keyring-unlock || true
        }
      fi

      code-work() {
        case "''${1:-}" in
          new|check|ready|status|merge|clean|abandon|recover-lock|managed)
            command code-work "$@"
            ;;
          --done|--abort|--list|--prune|--help|-h)
            command code-work "$@"
            ;;
          "")
            command code-work --help
            ;;
          *)
            local wt_name="$1"
            command code-work "$wt_name" || return
            local repo_root
            repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || repo_root=""
            if [[ -n "$repo_root" && -d "$repo_root/.worktrees/$wt_name" ]]; then
              cd "$repo_root/.worktrees/$wt_name"
              echo ""
              echo "> Worktree ready. Start your preferred assistant here."
              echo "> Run 'code-work --done $wt_name' when you finish."
              echo "> Run 'code-work --abort $wt_name' to discard everything"
            fi
            ;;
        esac
      }
    '';
  };
}
