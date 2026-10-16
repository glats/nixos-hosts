{
  pkgs,
  inputs,
  self,
  primaryUser,
  githubUser,
  javaVersion,
  lib,
  host,
  ...
}:

let
  mesh = import ../../shared/ssh/lan-mesh.nix { inherit lib; };

  corporateCaBundle = pkgs.runCommand "corporate-ca-bundle" { } ''
    mkdir -p $out/etc/ssl/certs

    # Extract Netskope root CA from macOS system keychain.
    /usr/bin/security find-certificate -a -c "certadmin" -p \
      /Library/Keychains/System.keychain > /tmp/netskope-root.crt

    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /tmp/netskope-root.crt \
      > $out/etc/ssl/certs/ca-bundle.crt

    rm /tmp/netskope-root.crt
  '';
in
{
  imports = [
    ../../darwin/system/nix.nix
    ../../darwin/system/cachix.nix
    ../../darwin/system/homebrew.nix
    ../../darwin/system/settings.nix
    ../../darwin/system/mise.nix
    ../../darwin/system/zsh.nix
    ../../darwin/services/wsdd.nix
    ../../darwin/system/sing-box-link.nix
    ../../darwin/system/ssh-relay.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.sops-nix.darwinModules.sops
  ];

  link.directCidrs = [ "163.116.0.0/16" ];

  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${primaryUser} = {
      imports = [
        ../../darwin/home
      ];
      home.stateVersion = "25.05";
      home.opencode.activeProviderName = "anthropic-medium";
    };
    extraSpecialArgs = {
      inherit
        inputs
        self
        primaryUser
        githubUser
        javaVersion
        host
        ;
    };
  };

  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = mesh.peerKeys host;
  };
  programs.ssh.knownHosts = mesh.knownHosts;
  environment = {
    variables = {
      DISPLAY = ":0";
      NIX_SSL_CERT_FILE = "${corporateCaBundle}/etc/ssl/certs/ca-bundle.crt";
      SDKROOT = "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk";
    };
    systemPackages = with pkgs; [
      git
      nixos-scripts
      (pkgs.callPackage ../../pkgs/findersearch { })
      (pkgs.callPackage ../../pkgs/tinkertool { })
    ];
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
  services.ssh-relay.enable = true;
}
