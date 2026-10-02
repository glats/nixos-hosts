# Delta for macm5-openai-tls-tunnel

## MODIFIED Requirements

### Requirement: Proxy-Environment and MCP Isolation

Proxy variables MUST be set ONLY by the packaged `opencode-home` scoped launcher, including its explicit V2 invocation, and ONLY when a bounded readiness probe confirms `127.0.0.1:2080` is listening. Probe failure or timeout MUST produce a stderr notice and continue launch without adding proxy variables; listener readiness MUST NOT imply tunnel connectivity. Shell profiles and the tunnel daemon MUST NOT export `HTTP_PROXY` or `HTTPS_PROXY` globally.

The V2 scoped invocation MUST execute the packaged V2 executable, not V1 or a same-named PATH executable. It MUST retain the existing V2 isolation environment and forward every user argument unchanged. Shell-function resolution MUST NOT be required by the executable launcher. Missing V2 isolation or executable MUST fail visibly without falling back to V1 or unisolated V2. The parent shell, V1 behavior, ordinary V2 invocations, and other hosts MUST remain unchanged.

The macm5 `opencode2-home` function MUST default interactive TUI and `mini` invocations to a private V2 server using the documented top-level `--standalone` position. For `run`, it MUST place `--standalone` after the subcommand. It MUST preserve all user arguments and MUST NOT inject the flag into unrelated subcommands or invocations that explicitly select `--server` or already provide `--standalone`.

Local MCP children MUST retain clean proxy environments through generated declarative configuration: `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` MUST be absent or empty, and `NO_PROXY` MUST equal `*`. Remote MCP definitions MUST remain unchanged. In full mode MCP traffic MAY traverse the tunnel solely by routing.

(Previously: scoped launch covered V1 only, referenced obsolete `bin/opencode-home`, and did not specify V2 executable identity or isolation.)

#### Scenario: Inspect MCP environments [hosts: macm5]

- GIVEN V1 or scoped V2 has launched representative local MCP children through the active tunnel
- WHEN each child's environment is inspected
- THEN proxy variables are absent or empty and `NO_PROXY` is `*`

#### Scenario: Scoped launcher exports proxy conditionally [hosts: macm5]

- GIVEN a proxy-clean parent launches `opencode-home` with the listener up and down
- WHEN each V1 process environment is inspected
- THEN `HTTP_PROXY`/`HTTPS_PROXY` equal `http://127.0.0.1:2080` only while listening
- AND down-listener launch prints a stderr notice, stays proxy-clean, and no shell profile globally exports either variable

#### Scenario: V2 listener available [hosts: macm5]

- GIVEN the loopback listener accepts connections
- WHEN scoped V2 starts
- THEN its process receives `HTTP_PROXY`/`HTTPS_PROXY=http://127.0.0.1:2080`
- AND this result establishes listener readiness only

#### Scenario: V2 readiness failure [hosts: macm5]

- GIVEN a proxy-clean parent and a refused, failed, or timed-out probe
- WHEN scoped V2 starts
- THEN it prints a stderr notice and launches without adding proxy variables
- AND readiness checking completes within a declared finite timeout

#### Scenario: V2 identity and argument preservation [hosts: macm5]

- GIVEN an `opencode2` shell function and competing V1/V2 executables on PATH
- WHEN scoped V2 receives arguments containing spaces, empty strings, and option-like values
- THEN the packaged V2 executable receives exactly those arguments in order

#### Scenario: Isolation survives executable launch [hosts: macm5]

- GIVEN the existing generated V2 environment and a parent with different XDG settings
- WHEN scoped V2 starts
- THEN its XDG config/data/cache/state, config directory, database, temporary directory, project-config policy, and supporting PATH match ordinary isolated V2
- AND parent variables and V1 configuration, authentication, and data remain unchanged

#### Scenario: Missing V2 prerequisites [hosts: macm5]

- GIVEN V2 isolation cannot be loaded or its executable cannot run
- WHEN scoped V2 is invoked
- THEN it exits nonzero with a diagnostic and launches neither V1 nor unisolated V2

#### Scenario: Declarative MCP hygiene [hosts: macm5]

- GIVEN enabled local and remote MCP definitions, including conflicting local proxy settings
- WHEN V1 and V2 configurations are generated
- THEN local proxy overrides enforce clean environments and preserve unrelated local settings
- AND remote definitions receive no proxy overrides

#### Scenario: Existing launch paths remain unchanged [hosts: macm5, rog, thinkcentre, t14]

- GIVEN existing V1 and ordinary V2 launch paths
- WHEN their behavior is compared before and after this change
- THEN their executable selection, arguments, isolation policies, and proxy behavior remain unchanged

#### Scenario: V2 home alias owns its default server [hosts: macm5]

- GIVEN the user invokes `opencode2-home` without selecting a server
- WHEN the interactive TUI or `mini` starts
- THEN the packaged V2 CLI receives `--standalone` in the top-level position
- AND the user does not need to provide a standalone flag

#### Scenario: V2 run owns its default server [hosts: macm5]

- GIVEN the user invokes `opencode2-home run` without selecting a server
- WHEN the run command starts
- THEN `--standalone` follows `run`
- AND every user-supplied run argument remains in order and unchanged

#### Scenario: Other commands and explicit server selection [hosts: macm5]

- GIVEN an unrelated CLI subcommand or an explicit `--server`/`--standalone` argument
- WHEN `opencode2-home` is invoked
- THEN it does not add a standalone flag
- AND it forwards the user's arguments unchanged
