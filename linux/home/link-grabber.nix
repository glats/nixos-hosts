{ config, lib, ... }:

{
  home.activation.linkGrabberEnv = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
    env_file="$HOME/.config/link-grabber/env"
    secret_path=${config.sops.secrets."opencode/groq_api_key".path}

    if [ -f "$env_file" ] && [ -f "$secret_path" ]; then
      mkdir -p "$HOME/.config/link-grabber"
      chmod 700 "$HOME/.config/link-grabber"

      new_value=$(cat "$secret_path")
      old_value=$(grep '^GROQ_API_KEY=' "$env_file" | head -1 | cut -d= -f2-)

      tmp_file=$(mktemp "$env_file.XXXXXX")
      grep -v '^GROQ_API_KEY=' "$env_file" > "$tmp_file" || true
      printf 'GROQ_API_KEY=%s\n' "$new_value" >> "$tmp_file"
      chmod 600 "$tmp_file"
      mv "$tmp_file" "$env_file"

      if [ "$old_value" != "$new_value" ]; then
        systemctl --user try-restart link-grabber-bot.service >/dev/null 2>&1 || true
        echo "link-grabber: groq api key refreshed, service restarted"
      else
        echo "link-grabber: groq api key already current"
      fi
    fi
  '';
}
