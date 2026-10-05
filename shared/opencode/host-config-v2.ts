import { homedir } from "node:os"
import { join } from "node:path"
import { Plugin } from "@opencode/plugin"

// Isolate OpenCode itself, not Git credentials or desktop tools spawned by it.
export default Plugin.define({
  id: "host-config-v2",
  async setup(ctx) {
    await ctx.shell.hook("create.before", (event) => {
      event.env.XDG_CONFIG_HOME = join(event.env.HOME || homedir(), ".config")
    })
  },
})
