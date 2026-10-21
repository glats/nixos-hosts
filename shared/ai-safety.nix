{
  recursiveRmFlags = [
    "-r"
    "-R"
    "-rf"
    "-fr"
    "-Rf"
    "-fR"
    "-rfv"
    "-frv"
    "-rvf"
    "-vrf"
    "-Rfv"
    "--recursive"
  ];
  sudoRmFlags = [
    "-r"
    "-R"
    "-rf"
    "-fr"
    "-Rf"
    "-fR"
  ];
  protectedRmTargets = [
    "/"
    "~"
    "~/*"
    "?HOME"
    "?HOME/*"
    "?{HOME}"
    "??HOME?"
    "."
    "./"
    ".."
    "../"
  ];
  trailingRmTargets = [
    "/"
    "~"
    "?HOME"
  ];
  gitPrefixes = [
    "git "
    "git -C * "
  ];
  pushForceClusters = [
    "-uf"
    "-fu"
  ];
  remoteCommands = [
    "ssh"
    "scp"
    "sftp"
    "rsync"
  ];
  databaseClients = [
    "psql"
    "mysql"
    "mariadb"
    "sqlite3"
  ];
  destructiveSql = [
    "DROP TABLE"
    "DROP DATABASE"
    "DROP SCHEMA"
    "TRUNCATE"
    "drop table"
    "drop database"
    "drop schema"
    "truncate"
  ];
  sensitivePaths = [
    "*.env"
    "*.env.*"
    "**/.env"
    "**/.env.*"
    ".env_*"
    "*/.env_*"
    ".env-*"
    "*/.env-*"
    ".env/*"
    "*/.env/*"
    "secrets"
    "secrets/*"
    "**/secrets"
    "**/secrets/**"
    ".ssh"
    ".ssh/*"
    "**/.ssh"
    "**/.ssh/**"
    ".credentials"
    ".credentials/*"
    "**/.credentials"
    "**/.credentials/**"
    "**/Library/Keychains/**"
    ".aws/credentials"
    "**/.aws/credentials"
    ".config/gh/hosts.yml"
    "**/.config/gh/hosts.yml"
    ".config/gh/hosts.yaml"
    "**/.config/gh/hosts.yaml"
    "**/credentials.json"
    "*.pem"
    "**/*.pem"
    "*.key"
    "**/*.key"
    "*.p12"
    "*.pfx"
  ];
}
