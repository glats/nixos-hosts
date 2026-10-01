{
  lib,
  cfg,
  permissionRules,
  runtimeDir,
}:

let
  skillsRoot = "${runtimeDir}/skills";
  executorContract = ''
    ## OpenCode V2 executor contract
    Use the live direct tool names and input schemas, not names remembered from other runtimes.
    For inspection, use direct read({path, offset?, limit?}). For commands, use direct
    shell({command, workdir?, timeout?, background?}) only when allowed by this agent's permissions.
    There is no direct bash tool; the bash-to-shell permission mapping is not a tool alias.
    Direct shell and read are not Code Mode catalog tools; do not search for or call them inside execute.
    For Code Mode tools, use execute({code}); when discovery is needed, call synchronous
    search({query?, namespace?, limit?, offset?}) inside that code without await, then use the
    returned exact callable paths and signatures. Never guess or normalize tool names.
    Managed skills live at ${skillsRoot}. Resolve skills/_shared/... references in loaded
    skills under ${skillsRoot}/_shared/..., not the repository or the V1 runtime.
    Keep repository-relative openspec/... artifact paths relative to the repository.
  '';
  system =
    name: prompt:
    if lib.hasPrefix "sdd-" name then
      executorContract
      + "\n"
      + builtins.replaceStrings [ "~/.config/opencode/skills/" ] [ "${skillsRoot}/" ] prompt
    else
      prompt;
  mode =
    value:
    if value == "subagent" then
      "subagent"
    else if value == "primary" then
      "primary"
    else
      "all";
  remap =
    name: agent:
    (lib.removeAttrs agent [
      "maxSteps"
      "tools"
      "prompt"
      "disable"
      "permission"
      "mode"
    ])
    // lib.optionalAttrs (agent ? maxSteps) { steps = agent.maxSteps; }
    // lib.optionalAttrs (agent ? prompt) { system = system name agent.prompt; }
    // lib.optionalAttrs (agent ? disable) { disabled = agent.disable; }
    // lib.optionalAttrs (agent ? permission) { permissions = permissionRules agent.permission; }
    // {
      mode = mode (agent.mode or "all");
    };
in
lib.mapAttrs remap cfg.agents
