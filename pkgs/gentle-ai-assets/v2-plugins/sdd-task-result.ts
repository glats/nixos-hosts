import { Plugin } from "@opencode/plugin"

// V2 emits task outcomes through the native session metadata channel.
export default Plugin.define({
  id: "sdd-task-result",
  setup(ctx) {
    ctx.session.hook("prompt", async (event) => {
      event.metadata = { ...event.metadata, "sdd-task-result": "pending" }
    })
  },
})
