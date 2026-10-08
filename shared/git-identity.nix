{
  personal = {
    signingKey = "CFD6C7FED46F6870BE13CE87D39580F75062BEFC";
  };
  work = {
    signingKey = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
  };

  # Git `credential` section that pins GitHub auth to a specific `gh` account
  # for the including gitdir. It reads that account's token with
  # `gh auth token --user` instead of `gh auth switch`, so gh's global active
  # account is never mutated. Scoped to https://github.com so the token is
  # never offered to other hosts; the leading "" resets inherited helpers
  # (e.g. system osxkeychain) so a stale keychain entry cannot win.
  mkCredential = gh: account: {
    "https://github.com".helper = [
      ""
      "!f() { test \"$1\" = get || exit 0; t=$(${gh}/bin/gh auth token -h github.com -u ${account}) || exit 0; echo username=${account}; echo \"password=$t\"; }; f"
    ];
  };
}
