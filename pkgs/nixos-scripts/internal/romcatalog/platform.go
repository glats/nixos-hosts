// Package romcatalog serves a browsable catalog of ROM files and downloads
// the selected ones into the emulator library.
package romcatalog

import "strings"

// Platform describes one emulated system: how RomM names it, which libretro
// cores run it, which files count as a ROM, and how a source is asked for its
// games.
type Platform struct {
	// Slug is the canonical RomM platform slug.
	Slug string
	// Dir is the library folder the downloads are written to. It differs from
	// Slug only where the library already uses an alias folder name.
	Dir string
	// Name is the display name.
	Name string
	// Cores are the libretro cores that run this platform.
	Cores []string
	// Extensions are the accepted ROM file extensions, lowercase and with dot.
	Extensions []string
	// Queries are the search terms a source uses for this platform.
	Queries []string
	// Thumbnails is the libretro thumbnail collection that holds the cover
	// art of this platform, empty when there is none.
	Thumbnails string
}

// CoverURL returns the libretro thumbnail URL for a game title, empty when
// the platform has no thumbnail collection.
func (p Platform) CoverURL(title string) string {
	if p.Thumbnails == "" || title == "" {
		return ""
	}
	return "https://thumbnails.libretro.com/" +
		strings.ReplaceAll(p.Thumbnails, " ", "%20") +
		"/Named_Boxarts/" +
		strings.ReplaceAll(title, " ", "%20") + ".png"
}

