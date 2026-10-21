{ lib, ... }:

let
  safety = import ./ai-safety.nix;
  bash = pattern: "Bash(${pattern})";
  rmTargets = [
    "/"
    "~"
    "~/*"
    "$HOME"
    "$HOME/*"
    "."
    "./"
    ".."
    "../"
  ];
  recursiveRm =
    prefix: flags:
    lib.concatMap (
      flag:
      map (target: "${prefix}rm ${flag} ${target}") rmTargets
      ++ map (target: "${prefix}rm ${flag} * ${target}") [
        "/"
        "~"
        "$HOME"
      ]
    ) flags;
  gitDeny =
    git:
    [
      "${git}reset --hard"
      "${git}reset --hard *"
      "${git}reset * --hard*"
      "${git}clean -f*"
      "${git}clean * -f*"
      "${git}push --force*"
      "${git}push * --force*"
      "${git}push -f*"
      "${git}push * -f*"
    ]
    ++ lib.concatMap (cluster: [
      "${git}push ${cluster}*"
      "${git}push * ${cluster}*"
    ]) safety.pushForceClusters;
  gitAsk = git: [
    "${git}push"
    "${git}push *"
    "${git}rebase *"
    "${git}branch -D *"
    "${git}commit *"
  ];
  secretPaths = [
    ".env"
    ".env.*"
    "**/.env"
    "**/.env.*"
    "**/secrets/**"
    ".ssh/*"
    "**/.ssh/**"
    "~/.ssh/**"
    ".credentials/*"
    "**/.credentials/**"
    "Library/Keychains/*"
    "**/Library/Keychains/**"
    ".aws/credentials"
    "~/.aws/credentials"
    ".config/gh/hosts.yml"
    "~/.config/gh/hosts.yml"
    "~/.config/gh/hosts.yaml"
    "**/credentials.json"
    "**/*.pem"
    "**/*.key"
    "**/*.p12"
    "**/*.pfx"
    "//run/secrets/**"
  ];
in
{
  imports = [
    ./ai-assets.nix
  ];

  home.ai-assets.enable = true;

  home.claude-code = {
    enable = true;

    permissions = {
      defaultMode = "auto";
      additionalDirectories = [ "/" ];

      allow = [
        "Bash(*)"
        "Read(*)"
        "Write(*)"
        "Edit(*)"
        "Glob(*)"
        "Grep(*)"
        "WebFetch(*)"
        "WebSearch"
        "Agent(*)"
        "Skill"
        "TaskCreate"
        "TaskGet"
        "TaskList"
        "TaskUpdate"
        "ExitPlanMode"
        "EnterPlanMode"
        "KillShell"
        "LSP"
        "NotebookEdit"
      ];

      ask = map bash (
        map (flag: "rm ${flag} *") safety.recursiveRmFlags
        ++ [
          "find *-delete*"
          "npm publish"
          "npm publish *"
        ]
        ++ lib.concatMap gitAsk safety.gitPrefixes
        ++ lib.concatMap (command: [
          command
          "${command} *"
        ]) safety.remoteCommands
        ++ lib.concatMap (
          client: map (statement: "${client} *${statement}*") safety.destructiveSql
        ) safety.databaseClients
      );

      deny =
        map bash (
          [
            "rm -rf *"
            "sudo *"
            "chown *"
            "chmod -R 777*"
            "curl * | *sh*"
            "curl * | *bash*"
            "sops*"
          ]
          ++ recursiveRm "" safety.recursiveRmFlags
          ++ lib.concatMap gitDeny safety.gitPrefixes
        )
        ++ lib.concatMap (path: [
          "Read(${path})"
          "Edit(${path})"
        ]) secretPaths;
    };
  };
}
