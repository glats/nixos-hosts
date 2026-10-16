{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.wetty = {
    image = "wettyoss/wetty:latest";
    autoStart = true;

    ports = [
      "9004:3000"
    ];

    volumes = [
      "/srv/glats/wetty/ssh:/root/.ssh"
    ];

    cmd = [
      "--ssh-host"
      "172.17.0.1"
      "--ssh-port"
      "22"
      "--ssh-user"
      "glats"
      "--base"
      "/"
      "--title"
      "ROG Server TTY"
    ];

    extraOptions = [
      "--tty"
      "--cpus=0.5"
      "--memory=512m"
    ];
  };
}
