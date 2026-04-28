# Layered Assets Specification

## Purpose

Define how local modifications (21 skills, persona rules) are applied as a layer on top of the vanilla upstream base, ensuring clear separation between upstream and local content.

## Requirements

### Requirement: Vanilla Base Import

The `default.nix` derivation MUST import the vanilla derivation as its base, not duplicate upstream copy logic inline.

#### Scenario: Default imports vanilla derivation

- GIVEN `pkgs/gentle-ai-assets/default.nix` is evaluated
- WHEN inspecting its source
- THEN it references `vanilla.nix` or the vanilla derivation as its upstream base
- AND it does NOT contain inline `cp $src/...` commands for upstream assets

### Requirement: Local Skills Overlay

All 21 local skills from `modules/home/opencode/skills/` MUST be present in the final output, overlaid on top of upstream skills. Local skills with the same name as upstream skills MUST override the upstream version.

#### Scenario: All local skills are included

- GIVEN 21 local skills exist in `modules/home/opencode/skills/`
- WHEN `gentle-ai-assets` is built
- THEN all 21 skill directories are present under `$out/share/gentle-ai/skills/`

#### Scenario: Local skill overrides upstream skill with same name

- GIVEN a local skill has the same name as an upstream skill (e.g., `caveman`)
- WHEN the layered derivation completes
- THEN the local version is present in the output, not the upstream version

### Requirement: No Plugin Layering

The layered derivation MUST NOT modify, override, or add to the `opencode/plugins/` directory from the vanilla base. Plugins are handled separately: upstream plugins come from vanilla, local-only plugins (e.g., `engram.ts`) are copied by the activation script.

### Requirement: Persona Rules Merge

Local persona rules MUST be prepended to the upstream `persona-gentleman.md` file, preserving both local rules and upstream content.

#### Scenario: Combined persona contains both local and upstream rules

- GIVEN local persona rules exist (English-only code, no emojis)
- AND upstream provides `persona-gentleman.md`
- WHEN the derivation completes
- THEN `$out/share/gentle-ai/opencode/persona-gentleman.md` contains local rules first, followed by upstream content

#### Scenario: Persona fallback when upstream is missing

- GIVEN upstream does NOT provide `persona-gentleman.md`
- WHEN the derivation completes
- THEN the output contains only the local persona rules
- AND the build does not fail

### Requirement: Composition Method

The layering MUST use a clean Nix composition method (`symlinkJoin`, `runCommand`, or similar) that does not modify the vanilla derivation's output.

#### Scenario: Vanilla output is not mutated

- GIVEN the vanilla derivation produces output at path V
- AND the layered derivation produces output at path L
- WHEN comparing V and L
- THEN V remains unchanged (read-only, not modified by layering)
- AND L contains the merged result
