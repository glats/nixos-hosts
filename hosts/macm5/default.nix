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
    ../../darwin/system/nix-cache-client.nix
    ../../darwin/system/homebrew.nix
    ../../darwin/system/settings.nix
    ../../darwin/system/mise.nix
    ../../darwin/system/zsh.nix
    ../../darwin/services/wsdd.nix
    ../../darwin/services/sunshine.nix
    ../../darwin/system/sing-box-link.nix
    ../../darwin/system/ssh-relay.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.sops-nix.darwinModules.sops
  ];

  link.directCidrs = [ "163.116.0.0/16" ];

  # Distrust for the eMudhra intermediate CA compromise (Oct 2026).
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];

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
      home.opencode.activeProviderName = "anthropic-copilot";
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
  services.sunshine = {
    enable = true;
    settings.global_prep_cmd =
      let
        displayplacer = "/opt/homebrew/bin/displayplacer";
        builtinMode =
          res:
          ''${displayplacer} "id:37D8832A-2D66-02CA-B9F7-8F30A301B230 res:${res} hz:120 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"'';
      in
      builtins.toJSON [
        {
          do = builtinMode "1352x878";
          undo = builtinMode "1800x1169";
          elevated = false;
        }
      ];
  };
  homebrew.brews = [ "displayplacer" ];
}
