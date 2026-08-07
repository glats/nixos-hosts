---
name: rom-downloader
description: "Trigger: download ROM, bajar rom, bájame, descargar juego, get ROM. Download retro game ROMs from reliable sources into the KNULLI folder structure."
license: Apache-2.0
metadata:
  author: glats
  version: "1.0"
---

## Activation Contract

Load when user asks to download a retro game ROM. If platform not specified, ask: "What platform? (NES, SNES, N64, GB, GBC, GBA, NDS, Genesis, PSX, Arcade)".

## Hard Rules

- NEVER use Romarr or Grabarr. They are removed and unreliable.
- Place ROMs directly into `/run/media/library/roms/{slug}/`.
- For PSX: prefer `.chd`. Reject `.cue`-only downloads.
- Verify downloaded file is not HTML (check with `file` command, size > 100KB).
- Keep folder flat: `roms/{slug}/file.ext`. No subdirectories.

## Platform Slugs

| Platform | KNULLI folder | Format |
|----------|--------------|--------|
| NES | `nes` | `.nes`, `.zip` |
| SNES | `snes` | `.sfc`, `.zip` |
| N64 | `n64` | `.z64`, `.n64` |
| GB | `gb` | `.gb`, `.zip` |
| GBC | `gbc` | `.gbc`, `.zip` |
| GBA | `gba` | `.gba`, `.zip` |
| NDS | `nds` | `.nds` |
| Genesis/MD | `megadrive` | `.md`, `.zip` |
| PSX | `psx` | `.chd` (preferred) |
| Arcade | `arcade` | `.zip` |

## Source Priority

Search in order. Try next source if current fails.

1. **Edge Emulation** — fastest, no auth. `https://edgeemu.net/download/{slug}/{filename}.zip`
2. **Internet Archive** — largest. `https://archive.org/download/{collection}/{filename}`
3. **MiNERVA** — most complete, torrent-based. Use aria2c with `--select-file`.

## Execution Steps

1. Ask platform if not provided. Resolve to KNULLI slug from table.
2. Ensure target directory exists: `mkdir -p /run/media/library/roms/{slug}`.
3. Search Edge Emulation first. Construct URL with system slug and game name.
4. Download: `curl -L -o "/run/media/library/roms/{slug}/{filename}" "{url}"`.
5. Verify: `file {path}` should show ROM data, not HTML.
6. Report: "Downloaded {title} ({platform}) — {size} from {source} → roms/{slug}/"

## References

- `references/sources.md` — URL templates, IA collections, MiNERVA paths.
- `references/edge-emu-slugs.md` — Edge Emulation system slug mapping.
