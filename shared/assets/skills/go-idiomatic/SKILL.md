---
name: go-idiomatic
description: "Trigger: writing Go, Golang, refactor Go, idiomatic Go. Apply Go-specific design rules while preserving observable behavior."
license: Apache-2.0
metadata:
  author: "glats"
  version: "1.0"
---

## Activation Contract

Load for Go implementation, review, or refactoring. Inspection requests remain
read-only; this skill never authorizes edits, installs, commits, or activation.

## Hard Rules

- Read `go.mod`, applicable build tags, callers, and boundary contracts first.
  Use standard-library APIs supported by the module's declared Go version.
- Decode known input shapes into concrete types where contracts permit. Validate
  external input and business invariants; typed structs alone prove neither.
- Preserve CLI output, exit codes, exported APIs, persisted formats, JSON
  nil/empty distinctions, optional/default values, and accepted input semantics.
- Preserve ownership, defensive copies, resource cleanup, and synchronization
  unless their redundancy is demonstrated. Never remove checks by pattern alone.
- Return actionable errors; preserve `errors.Is`/`errors.As` behavior. Add useful
  context, not repeated wrapping or logging. Do not turn failures into success.
- Propagate caller contexts across I/O; release resources on every path. Give
  goroutines explicit cancellation, completion, and error ownership.

## Decision Gates

| Observation | Action |
| --- | --- |
| Known schema carried through `any` or maps | Trace producers and consumers before proposing typed decoding. |
| Interface, helper, wrapper, or DTO | Keep meaningful consumer contracts, test seams, security boundaries, and invariants; simplify only demonstrated redundancy. |
| Generics, reflection, concurrency, or optimization | Require an actual use case; measure performance claims. |
| Change alters observable behavior | Treat as a separate behavior change requiring authorization, not cleanup. |

## Execution Steps

1. Bound the requested scope and trace data, errors, resources, and callers.
2. Prefer existing code and version-compatible standard library over new layers
   or dependencies. Do not optimize for line counts or health scores.
3. Load `safe-refactor` for behavior-preserving restructuring and `go-testing`
   for test changes through the runtime skill loader. If unavailable, disclose
   that limitation and retain repository verification requirements.
4. For authorized edits, establish baseline behavior and relevant regression
   checks before changing code. Format touched Go files before final checks.
5. Run applicable repository tests and `go vet` from the module root; use
   Staticcheck when available and race detection for concurrency-sensitive work
   on supported platforms. Do not install missing tools or run operational
   commands against live data merely to verify. Report unavailable checks.
6. Stop when the requested outcome and applicable checks are satisfied; leave
   unrelated cleanup as suggestions.

## Output Contract

Report evidence locations, the minimal change or recommendation, preserved
contracts, observed checks, and remaining risks. Separate findings from proven
defects; never claim tests establish complete correctness.
