{ pkgs, homeManager }:
let
  sources = [
    "rog"
    "t14"
    "thinkcentre"
    "samsung"
    "macm5"
  ];
  configurations = map (
    source:
    let
      home = homeManager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          hostName = source;
          host = source;
        };
        modules = [
          (if source == "macm5" then ../../darwin/home/ssh.nix else ../../linux/home/ssh.nix)
          {
            home.username = if source == "macm5" then "juan" else "glats";
            home.homeDirectory = if source == "macm5" then "/Users/juan" else "/home/glats";
            home.stateVersion = "25.05";
            programs.ssh.settings."*" = {
              BatchMode = true;
              PasswordAuthentication = false;
              PreferredAuthentications = "publickey";
              ControlMaster = "auto";
              ControlPath = "/nonexistent/shared-ssh-control";
            };
          }
        ];
      };
    in
    pkgs.writeText "${source}-ssh-config" home.config.home.file.".ssh/config".text
  ) sources;
in
pkgs.runCommand "ssh-work-aliases-check"
  {
    nativeBuildInputs = [
      pkgs.openssh
      pkgs.python3
    ];
  }
  ''
    python3 ${./test.py} ${pkgs.lib.escapeShellArgs (map toString configurations)}
    touch $out
  ''
