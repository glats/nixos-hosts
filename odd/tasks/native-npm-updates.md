# Native npm updates
Objective: standard npm locks and separate update, validation, and activation. Branch: `feat/npm`; delivery: user-authorized commit, merge to local master, and push (L11). Activation, service restarts, and runtime upgrades remain prohibited.
Route: inline implementation after delegated mapping; independent verification for dependency/security-sensitive changes. Runners: Go tests, pinned Nix evaluation/build checks. Estimated authored delta: 250–400 lines excluding generated locks; no PR planned.

## Specs
S1. "Verificar el flujo completo y escoger el mecanismo nativo más simple." Evaluate `buildNpmPackage` and `importNpmLock` against the actual pin; reuse the existing CLI and registrations.
S2. "Migrar los dos paquetes conservando versiones directas y comportamiento. Comparar dependencias transitivas; no aceptar cambios silenciosos." Preserve `lib/node_modules`, all BrowserMCP patches, and existing imports. User authorized testing the expanded standard dependency graphs (L6); preserve all existing exact pins and prove compatibility before delivery.
S3. "Eliminar o reemplazar la llamada rota y su error silenciado." Observe a deterministic failing regression before correcting behavior; failures must be visible and nonzero.
S4. "Integrar actualización explícita de locks con el flujo existente, sin activar el sistema durante esa operación. Preservar comandos existentes; preguntar antes de cambiar su semántica." User subsequently approved `nix-upgrade` becoming update-only and `nix-switch` retaining build/activation without updates; keep `nixos-build check`, boot/test/safe, and no language-specific commands.
S5. "Actualizar ayuda y documentación." Document update, validation, activation, compatibility limitations, and protected coupled runtimes.
S6. "No usar --legacy-peer-deps ni desactivar scripts como solución automática: justificarlo con evidencia." No automatic OpenCode/Gentle AI or coupled dependency upgrades; Darwin npx migration remains follow-up only.
S7. "Reproducir el fallo con prueba determinista antes de corregirlo. Verificar dependencias, imports, estructura consumida, parches BrowserMCP y errores visibles. Ejecutar pruebas Go y checks Nix aplicables. Prever coste antes de builds largos. Verificación independiente para cambios de alto riesgo."

## Tasks
- T1 [S1,S2,S6] delegated + parent correction — Linux builds/install checks passed; direct versions and tarball integrity identical; commit prohibited.
- T2 [S3,S4] delegated — complete: observed RED for swallowed failure, focused GREEN and full Go suite/vet passed; commit prohibited.
- T3 [S2,S5,S7] inline — docs/help integrated, shared Linux checks passed; Darwin system/home evaluation unavailable on this host; commit prohibited.
- T4 [S1–S7] delegated verification — Linux verification complete, no change-caused blockers; native review unavailable (budget), reported and candidate-scoped declined with user consent; Darwin/live-extension proof pending; commit prohibited.

## Log
L1. Original user request (verbatim):
> ODD, caveman y ponytail: respuestas breves, solución mínima completa, reutilizar antes de crear.
>
> Objetivo
> Simplificar instalación y actualización de software, especialmente paquetes npm. Quiero un único flujo que actualice versiones y hashes sin editar archivos manualmente. Separar actualización, validación y activación.
>
> Autorización
> Puedes investigar, modificar código y añadir pruebas. No hacer stage, commits, push, activar configuraciones, reiniciar servicios ni actualizar runtimes sin autorización explícita. Respeta cambios existentes y políticas del repositorio.
>
> Contexto comprobado; verifica que siga vigente
> - nix-switch y nix-upgrade existen en shared/shell-aliases.nix.
> - nix-upgrade llama a nixos-build upgrade.
> - pkgs/nixos-scripts/internal/nixbuild/nixbuild.go intenta construir #opencode-npm-packages.updateScript.
> - Ese paquete fue eliminado en 14a1f654; el código conserva la llamada y silencia su error.
> - El actualizador antiguo modificaba versions.json y node-modules.json.
> - Actualmente ambos archivos existen en:
>   - pkgs/opencode-npm-packages-v2/
>   - pkgs/browsermcp-v2/
> - Esos paquetes YA son derivaciones Nix. Lo personalizado es la representación y extracción manual de dependencias.
> - pkgs/opencode-quota-patched y pkgs/mcp-supermercados-cl ofrecen precedentes con buildNpmPackage.
> - BrowserMCP tiene parches necesarios de compatibilidad y protección del puerto: conservarlos.
> - shared/opencode/runtime-config.nix consume la estructura lib/node_modules: preservar su contrato.
> - darwin/home/opencode/mcps-extra.nix contiene cuatro servidores mediante npx sin versión fija. Evaluarlos como mejora posterior, no migrarlos automáticamente.
>
> Primera entrega
> 1. Verificar el flujo completo y escoger el mecanismo nativo más simple.
> 2. Evaluar package.json + package-lock.json con buildNpmPackage/importNpmLock, comprobando API y compatibilidad con el nixpkgs fijado.
> 3. Migrar los dos paquetes conservando versiones directas y comportamiento. Comparar dependencias transitivas; no aceptar cambios silenciosos.
> 4. Eliminar o reemplazar la llamada rota y su error silenciado.
> 5. Integrar actualización explícita de locks con el flujo existente, sin activar el sistema durante esa operación. Preservar comandos existentes; preguntar antes de cambiar su semántica.
> 6. Actualizar ayuda y documentación.
>
> No confundir:
> - nix flake update actualiza inputs, no versiones literales ni package-lock.json.
> - Usar locks estándar reduce mantenimiento, pero no automatiza sus actualizaciones por sí solo.
> - Migrar empaquetado no autoriza subir OpenCode, Gentle AI ni sus dependencias acopladas.
> - No crear otro CLI, framework o manifiesto propio si las herramientas existentes bastan.
>
> ODD
> Explora primero y registra una tarea duradera antes de implementar si corresponde. Mantén alcance y evidencia en odd/tasks/<feature>.md; memoria en inglés si está disponible. No convertir artefactos OpenSpec históricos. Si Engram falla, continúa con registro local y deja espejo pendiente.
>
> Pruebas
> Reproducir el fallo con prueba determinista antes de corregirlo. Verificar dependencias, imports, estructura consumida, parches BrowserMCP y errores visibles. Ejecutar pruebas Go y checks Nix aplicables. Prever coste antes de builds largos. Verificación independiente para cambios de alto riesgo.
>
> No usar --legacy-peer-deps ni desactivar scripts como solución automática: justificarlo con evidencia. Si no puede preservarse compatibilidad, detener esa parte y explicar el bloqueo.
>
> Entrega
> Indicar cambios, pruebas observadas, pendientes y riesgo. Sin afirmar éxito de builds o plataformas no comprobadas. Auditoría general orientada a simplificación; implementar solo esta primera entrega.

