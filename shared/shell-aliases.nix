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

      # tmux-resume: bounded-retry attach that lets Continuum's async
      # `@continuum-restore on` land before reporting a verdict. Continuum
      # remains the sole restore authority — this never calls Resurrect's
      # restore.sh and never creates a bootstrap session (no `new-session -A`).
      # See openspec/changes/tmux-restore-attach/design.md for the contract.
      tmux-resume() {
        command -v tmux >/dev/null 2>&1 || {
          echo "tmux-resume: tmux not found" >&2
          return 127
        }

        local tries=15 delay=0.2 i err errfile
        errfile="$(mktemp)"

        for ((i = 0; i < tries; i++)); do
          if tmux has-session 2>"$errfile"; then
            rm -f "$errfile"
            exec tmux attach
          fi
          err="$(cat "$errfile" 2>/dev/null)"
          # A real tmux error (not "no server"/"no session(s)") short-circuits
          # immediately instead of being masked as a restore-in-progress wait.
          if [[ -n "$err" && "$err" != *"no server"* && "$err" != *"no session"* ]]; then
            rm -f "$errfile"
            echo "$err" >&2
            return 1
          fi
          sleep "$delay"
        done
        rm -f "$errfile"

        local snapshot
        for snapshot in \
          "''${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/last" \
          "$HOME/.tmux/resurrect/last"; do
          if [[ -e "$snapshot" ]]; then
            echo "tmux-resume: restore did not finish within timeout" >&2
            return 1
          fi
        done

        echo "tmux-resume: no snapshot to restore" >&2
        return 1
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
