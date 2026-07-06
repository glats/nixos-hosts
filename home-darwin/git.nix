{ pkgs
, config
, primaryUser
, lib
, ...
}:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    ignores = [ "**/.DS_STORE" ];
    settings = {
      user = {
        name = "placeholder";
        email = "placeholder";
      };

      github.user = primaryUser;
      init.defaultBranch = "main";
      core.editor = "nvim -u NONE";
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };

    # Sign work commits with work key by default
    signing = {
      key = identities.work.signingKey;
      signByDefault = true;
    };

    includes = [
      # Default: work identity via activation-written file
      { path = "~/.config/git/identity-work"; }
      # Personal identity in Personal directory
      {
        condition = "gitdir:~/Personal/**";
        path = "~/.config/git/identity-personal";
      }
    ]
    # Personal repos sign with personal key if set
    ++ lib.optional (identities.personal.signingKey != "") {
      condition = "gitdir:~/Personal/**";
      contents = {
        user.signingKey = identities.personal.signingKey;
        commit.gpgsign = true;
      };
    };
  };

  home.activation.writeGitIdentity = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _write_identity() {
      _mode="$1"
      _secrets_file="$2"
      _out_file="$HOME/.config/git/identity-$_mode"

      if [ ! -f "$_secrets_file" ]; then
        return 0  # skip silently if sops secrets not available
      fi

      mkdir -p "$(dirname "$_out_file")"
      _name="$(${pkgs.gawk}/bin/awk -F': ' '/^name:/ {gsub(/"/, ""); print $2; exit}' "$_secrets_file")"
      _email="$(${pkgs.gawk}/bin/awk -F': ' '/^email:/ {gsub(/"/, ""); print $2; exit}' "$_secrets_file")"
      printf "[user]\n    name = %s\n    email = %s\n" "$_name" "$_email" > "$_out_file"
    }
    _write_identity "work" "${config.sops.secrets."identities/work".path}"
    _write_identity "personal" "${config.sops.secrets."identities/personal".path}"
  '';
}
