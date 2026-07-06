{
  imports = [
    ./desktop.nix

    # Services
    ../features/services/xrdp.nix
    ../features/services/github-mcp-server.nix
    ../features/services/github-token-check.nix

    # Networking
    ../networking/wol.nix

    # Virtualisation
    ../virtualisation/docker.nix
  ];
}
