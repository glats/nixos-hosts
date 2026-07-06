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
          --done|--abort)
            # Save repo root before script deletes the worktree
            local _main_root="$(git worktree list --porcelain 2>/dev/null | grep "^worktree " | head -1 | sed 's/^worktree //')"
            command code-work "$@"
            [[ -n "$_main_root" ]] && cd "$_main_root"
            ;;
          --list|--prune|--help|-h)
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
              opencode || true
              echo ""
              echo "> Run 'code-work --done' to save and cleanup"
              echo "> Run 'code-work --abort' to discard everything"
            fi
            ;;
        esac
      }

      if [ -f "${config.sops.secrets."github/personal_pat".path}" ]; then
        export GH_TOKEN="$(cat ${config.sops.secrets."github/personal_pat".path})"
        # Non-blocking check: warn if token expired (async + disown so it doesn't delay shell or show job notifications)
        ( ${pkgs.gh}/bin/gh auth status --active --hostname github.com >/dev/null 2>&1 || \
          echo "WARNING: GitHub token (personal) expired! Create new PAT and: sops edit secrets/shared/passwords.yaml && nixos-build switch" >&2
        ) &!
      fi
    '';
  };
}
