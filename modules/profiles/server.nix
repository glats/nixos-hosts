{
  imports = [
    ./desktop.nix

    # Services
    ../features/services/xrdp.nix
    ../features/services/github-mcp-server.nix

    # Networking
    ../networking/wol.nix

    # Virtualisation
    ../virtualisation/docker.nix
  ];
}
