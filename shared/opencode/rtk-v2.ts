import { Plugin } from "@opencode/plugin"

// Keep the rewrite policy in RTK. This adapter only invokes its native rewrite
// command and leaves the original shell input untouched when RTK is unavailable.
export default Plugin.define({
  id: "rtk-v2",
  setup(ctx) {
    if (!Bun.which("rtk")) return

    ctx.tool.hook("execute.before", async (event) => {
      if (event.tool !== "shell" || !event.input || typeof event.input !== "object") return
      const input = event.input as { command?: unknown }
      if (typeof input.command !== "string" || input.command.length === 0) return

      const result = Bun.spawnSync(["rtk", "rewrite", input.command], { stdout: "pipe", stderr: "pipe" })
      if (result.exitCode !== 0) return
      const rewritten = new TextDecoder().decode(result.stdout).trim()
      if (rewritten) input.command = rewritten
    })
  },
})
