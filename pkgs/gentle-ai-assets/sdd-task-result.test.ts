import { describe, expect, test } from "bun:test"
import { Cause, Effect, Exit, Queue, Scope, Stream } from "effect"
import plugin from "./v2-plugins/sdd-task-result"

// Run the actual pinned Effect API, not a mock Plugin.define or Promise hook.
// Resolve dependencies from the existing opencode-npm-packages-v2 closure
// (Bun --tsconfig-override paths); do not install packages for this test.
async function harness(directory = "/tmp/sdd-fixture") {
  const scope = await Effect.runPromise(Scope.make())
  const events = await Effect.runPromise(Queue.unbounded<any>())
  const hooks = new Map<string, (event: any) => any>()
  const register = (name: string, callback: any) => Effect.gen(function* () {
    hooks.set(name, callback)
    const dispose = Effect.sync(() => { hooks.delete(name) })
    yield* Effect.addFinalizer(() => dispose)
    return { dispose }
  })
  await Effect.runPromise(plugin.effect({
    location: { directory },
    tool: { hook: register },
    session: { hook: register },
    event: { subscribe: () => Stream.fromQueue(events) },
  } as any).pipe(Scope.provide(scope)))
  return {
    hooks,
    call: (name: string, event: any) => Effect.runPromise(hooks.get(name)!(event)),
    deletion: async (sessionID: string) => {
      await Effect.runPromise(Queue.offer(events, { type: "session.deleted", data: { sessionID } }))
      await new Promise((resolve) => setTimeout(resolve, 0))
    },
    close: () => Effect.runPromise(Scope.close(scope, Exit.void)),
  }
}

function completion(output: unknown, agent = "sdd-explore", sessionID = "parent") {
  return {
    tool: "subagent", sessionID, input: { agent }, status: "completed",
    result: { output: { sessionID: "child", status: "completed", output }, content: "native wrapper", metadata: { preserved: true } },
  }
}

function failure(event: any) {
  expect(event.result.content).toStartWith("GENTLE_AI_SDD_FAILURE ")
  expect(event.result.output.output).toBe(event.result.content)
  return JSON.parse(event.result.content.slice("GENTLE_AI_SDD_FAILURE ".length))
}

