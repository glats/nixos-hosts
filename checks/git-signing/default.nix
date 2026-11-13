{ pkgs, inputs }:

let
  repo = builtins.path { path = ../..; };

  # The test used to evaluate this configuration with nix eval at run time.
  # A check runs inside a Nix build, where the store is read-only and the
  # store database is not readable, so that evaluation cannot happen there.
  # The configuration is evaluated here instead and handed to the test as
  # JSON. The synthetic home is a placeholder: the test rewrites it to the
  # home it uses.
  syntheticHome = "/tmp/nixos-git-signing-synthetic-home";

  lib = inputs.nixpkgs.lib;
  hm = import (inputs.home-manager.outPath + "/modules");
  sopsHm = import (inputs.sops-nix.outPath + "/modules/home-manager/sops.nix");

  evaluationPkgs = pkgs // {
    writeText = name: text: builtins.toFile name text;
  };

  evaluate =
    platform:
    let
      configuration = { ... }: {
        imports = [
          sopsHm
          (import (repo + "/${platform}/home/git.nix"))
          (import (repo + "/shared/sops.nix"))
        ];
        home.username = "tester";
        home.homeDirectory = syntheticHome;
        home.stateVersion = "24.05";
        xdg.configHome = syntheticHome + "/.config";
      };
      cfg =
        (hm {
          inherit configuration pkgs;
          extraSpecialArgs = {
            githubUser = null;
          };
        }).config;
    in
    {
      config = cfg.xdg.configFile."git/config".text;
      activation = cfg.home.activation.writeGitIdentity.data;
      includes = cfg.programs.git.includes;
      includeFiles = map (entry: {
        inherit (entry) condition path;
        ini = if entry.contents == { } then null else lib.generators.toGitINI entry.contents;
      }) cfg.programs.git.includes;
      settings = cfg.programs.git.settings;
      signingKey = cfg.programs.git.signing.key;
      signByDefault = cfg.programs.git.signing.signByDefault;
      templates = builtins.mapAttrs (_: value: { inherit (value) content path; }) cfg.sops.templates;
      placeholders = {
        personal = cfg.sops.placeholder."github/personal_gpg_fingerprint";
        work = cfg.sops.placeholder."github/work_gpg_fingerprint";
      };
    };

  payload = pkgs.writeText "git-signing-payload.json" (
    builtins.toJSON {
      inherit syntheticHome;
      linux = evaluate "linux";
      darwin = evaluate "darwin";
    }
  );
in
pkgs.runCommand "git-signing-check"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.git
    ];
  }
  ''
    export GIT_SIGNING_PAYLOAD="${payload}"

    cp -r ${repo} repo
    python3 repo/checks/git-signing/test.py

    touch $out
  ''
