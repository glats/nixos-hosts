{ config, lib, ... }:

{
  home.activation.linkGrabberEnv = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
    env_file="$HOME/.config/link-grabber/env"
    groq_secret=${config.sops.secrets."opencode/groq_api_key".path}
    telegram_secret=${config.sops.secrets."link_grabber/telegram_token".path}

    if [ -f "$env_file" ] && [ -f "$groq_secret" ] && [ -f "$telegram_secret" ]; then
      mkdir -p "$HOME/.config/link-grabber"
      chmod 700 "$HOME/.config/link-grabber"

      groq_new=$(cat "$groq_secret")
      telegram_new=$(cat "$telegram_secret")
      groq_old=$(grep '^GROQ_API_KEY=' "$env_file" | head -1 | cut -d= -f2-)
      telegram_old=$(grep '^TELEGRAM_TOKEN=' "$env_file" | head -1 | cut -d= -f2-)

      tmp_file=$(mktemp "$env_file.XXXXXX")
      grep -v -e '^GROQ_API_KEY=' -e '^TELEGRAM_TOKEN=' "$env_file" > "$tmp_file" || true
      printf 'GROQ_API_KEY=%s\n' "$groq_new" >> "$tmp_file"
      printf 'TELEGRAM_TOKEN=%s\n' "$telegram_new" >> "$tmp_file"
      chmod 600 "$tmp_file"
      mv "$tmp_file" "$env_file"

      if [ "$groq_old" != "$groq_new" ] || [ "$telegram_old" != "$telegram_new" ]; then
        systemctl --user try-restart link-grabber-bot.service >/dev/null 2>&1 || true
        echo "link-grabber: env refreshed"
      else
        echo "link-grabber: env already current"
      fi
    fi
  '';
}
