import { Plugin } from "@opencode/plugin"
const GO_COMMAND = "gentle-ai"

export default Plugin.define({
  id: "skill-registry",
  setup(ctx) {
    const root = ctx.location.directory
    if (root === "/") return
    const refresh = Bun.spawn([GO_COMMAND, "skill-registry", "refresh", "--quiet", "--no-gitignore", "--cwd", root])
    void refresh.exited
  },
})
