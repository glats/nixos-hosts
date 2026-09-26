import { Plugin } from "@opencode/plugin"

// Engram is accessed through its MCP server. The adapter records the native
// session identifier without changing any memory command arguments.
const ENGRAM_BIN = process.env.ENGRAM_BIN ?? "engram"

export default Plugin.define({
  id: "engram",
  setup(ctx) {
    if (!Bun.which(ENGRAM_BIN)) return
    ctx.session.hook("prompt", async (event) => {
      event.metadata = { ...event.metadata, engram_session_id: event.sessionID }
    })
  },
})
