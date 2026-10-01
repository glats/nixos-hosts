import { Plugin } from "@opencode/plugin/effect"
import { Tool } from "@opencode/schema/tool"
import { Effect, Stream } from "effect"

const TASK_RESULT = /^<task id="[^"\r\n]+" state="completed">\n(?:<summary>[^<>\r\n]+<\/summary>\n)?<task_result>\n([\s\S]*?)\n<\/task_result>\n<\/task>$/
const TASK_TAG = /<\/?(?:task|task_result|summary)(?:\s|>)/
const PHASES = ["sdd-init", "sdd-explore", "sdd-propose", "sdd-spec", "sdd-design", "sdd-tasks", "sdd-apply", "sdd-verify", "sdd-archive", "sdd-onboard"]
const PREFIX = "GENTLE_AI_SDD_FAILURE "
type Failure = { phase: string; code: string }

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : undefined
}

function phase(tool: string, input: unknown): string | undefined {
  const agent = record(input)?.agent
  return tool === "subagent" && typeof agent === "string" && PHASES.some((name) => agent === name || agent.startsWith(name + "-")) ? agent : undefined
}

function invalidOutput(value: unknown): string | undefined {
  // The pinned native completion helper substitutes this sentinel for no text.
  if (typeof value !== "string" || value.trim() === "" || value.trim() === "Subagent completed without a text response.") return "sdd_task_result_empty"
  const text = value.trim()
  const envelope = TASK_RESULT.exec(text)
  if (!envelope) return TASK_TAG.test(text) ? "sdd_task_result_malformed" : undefined
  if (envelope[1].trim() === "") return "sdd_task_result_empty"
  return TASK_TAG.test(envelope[1]) ? "sdd_task_result_malformed" : undefined
}

function handoff(requested: string, failure: Failure, cwd: string, latched = false): string {
  const usable = cwd.trim() !== "" && !/^(?:[\\/]+|[A-Za-z]:[\\/]*)$/.test(cwd.trim())
  return PREFIX + JSON.stringify({
    schemaName: "gentle-ai.sdd-task-result-failure/v1",
    status: "blocked",
    code: latched ? "sdd_task_dispatch_latched" : failure.code,
    phase: requested,
    ...(latched ? { latchedPhase: failure.phase, latchedCode: failure.code } : {}),
    summary: latched
      ? `${requested} was not dispatched. An earlier SDD phase failed in this session; no provider call or artifact write happened for this launch.`
      : `${requested} returned no valid terminal task result. Do not retry or advance SDD; inspect the existing artifact state and surface the terminal failure to the user.`,
    continuation: usable ? `gentle-ai sdd-status --cwd '${cwd.replace(/'/g, "'\\''")}' --json` : "gentle-ai sdd-status --cwd <repo> --json",
    exit: "Inspect the existing artifact state and surface the failure to the user. Start a new session before launching SDD again.",
  })
}

// Effect hooks are required: the pinned Promise adapter turns throws into
// defects, whereas execute.before accepts a typed Tool.Error rejection.
export default Plugin.define({
  id: "sdd-task-result",
  effect: (ctx) => Effect.gen(function* () {
    const failures = new Map<string, Failure>()
    const cwd = ctx.location.directory
    yield* Effect.addFinalizer(() => Effect.sync(() => failures.clear()))
    yield* ctx.session.hook("prompt", (event) => Effect.sync(() => {
      event.metadata = { ...event.metadata, "sdd-task-result": "pending" }
    }))
    yield* ctx.tool.hook("execute.before", (event) => Effect.gen(function* () {
      const requested = phase(event.tool, event.input)
      const failure = failures.get(event.sessionID)
      if (requested && failure) yield* Effect.fail(new Tool.Error({ message: handoff(requested, failure, cwd, true) }))
    }))
    yield* ctx.tool.hook("execute.after", (event) => Effect.sync(() => {
      const requested = phase(event.tool, event.input)
      if (!requested || event.status !== "completed") return
      const child = record(event.result.output)
      // Native running acknowledgements include foreground jobs backgrounded
      // while waiting. The background argument alone is not a terminal signal.
      if (child?.status === "running") return
      const code = child?.status === "completed" && typeof child.sessionID === "string" && child.sessionID !== ""
        ? invalidOutput(child.output)
        : "sdd_task_result_malformed"
      if (!code) return
      const failure = { phase: requested, code }
      if (!failures.has(event.sessionID)) failures.set(event.sessionID, failure)
      const message = handoff(requested, failure, cwd)
      // execute.after has no failure channel in 2.0.14. Replace model-visible
      // content and structured output; do not throw or fake a tool error state.
      event.result = {
        ...event.result,
        output: { ...child, output: message },
        content: message,
      }
    }))
    yield* ctx.event.subscribe().pipe(
      Stream.runForEach((event) => Effect.sync(() => {
        if (event.type === "session.deleted") failures.delete(event.data.sessionID)
      })),
      Effect.forkScoped({ startImmediately: true }),
    )
  }),
})
