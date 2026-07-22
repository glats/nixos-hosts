{ pkgs, ... }:
let
  # Google Cloud SDK with the GKE auth plugin component included.
  gdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      gke-gcloud-auth-plugin
    ]
  );
in
{
  home = {
    packages = with pkgs; [
      pandoc
      wkhtmltopdf
      curl
      git
      tmux
      htop
      tree
      nerd-fonts.caskaydia-cove
      defaultbrowser
      docker-compose
      lazydocker
      freerdp
      colima
      docker
      maven
      gradle
      micronaut
      nixfmt
      fastfetch
      wget
      jq
      lsd
      vscode
      gdk
      btop
      nix-index
      gnupg1
      pinentry_mac
      netcat
      sshfs-fuse
      protobuf
      plantuml
      lazygit
      mise
      speedtest-cli
      wireguard-go
      wireguard-tools
      bat
      gh
      wakeonlan
      glab
      yarn
      kubectl
      nodejs
      opencode
      uv
      ripgrep
      sops
      home-manager
      superfile
      ffmpeg
    ];
  };
}
