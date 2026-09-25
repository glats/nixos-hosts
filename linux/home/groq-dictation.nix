{ config, lib, ... }:

{
  programs.zsh.initContent = lib.mkAfter ''
    if [ -f "${config.sops.secrets."opencode/groq_api_key".path}" ]; then
      export GROQ_API_KEY="$(cat ${config.sops.secrets."opencode/groq_api_key".path})"
    fi
  '';
}