// Accepts reports whether name looks like a ROM file for this platform.
func (p Platform) Accepts(name string) bool {
	lower := strings.ToLower(name)
	for _, ext := range p.Extensions {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}

// platforms is the catalog of supported systems. Dir defaults to Slug; the
// Genesis keeps the "megadrive" folder the library already uses.
var platforms = []Platform{
	{
		Slug:       "nes",
		Thumbnails: "Nintendo - Nintendo Entertainment System", Name: "Nintendo Entertainment System",
		Cores:      []string{"fceumm", "nestopia"},
		Extensions: []string{".nes", ".unf", ".unif"},
		Queries:    []string{"Nintendo Entertainment System", "NES"},
	},
	{
		Slug:       "snes",
		Thumbnails: "Nintendo - Super Nintendo Entertainment System", Name: "Super Nintendo Entertainment System",
		Cores:      []string{"snes9x", "bsnes"},
		Extensions: []string{".sfc", ".smc", ".smd", ".fig", ".swc"},
		Queries:    []string{"Super Nintendo Entertainment System", "SNES"},
	},
	{
		Slug:       "gb",
		Thumbnails: "Nintendo - Game Boy", Name: "Nintendo Game Boy",
		Cores:      []string{"gambatte"},
		Extensions: []string{".gb"},
		Queries:    []string{"Nintendo Game Boy"},
	},
	{
		Slug:       "gbc",
		Thumbnails: "Nintendo - Game Boy Color", Name: "Nintendo Game Boy Color",
		Cores:      []string{"gambatte"},
		Extensions: []string{".gbc"},
		Queries:    []string{"Nintendo Game Boy Color"},
	},
	{
		Slug:       "gba",
		Thumbnails: "Nintendo - Game Boy Advance", Name: "Nintendo Game Boy Advance",
		Cores:      []string{"mgba"},
		Extensions: []string{".gba"},
		Queries:    []string{"Nintendo Game Boy Advance", "GBA"},
	},
	{
		Slug:       "genesis",
		Thumbnails: "Sega - Mega Drive - Genesis", Dir: "megadrive", Name: "Sega Mega Drive / Genesis",
		Cores:      []string{"genesis_plus_gx"},
		Extensions: []string{".md", ".gen", ".bin", ".smd"},
		Queries:    []string{"Sega Mega Drive Genesis", "Mega Drive"},
	},
	{
		Slug:       "n64",
		Thumbnails: "Nintendo - Nintendo 64", Name: "Nintendo 64",
		Cores:      []string{"mupen64plus_next", "parallel_n64"},
		Extensions: []string{".n64", ".z64", ".v64", ".u1", ".ndd"},
		Queries:    []string{"Nintendo 64", "N64"},
	},
	{
		Slug:       "nds",
		Thumbnails: "Nintendo - Nintendo DS", Name: "Nintendo DS",
		Cores:      []string{"melonds", "desmume"},
		Extensions: []string{".nds", ".dsi"},
		Queries:    []string{"Nintendo DS", "NDS"},
	},
	{
		Slug:       "psx",
		Thumbnails: "Sony - PlayStation", Name: "Sony PlayStation",
		Cores:      []string{"pcsx_rearmed", "mednafen_psx_hw"},
		Extensions: []string{".chd", ".cue", ".bin", ".pbp", ".img"},
		Queries:    []string{"Sony PlayStation", "PlayStation"},
	},
	{
		Slug: "ps2", Name: "Sony PlayStation 2",
		Cores:      []string{"pcsx2"},
		Extensions: []string{".iso", ".chd", ".bin"},
		Queries:    []string{"Sony PlayStation 2", "PlayStation 2"},
	},
	{
		Slug:       "psp",
		Thumbnails: "Sony - PlayStation Portable", Name: "Sony PlayStation Portable",
		Cores:      []string{"ppsspp"},
		Extensions: []string{".iso", ".cso", ".pbp", ".chd"},
		Queries:    []string{"Sony PlayStation Portable", "PSP"},
	},
	{
		Slug:       "ngc",
		Thumbnails: "Nintendo - GameCube", Name: "Nintendo GameCube",
		Cores:      []string{"dolphin"},
		Extensions: []string{".iso", ".gcm", ".rvz", ".wbfs"},
		Queries:    []string{"Nintendo GameCube", "GameCube"},
	},
	{
		Slug:       "wii",
		Thumbnails: "Nintendo - Wii", Name: "Nintendo Wii",
		Cores:      []string{"dolphin"},
		Extensions: []string{".wbfs", ".iso", ".rvz"},
		Queries:    []string{"Nintendo Wii"},
	},
	{
		Slug:       "n3ds",
		Thumbnails: "Nintendo - Nintendo 3DS", Name: "Nintendo 3DS",
		Cores:      []string{"azahar"},
		Extensions: []string{".3ds", ".cia", ".cci"},
		Queries:    []string{"Nintendo 3DS", "3DS"},
	},
	{
		Slug:       "saturn",
		Thumbnails: "Sega - Saturn", Name: "Sega Saturn",
		Cores:      []string{"yabause"},
		Extensions: []string{".cue", ".bin", ".mds", ".chd"},
		Queries:    []string{"Sega Saturn", "Saturn"},
	},
	{
		Slug:       "dc",
		Thumbnails: "Sega - Dreamcast", Name: "Sega Dreamcast",
		Cores:      []string{"flycast"},
		Extensions: []string{".chd", ".gdi", ".cue", ".iso"},
		Queries:    []string{"Sega Dreamcast", "Dreamcast"},
	},
	{
		Slug: "switch", Name: "Nintendo Switch",
		Cores:      []string{"yuzu", "ryujinx"},
		Extensions: []string{".nsp", ".xci", ".nsz"},
		Queries:    []string{"Nintendo Switch"},
	},
	{
		Slug: "psvita", Name: "Sony PlayStation Vita",
		Cores:      []string{"vita3k"},
		Extensions: []string{".vpkg"},
		Queries:    []string{"Sony PlayStation Vita", "PS Vita"},
	},
	{
		Slug: "arcade", Name: "Arcade",
		Cores:      []string{"fbneo", "mame2003_plus"},
		Extensions: []string{".zip", ".7z"},
		Queries:    []string{"MAME arcade", "FBNeo"},
	},
	{
		Slug:       "atari2600",
		Thumbnails: "Atari - 2600", Name: "Atari 2600",
		Cores:      []string{"stella2014"},
		Extensions: []string{".a26", ".bin"},
		Queries:    []string{"Atari 2600"},
	},
	{
		Slug:       "lynx",
		Thumbnails: "Atari - Lynx", Name: "Atari Lynx",
		Cores:      []string{"handy"},
		Extensions: []string{".lnx", ".lyx"},
		Queries:    []string{"Atari Lynx"},
	},
	{
		Slug: "ngage", Name: "Nokia N-Gage",
		Cores:      []string{"eka2l1"},
		Extensions: []string{".ngage", ".vpl"},
		Queries:    []string{"Nokia N-Gage"},
	},
}

// Platforms returns every supported platform.
func Platforms() []Platform {
	out := make([]Platform, len(platforms))
	copy(out, platforms)
	return out
}

// PlatformBySlug returns the platform with the given slug.
func PlatformBySlug(slug string) (Platform, bool) {
	for _, p := range platforms {
		if p.Slug == slug {
			return p, true
		}
	}
	return Platform{}, false
}

// PlatformByDir returns the platform whose library folder is dir, which may be
// the canonical slug or an alias folder name such as "megadrive".
func PlatformByDir(dir string) (Platform, bool) {
	for _, p := range platforms {
		if p.Dir == dir || p.Slug == dir {
			return p, true
		}
	}
	return Platform{}, false
}