describe("pinned V2 SDD terminal results", () => {
  test("rejects empty, malformed and native no-text results and latches dispatch", async () => {
    const cases: [unknown, string][] = [
      ["", "empty"], [" \n\t", "empty"], [undefined, "empty"], [null, "empty"], [42, "empty"], [{}, "empty"],
      ["Subagent completed without a text response.", "empty"],
      ['<task id="x" state="completed">\n<task_result>\n \n</task_result>\n</task>', "empty"],
      ['<task id="x" state="completed">broken', "malformed"],
      ['<task id="x" state="completed">\n<task_result>\n<task_result>nested</task_result>\n</task_result>\n</task>', "malformed"],
      ['<task id="x" state="completed">\n<task_result>\n  <task_result>nested</task_result>\n</task_result>\n</task>', "malformed"],
      ['<task id="x" state="running">\n<task_result>\ntext\n</task_result>\n</task>', "malformed"],
    ]
    for (const [output, classification] of cases) {
      const h = await harness()
      try {
        const event = completion(output)
        await h.call("execute.after", event)
        expect(failure(event)).toMatchObject({ status: "blocked", phase: "sdd-explore", code: `sdd_task_result_${classification}` })
        expect(event.result.metadata).toEqual({ preserved: true })
        for (const agent of ["sdd-explore", "sdd-apply", "sdd-verify-special", "sdd-onboard"]) {
          const exit = await Effect.runPromiseExit(h.hooks.get("execute.before")!({ tool: "subagent", sessionID: "parent", input: { agent, background: true } }))
          expect(Exit.isFailure(exit)).toBe(true)
          // A typed failure is recoverable by the native dispatcher, not a defect.
          if (Exit.isFailure(exit)) expect(Cause.hasDies(exit.cause)).toBe(false)
          expect(JSON.stringify(exit)).toContain('"_tag":"Tool.Error"')
          expect(JSON.stringify(exit)).toContain("sdd_task_dispatch_latched")
        }
        await h.call("execute.before", { tool: "subagent", sessionID: "other", input: { agent: "sdd-apply" } })
      } finally { await h.close() }
    }
  })

  test("passes plain and legacy enveloped text without mutation", async () => {
    const h = await harness()
    try {
      for (const output of ["Valid plain output", '  <task id="x" state="completed">\n<summary>Done</summary>\n<task_result>\nValid output\n</task_result>\n</task>  ']) {
        const event = completion(output)
        const previous = structuredClone(event)
        await h.call("execute.after", event)
        expect(event).toEqual(previous)
      }
      await h.call("execute.before", { tool: "subagent", sessionID: "parent", input: { agent: "sdd-apply" } })
    } finally { await h.close() }
  })

  test("passes Markdown describing transport tags without latching dispatch", async () => {
    const h = await harness()
    const report = "## Findings\n\nThe guard validates `<task_result>` envelopes, not report prose."
    try {
      for (const output of [
        report,
        "Mention <task_result> as literal text, not a transport envelope.",
        "Example:\n```xml\n<task_result>example</task_result>\n```",
        `<task id="x" state="completed">\n<task_result>\n${report}\n</task_result>\n</task>`,
      ]) {
        const event = completion(output)
        const previous = structuredClone(event)
        await h.call("execute.after", event)
        expect(event).toEqual(previous)
        await h.call("execute.before", { tool: "subagent", sessionID: "parent", input: { agent: "sdd-explore" } })
      }
    } finally { await h.close() }
  })

  test("validates nested native output, never the rendered content wrapper", async () => {
    const h = await harness()
    try {
      for (const child of [undefined, "text", {}, { status: "unknown" }, { status: "completed", output: "valid" }, { status: "completed", sessionID: "", output: "valid" }]) {
        const event: any = completion("valid")
        event.result.output = child
        await h.call("execute.after", event)
        expect(failure(event).code).toBe("sdd_task_result_malformed")
      }
    } finally { await h.close() }
  })

  test("ignores running acknowledgements, errors and non-SDD calls", async () => {
    const h = await harness()
    try {
      const events: any[] = [
        { ...completion(""), result: { output: { status: "running", sessionID: "child", output: "" }, content: "ack" } },
        { ...completion(""), status: "error", error: { message: "native error" } },
        completion("", "general"), completion("", "review-risk"), completion("", "sdd-exploration"),
        { ...completion(""), tool: "task" }, { ...completion(""), input: { subagent_type: "sdd-explore" } },
      ]
      for (const event of events) {
        const previous = structuredClone(event)
        await h.call("execute.after", event)
        expect(event).toEqual(previous)
      }
      await h.call("execute.before", { tool: "subagent", sessionID: "parent", input: { agent: "sdd-apply" } })
      await h.call("execute.after", completion(""))
      for (const agent of ["general", "review-risk", "sdd-exploration"]) await h.call("execute.before", { tool: "subagent", sessionID: "parent", input: { agent } })
    } finally { await h.close() }
  })

  test("completed output remains terminal even if launch requested background", async () => {
    const h = await harness()
    try {
      const event: any = completion("")
      event.input.background = true
      await h.call("execute.after", event)
      expect(failure(event).code).toBe("sdd_task_result_empty")
    } finally { await h.close() }
  })

  test("cleans only the deleted parent and disposes scoped hooks", async () => {
    const h = await harness()
    await h.call("execute.after", completion(""))
    await h.call("execute.after", completion("", "sdd-spec", "other"))
    await h.deletion("child")
    await expect(h.call("execute.before", { tool: "subagent", sessionID: "parent", input: { agent: "sdd-apply" } })).rejects.toThrow("sdd_task_dispatch_latched")
    await h.deletion("parent")
    await h.call("execute.before", { tool: "subagent", sessionID: "parent", input: { agent: "sdd-apply" } })
    await expect(h.call("execute.before", { tool: "subagent", sessionID: "other", input: { agent: "sdd-apply" } })).rejects.toThrow("sdd_task_dispatch_latched")
    const before = h.hooks.get("execute.before")!
    await h.close()
    expect(h.hooks.size).toBe(0)
    await Effect.runPromise(before({ tool: "subagent", sessionID: "other", input: { agent: "sdd-apply" } }))
  })

  test("preserves prompt metadata and supplies safe continuation", async () => {
    for (const directory of ["/", "", "/tmp/repo's path"]) {
      const h = await harness(directory)
      try {
        const prompt = { metadata: { existing: true } }
        await h.call("prompt", prompt)
        expect(prompt.metadata).toEqual({ existing: true, "sdd-task-result": "pending" })
        const event = completion("")
        await h.call("execute.after", event)
        expect(failure(event).continuation).toBe(directory === "/tmp/repo's path" ? "gentle-ai sdd-status --cwd '/tmp/repo'\\''s path' --json" : "gentle-ai sdd-status --cwd <repo> --json")
      } finally { await h.close() }
    }
  })
})
