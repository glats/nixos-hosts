{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.system.primaryUser;
  apps = pkgs.buildEnv {
    name = "applications";
    paths = config.environment.systemPackages ++ config.users.users.${user}.packages;
    pathsToLink = [ "/Applications" ];
  };
in
{
  system.activationScripts.applications.text = lib.mkForce ''
    echo "copying Nix apps into /Applications..." >&2

    manifest='/Library/Application Support/nix-darwin/applications'
    mkdir -p "$(dirname "$manifest")"
    touch "$manifest"
    next="$(mktemp)"

    for src in ${apps}/Applications/*.app; do
      [ -e "$src" ] || continue
      name="$(basename "$src")"
      dest="/Applications/$name"
      if [ -e "$dest" ] && ! grep -qxF "$name" "$manifest"; then
        echo "warning: $dest exists and is not managed by Nix, skipping" >&2
        continue
      fi
      if ${lib.getExe pkgs.rsync} --checksum --copy-unsafe-links --archive --delete \
        --chmod=-w --no-group --no-owner "$src/" "$dest"; then
        echo "$name" >> "$next"
      else
        echo "warning: failed to copy $name (grant App Management to your terminal)" >&2
        grep -qxF "$name" "$manifest" && echo "$name" >> "$next"
      fi
    done

    while IFS= read -r name; do
      case "$name" in */* | .* | "") continue ;; *.app) ;; *) continue ;; esac
      if ! grep -qxF "$name" "$next" && [ -e "/Applications/$name" ]; then
        chmod -R u+w "/Applications/$name" 2>/dev/null || true
        rm -rf "/Applications/$name" || echo "warning: failed to remove /Applications/$name" >&2
      fi
    done < "$manifest"
    mv "$next" "$manifest"
    chmod 644 "$manifest"

    for old in '/Applications/Nix Apps' ~${user}/Applications/Nix-Apps; do
      if [ -e "$old" ]; then
        chmod -R u+w "$old" 2>/dev/null || true
        rm -rf "$old" || echo "warning: failed to remove $old" >&2
      fi
    done
  '';
}
