{
  personal = {
    signingKey = "CFD6C7FED46F6870BE13CE87D39580F75062BEFC";
  };
  work = {
    signingKey = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
  };

  # Force the given `gh` account active before resolving git credentials, so
  # pushes in that gitdir work regardless of gh's global active-account state.
  mkCredentialHelper =
    gh: account:
    "!f() { ${gh}/bin/gh auth switch -h github.com -u ${account} 2>/dev/null; exec ${gh}/bin/gh auth git-credential \"$@\"; }; f";
}
