import { Plugin } from "@opencode/plugin"

// Review ownership remains with the caller. The relay only preserves the
// session marker used by the native review agents and never selects a branch.
export default Plugin.define({
  id: "opencode-review-transport",
  setup(ctx) {
    ctx.session.hook("prompt", async (event) => {
      event.metadata = { ...event.metadata, "gentle-ai-review": "pass-through" }
    })
  },
})
