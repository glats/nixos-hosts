{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  safety = import ../ai-safety.nix;
  rule = effect: name: {
    inherit name;
    value = effect;
  };
  ask = rule "ask";
  deny = rule "deny";

  recursiveRm =
    prefix: flags:
    concatMap (
      flag:
      [ (ask "${prefix}rm ${flag} *") ]
      ++ map (target: deny "${prefix}rm ${flag} ${target}") safety.protectedRmTargets
      ++ map (target: deny "${prefix}rm ${flag} * ${target}") safety.trailingRmTargets
    ) flags;

  gitRules =
    git:
    map ask [
      "${git}push"
      "${git}push *"
      "${git}rebase *"
      "${git}branch -D *"
    ]
    ++ map deny (
      [
        "${git}reset --hard"
        "${git}reset --hard *"
        "${git}reset * --hard*"
        "${git}clean -f*"
        "${git}clean -?f*"
        "${git}clean -??f*"
        "${git}clean * -f*"
        "${git}clean * -?f*"
        "${git}push --force*"
        "${git}push * --force*"
        "${git}push -f*"
        "${git}push * -f*"
      ]
      ++ concatMap (cluster: [
        "${git}push ${cluster}*"
        "${git}push * ${cluster}*"
      ]) safety.pushForceClusters
    );

  bashRules =
    recursiveRm "" safety.recursiveRmFlags
    ++ recursiveRm "sudo " safety.sudoRmFlags
    ++
      concatMap
        (prefix: [
          (ask "${prefix}find *-delete*")
          (deny "${prefix}chmod -R 777*")
          (deny "${prefix}chown -R *")
        ])
        [
          ""
          "sudo "
        ]
    ++ concatMap gitRules safety.gitPrefixes
    ++ map ask [
      "npm publish"
      "npm publish *"
    ]
    ++ concatMap (command: [
      (ask command)
      (ask "${command} *")
    ]) safety.remoteCommands
    ++ concatMap (
      client: map (statement: ask "${client} *${statement}*") safety.destructiveSql
    ) safety.databaseClients;

  pathRules = {
    "*" = "allow";
    "/run/secrets/**" = "deny";
  }
  // genAttrs safety.sensitivePaths (_: "deny");

  defaultPermissions = {
    external_directory = {
      "/**" = "allow";
    };
    bash = {
      "*" = "allow";
      "sops*" = "deny";
      "git commit *" = "ask";
    }
    // listToAttrs bashRules;
    read = pathRules;
    edit = pathRules;
  };
in
{
  options.home.opencode.permissions = mkOption {
    type = types.attrs;
    default = defaultPermissions;
    description = ''
      Permission rules for OpenCode agents.

      Keys:
      - external_directory: Rules for external directory access
      - bash: Rules for bash command execution
      - read: Rules for file read access

      Values are attrsets where:
      - Keys are glob patterns (e.g., "*", "**/.env", "git push *")
      - Values are permission levels: "allow", "deny", or "ask"

      Example:
      {
        bash = {
          "rm -rf /" = "deny";
          "git *" = "allow";
        };
      }
    '';
  };
}