L2. User correction (2026-10-26, verbatim): "si. o sea no quiero un comando asi tipo update-npm o update-zig por decir algo. de hecho quiero ahcer un refactor y consolidar nix-switch o nix-upgrade y que cada uno tenga el comportamiento que correpsonde. quizas no tner tanto nixos-build. no se que sugieres?"

L3. User approval (2026-10-26, verbatim): "ok" to making nix-upgrade update-only, nix-switch build/activate-only, retaining check and boot/test/safe; no language-specific subcommand.

L4. Baseline e9143c20577f08d8f87a496f25d4d659af02f6d3; initially clean. Read-only explorer mapped the flow; parent confirmed dangling attribute and swallowed error at nixbuild.go:250–295 and activation in upgrade at :153–175. Explorer established native npm APIs at the pin, not package compatibility. Actual host has nix, npm, go available. Existing package manifests pin flat closures (10 and 12 entries); standard resolution equivalence remains unproved. Rollback: retain old manifests/derivations until compatibility is demonstrated; do not activate changes. Engram mirror pending initial synchronization.

L5. Compatibility probe (2026-10-26): generated synthetic manifests in `/tmp/opencode/npm-lock-probe-bmgys256` using every existing exact version, then ran `npm install --package-lock-only --no-audit --no-fund --cache <scratch>/cache` with npm 11.17.0. Both exited 0. No legacy peer flag, ignore-scripts flag, runtime upgrade, repository manifest mutation, build, or activation was performed. OpenCode lock contains 285 non-root package entries versus 10 existing tarballs (275 added); BrowserMCP contains 93 versus 12 (81 added). Every existing top-level version is unchanged. Counts include nested/platform/optional lock entries, not necessarily installed runtime packages. Examples: OpenCode adds AWS/Smithy, Google authentication, npm tooling and telemetry dependencies; BrowserMCP adds express, cors, eventsource, and cross-spawn dependencies declared by its SDK. Registry metadata confirms the current flat sets omit declared transitive dependencies; therefore native installation is not proven behavior-equivalent. npm additionally warns that protobufjs@7.6.6 and msgpackr-extract@3.0.4 install scripts are not covered by allowScripts; no bypass or approval was applied. Logs and candidate locks remain in scratch only. Pause migration for explicit acceptance of graph expansion or preservation of current curated sets. Source edits, deterministic Go RED, Nix checks/builds, and independent verification remain pending; do not interpret lock generation as compatibility proof.

L6. User approval (2026-10-26, verbatim): "confirmo" to incorporating the reported transitive dependencies to test standard migration, keeping current versions and without activation. Plan: use buildNpmPackage with importNpmLock (verified against local pinned source); integrity lives in standard locks, no second npmDepsHash. Keep OpenCode's whole coupled lock frozen during ordinary upgrade; npm update for BrowserMCP respects exact direct pins and updates eligible transitive ranges. Explicit direct-version changes use native npm install --package-lock-only --save-exact, not another CLI or manifest. Upgrade updates sources only; check validates; switch builds/activates. Two independent units now justify parallel writers: package directories versus Go CLI. Parent owns task/docs and git. Expected package builds: several minutes and potentially hundreds of MiB to over 1 GiB with toolchain/cache misses; no system build or activation. Source mutation and dependency update during verification limited to scratch/candidate files, never running the real upgrade command.

