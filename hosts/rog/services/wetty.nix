{ config, pkgs, ... }:

{
  # Wetty - Web Terminal
  # Datos en /srv/glats/wetty/
  # Actualizado a imagen oficial wettyoss/wetty (butlerx/wetty está deprecada)
  virtualisation.oci-containers.containers.wetty = {
    image = "wettyoss/wetty:latest";
    autoStart = true;

    ports = [
      "9004:3000"
    ];

    volumes = [
      "/srv/glats/wetty/ssh:/root/.ssh"
    ];

    # Usar comando directo con flags nuevos (formato wettyoss)
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
