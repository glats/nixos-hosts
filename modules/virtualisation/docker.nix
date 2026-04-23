{ ... }:

{
  virtualisation.docker.enable = true;

  # Use docker as the backend for virtualisation.oci-containers.
  # Podman's netavark/aardvark-dns has a race during shutdown.target where
  # pre-stop hooks try to start new transient scopes — systemd rejects them
  # as destructive, containers fail, and the hardware watchdog may not
  # disarm. Docker avoids this code path entirely.
  virtualisation.oci-containers.backend = "docker";
}
