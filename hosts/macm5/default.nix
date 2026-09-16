# macOS host configuration for macm5 (Apple Silicon).
# Imports the darwin base profile (system modules) and retains only
# per-host concerns: nix-homebrew, home-manager, users, environment,
# and service enablements.
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

  # Determinate Nix owns /etc/ssl/certs/ca-certificates.crt, making
  # nix-darwin's security.pki.certificateFiles a no-op. Build a combined
  # Mozilla + Netskope corporate CA bundle and point NIX_SSL_CERT_FILE at it
  # so Nix-built programs (curl, git, nvim-treesitter) verify TLS behind
  # the corporate MITM proxy.
  #
  # The Netskope root CA is extracted from Apple SecTrust during the build
  # phase — the cert never lives in the repo.
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
    # Flattened from modules/darwin/profiles/base.nix
    ../../darwin/system/nix.nix
    ../../darwin/system/cachix.nix
    ../../darwin/system/homebrew.nix
    ../../darwin/system/settings.nix
    ../../darwin/system/mise.nix
    ../../darwin/system/zsh.nix
    ../../darwin/services/wsdd.nix
    ../../darwin/system/sing-box-link.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.sops-nix.darwinModules.sops
  ];

  # Keep corporate EDR traffic direct if the private link is unavailable.
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
      home.opencode.activeProviderName = "anthropic-opencode-free";
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
      # MacOSX27.0.sdk has a broken .tbd (tapi error: malformed file).
      # Force 26.5 until Apple fixes the SDK or CLI tools are updated.
      SDKROOT = "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk";
    };
    systemPackages = with pkgs; [
      git
      nixos-scripts
    ];
    # Intel uses /usr/local; Apple Silicon uses /opt/homebrew.
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
}
