{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "8192";
    };
    loadModels = [
      "qwen2.5:3b"
      "qwen2.5-coder:1.5b"
    ];
  };
}
