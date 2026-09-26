import { Plugin } from "@opencode/plugin"

export default Plugin.define({
  id: "skill-registry",
  setup() {
    const root = process.cwd()
    if (root === "/") return
    const refresh = Bun.spawn(["gentle-ai", "skill-registry", "refresh", "--quiet", "--no-gitignore", "--cwd", root])
    void refresh.exited
  },
})
