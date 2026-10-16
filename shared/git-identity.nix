{
  personal = {
    signingKey = "CFD6C7FED46F6870BE13CE87D39580F75062BEFC";
  };
  work = {
    signingKey = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
  };

  mkCredential = gh: account: {
    "https://github.com".helper = [
      ""
      "!f() { test \"$1\" = get || exit 0; t=$(${gh}/bin/gh auth token -h github.com -u ${account}) || exit 0; echo username=${account}; echo \"password=$t\"; }; f"
    ];
  };
}
