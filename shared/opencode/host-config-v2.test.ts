import { expect, mock, test } from "bun:test"
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

mock.module("@opencode/plugin", () => ({ Plugin: { define: (plugin: unknown) => plugin } }))
const { default: plugin } = await import("./host-config-v2")

test("shell children find host Git config and rofi theme without changing server isolation", async () => {
  let before: (event: any) => void
  await (plugin as any).setup({
    shell: { hook: async (name: string, callback: typeof before) => {
      expect(name).toBe("create.before")
      before = callback
    } },
  })
  const home = mkdtempSync(join(tmpdir(), "host-config-v2-"))
  try {
    mkdirSync(join(home, ".config/git"), { recursive: true })
    mkdirSync(join(home, ".config/rofi"), { recursive: true })
    writeFileSync(join(home, ".config/git/config"), "[credential]\n\thelper = fixture-helper\n")
    writeFileSync(join(home, ".config/rofi/ulauncher-like.rasi"), "* { background: #000000; }\n")
    const server = {
      ...process.env,
      HOME: home,
      XDG_CONFIG_HOME: join(home, ".config/opencode-v2"),
      OPENCODE_CONFIG_DIR: join(home, ".config/opencode-v2"),
      XDG_DATA_HOME: join(home, ".local/opencode-v2/data"),
      GIT_CONFIG_NOSYSTEM: "1",
      GIT_CONFIG_GLOBAL: undefined,
    }
    const git = (env: typeof server) => Bun.spawnSync(["git", "config", "--global", "--get", "credential.helper"], { env })
    expect(git(server).exitCode).not.toBe(0)
    const event = { command: "git push", cwd: home, timeout: 1000, shell: "/bin/sh", env: { ...server } }
    before!(event)
    expect(git(event.env).stdout.toString().trim()).toBe("fixture-helper")
    expect(Bun.file(join(event.env.XDG_CONFIG_HOME, "rofi/ulauncher-like.rasi")).size).toBeGreaterThan(0)
    expect(event.command).toBe("git push")
    expect(event.env.OPENCODE_CONFIG_DIR).toBe(server.OPENCODE_CONFIG_DIR)
    expect(event.env.XDG_DATA_HOME).toBe(server.XDG_DATA_HOME)
    expect(server.XDG_CONFIG_HOME).toBe(join(home, ".config/opencode-v2"))
  } finally {
    rmSync(home, { recursive: true, force: true })
  }
})
