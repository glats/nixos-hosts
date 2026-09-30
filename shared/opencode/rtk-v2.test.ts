import { expect, mock, test } from "bun:test"

mock.module("@opencode/plugin", () => ({ Plugin: { define: (plugin: unknown) => plugin } }))
const { default: plugin } = await import("./rtk-v2")

test("preserves PR head and environment while leaving unsupported review commands intact", async () => {
  const hooks = new Map<string, (event: any) => Promise<void>>()
  await (plugin as any).setup({
    tool: { hook: (name: string, callback: (event: any) => Promise<void>) => hooks.set(name, callback) },
  })
  const before = hooks.get("execute.before")!

  const pr = { tool: "shell", input: { command: "env TEST_FLAG=fixture gh pr create --head feature/review --base main" } }
  await before(pr)
  expect(pr.input.command).toBe("env TEST_FLAG=fixture rtk gh pr create --head feature/review --base main")

  const review = { tool: "shell", input: { command: "TEST_FLAG=fixture gentle-ai review status --cwd /tmp/review-fixture --next-transition" } }
  await before(review)
  expect(review.input.command).toBe("TEST_FLAG=fixture gentle-ai review status --cwd /tmp/review-fixture --next-transition")
})
