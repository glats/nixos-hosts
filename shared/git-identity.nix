rec {
  signingKeyFallback = "=unavailable-signing-key";

  mkCredential = gh: account: {
    "https://github.com".helper = [
      ""
      "!f() { test \"$1\" = get || exit 0; t=$(${gh}/bin/gh auth token -h github.com -u ${account}) || exit 0; echo username=${account}; echo \"password=$t\"; }; f"
    ];
  };

  mkCredentialFromFile = gh: accountFile: {
    "https://github.com".helper = [
      ""
      "!f() { test \"$1\" = get || exit 0; account=$(cat ${builtins.toJSON accountFile} 2>/dev/null) || exit 0; test -n \"$account\" || exit 0; t=$(${gh}/bin/gh auth token -h github.com -u \"$account\") || exit 0; printf 'username=%s\\npassword=%s\\n' \"$account\" \"$t\"; }; f"
    ];
  };

  mkSigningIdentity =
    {
      gpgProgram,
      guardProgram,
      entries,
    }:
    ''
      for ((i = 0; i < 50; i++)); do
        _signing_ready=1
        for _fingerprint_file in ${
          builtins.concatStringsSep " " (map (entry: "\"${entry.fingerprint}\"") entries)
        }; do
          if [ ! -f "$_fingerprint_file" ]; then
            _signing_ready=0
          fi
        done
        if [ "$_signing_ready" = 1 ]; then
          break
        fi
        sleep 0.2
      done

      _write_signing_key() {
        _scope="$1"
        _fingerprint_file="$2"
        _out_file="$HOME/.config/git/signing-$_scope"

        _fingerprint=""
        if [ -f "$_fingerprint_file" ]; then
          _fingerprint="$(tr -d '\n' < "$_fingerprint_file" 2>/dev/null || true)"
        fi
        if [[ ! "$_fingerprint" =~ ^([[:xdigit:]]{8}|[[:xdigit:]]{16}|[[:xdigit:]]{40})$ ]]; then
          _fingerprint=""
        fi

        mkdir -p "$(dirname "$_out_file")"
        if [ -n "$_fingerprint" ]; then
          printf "[user]\n    signingKey = %s\n[gpg]\n    program = %s\n[gpg \"openpgp\"]\n    program = %s\n" \
            "$_fingerprint" "${gpgProgram}" "${gpgProgram}" > "$_out_file"
        else
          printf "[user]\n    signingKey = %s\n[gpg]\n    program = %s\n[gpg \"openpgp\"]\n    program = %s\n" \
            "${signingKeyFallback}" "${guardProgram}" "${guardProgram}" > "$_out_file"
        fi
      }

      ${builtins.concatStringsSep "\n" (
        map (entry: ''_write_signing_key "${entry.scope}" "${entry.fingerprint}"'') entries
      )}
    '';
}