L7. Implementation evidence: CLI worker observed RED `npm capture failure propagates: Run = 0, want 1`, then removed obsolete KindNpm/npmSteps and replaced upgrade with native BrowserMCP lock update followed by flake update. Existing non-upgrade command expectations remain. Darwin cache-push policy excludes upgrade. Focused test/vet passed; parent reran focused tests successfully. Packaging worker first built outputs but omitted running postInstall and changed OpenCode output metadata; parent added check.mjs tests and observed RED for missing port protection and incompatible metadata, restored runHook calls, original explanatory comments, derivation version and dependency-map output. Both corrected install checks passed. Original 22 versions AND integrity strings were compared exactly against new manifests/locks before deleting obsolete custom JSON files. No bypass flags added. Worker created an unintended empty `/tmp/unused` file outside its allowed surfaces; not consumed or removed, explicitly disclosed here.

L8. Verification commands observed: both `nix build --no-update-lock-file 'path:.#opencode-npm-packages-v2' 'path:.#browsermcp-v2' --no-link --print-out-paths` passed with install checks (OpenCode output xhdh95j2xda2ya3awyl72gjdxqps40sn, BrowserMCP zg73zny4c520wflh8c2spwgqsf9ks98y). `go -C pkgs/nixos-scripts test ./...` and `vet ./...` passed. `nix flake check --no-update-lock-file path:. --no-build` passed; standalone Home Manager evaluation passed for rog/t14/thinkcentre. macm5 system and home evaluations failed because existing Gentle AI asset rendering requires an aarch64-darwin derivation on this x86_64-linux host; compatible-host proof remains pending. No live browser-extension integration or system activation tested. Native risk assessment returned high/unassessable pending explicit untracked inventory; RDD globally on. Independent verification required before native review. Task mirror initial snapshot stored as Engram #4668; newer log synchronization pending.

L9. Independent verification (scratch `/tmp/opencode/npm-verify-4kVGLG`): no change-caused blockers. Final post-deletion sources built with install checks: OpenCode `/nix/store/dcvvz7jxrlb8d6266p683p3pfzzj5fza-opencode-npm-packages-v2-2.0.14`, BrowserMCP `/nix/store/15zhlz9jh6bnhhw21nzpwahxjkvxh7l4-browsermcp-v2-0.1.3`. Exact comparison confirmed all 22 baseline versions/integrities; 56 non-upgrade command-step snapshots identical. Public CLI probes proved rejected/npm-failing commands preserve isolated lock hashes, native stderr/exit 9 and 7 propagate, successful npm writes survive later flake failure as documented, OpenCode lock never changes. Baseline reproduces Darwin evaluation failure. Parent persisted verifier CLI probes as upgrade_integration_test.go with normal formatting and checked I/O errors. Review pending; no commit or activation authorized. Risk: items 2, 3, 5 (BrowserMCP port-safety behavior, shared CLI semantics, dependency packaging). Documentation and task are English apart from verbatim user requirements.

L10. Native review closure: user selected "Revisar este cambio". Exact granted START for target sha256:1d616fc1f9091be1060e8785e158a383a46249bdc782118e41118ff9b1ad0235 returned lens_context_budget_exceeded, mutation_outcome not_started, no review authority. User selected "Reportar y continuar", then wrote "conitnua". Completed open/closed lookup found equivalent tracker #5356; no relevant published stable fix verified. One privacy-scrubbed occurrence comment confirmed with exact readback: https://github.com/Gentleman-Programming/gentle-ai/issues/5356#issuecomment-6420453708; no labels/states changed. Exact captured decline invoked once and validated action=declined, consent=declined_this_candidate, matching target. Negotiated STATUS re-entered; no new START was executed because this candidate was explicitly skipped. Global review remains enabled. Native review is unavailable/skipped, not approved; functional and independent verification remain separate evidence. New integration regression passed and both final installed check scripts were rerun successfully by parent. Only this passive log changed after the reviewed candidate snapshot. No stage, commit, push, configuration activation, service restart, or runtime upgrade occurred. Darwin and live-extension checks remain pending; delivery requires separate authorization. Engram mirror final synchronization pending.

L11. Delivery authorization (2026-10-26, verbatim): "deja todo en master", followed by "si. dejalo lisot con push y comit y todo" in response to explicit confirmation of staging, committing, and integrating this delivery into local master. Push is now explicitly authorized too; no activation or runtime upgrades. Main worktree initially clean at 06b1ede8, feature HEAD b9f487b4, two master-only commits; preserve both histories without rebase or force push. One coherent feature commit contains packaging, CLI, tests and documentation. Existing candidate review was explicitly declined after budget refusal; delivery authorization does not fabricate review approval.
