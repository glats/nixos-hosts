{ config, pkgs, ... }:

{
  # Code-Server - VS Code in Browser (Nativo)
  # Datos en /srv/glats/code/
  services.code-server = {
    enable = true;

    port = 9008;
    host = "127.0.0.1";
    user = "glats";

    extraArguments = [
      "--disable-telemetry"
    ];

    extraEnvironment = {
      EXTENSIONS_GALLERY = ''{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl":"https://vscode.blob.core.windows.net/gallery/index","itemUrl":"https://marketplace.visualstudio.com/items","controlUrl":"","recommendationsUrl":""}'';
    };
  };

  # Bind mounts para los datos de code-server
  systemd.services.code-server.serviceConfig = {
    BindPaths = [
      "/srv/glats/code/project:/home/glats/project"
      "/srv/glats/code/.config:/home/glats/.config/code-server"
      "/home/glats/.ssh:/home/glats/.ssh"
    ];
  };
}
