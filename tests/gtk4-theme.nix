let
  flake = builtins.getFlake ("path:" + toString ../.);
  hosts = [
    "rog"
    "thinkcentre"
    "t14"
  ];
  checkTheme =
    host: config:
    let
      css = config.xdg.configFile."gtk-4.0/gtk.css".text or "";
    in
    assert config.gtk.gtk4.theme == null;
    assert builtins.match ".*Materia.*" css == null;
    assert config.gtk.theme.name == "Materia-dark-compact";
    assert
      config.gtk.gtk3.extraConfig == (
        if host == "t14" then
          { }
        else
          {
            gtk-application-prefer-dark-theme = true;
          }
      );
    assert
      config.gtk.gtk4.extraConfig == (
        if host == "t14" then
          {
            gtk-interface-color-scheme = "dark";
          }
        else
          {
            gtk-application-prefer-dark-theme = true;
          }
      );
    assert config.gtk.iconTheme.name == "Papirus-Dark";
    assert config.qt.platformTheme.name == "gtk3";
    assert config.qt.style.name == "adwaita-dark";
    assert config.dconf.settings."org/gnome/desktop/interface".color-scheme == "prefer-dark";
    "passed";
  checkHost = host: {
    name = host;
    value = {
      standalone = checkTheme host flake.homeConfigurations.${host}.config;
      integrated = checkTheme host flake.nixosConfigurations.${host}.config.home-manager.users.glats;
    };
  };
in
builtins.listToAttrs (map checkHost hosts)
