class_name Tokens
## Design tokens from docs/design/yas-v1/README.md — the single source of truth
## for UI chrome. Screens must reference these, never re-declare hex literals.

# ── Surfaces ────────────────────────────────────────────────────────────────
const BG_CANVAS := Color("#101319")
const BG_SCREEN := Color("#151a26")
const BG_PANEL := Color("#141a28")
const BG_CARD := Color("#1b2130")
const BG_INSET := Color("#0b0f18")
const BORDER := Color("#2c3852")

# ── Primary cyan ────────────────────────────────────────────────────────────
const CYAN := Color("#45d6f4")
const CYAN_LIGHT := Color("#7ee7fb")
const CYAN_GRAD_TOP := Color("#63e2f8")
const CYAN_GRAD_BOTTOM := Color("#1fa9cc")
const ON_CYAN := Color("#083240")
const CYAN_SHADOW := Color("#12586b")

# ── Success green ───────────────────────────────────────────────────────────
const GREEN_GRAD_TOP := Color("#7ce843")
const GREEN_GRAD_BOTTOM := Color("#3aa74e")
const ON_GREEN := Color("#0e2a10")
const GREEN_SHADOW := Color("#2a6a1e")

# ── Gold ────────────────────────────────────────────────────────────────────
const GOLD_GRAD_TOP := Color("#ffd75e")
const GOLD_GRAD_BOTTOM := Color("#f2a92e")
const GOLD_BORDER := Color("#9c6b12")
const ON_GOLD := Color("#4a3305")
const ON_GOLD_ALT := Color("#5c3f06")
const GOLD_SHADOW := Color("#b8891a")
const WARNING := Color("#ffc93c")

# ── Danger / pink ───────────────────────────────────────────────────────────
const RED_GRAD_TOP := Color("#ff7a5c")
const RED_GRAD_BOTTOM := Color("#e0342e")
const RED_SHADOW := Color("#8a1a16")
const PINK := Color("#ff5f8a")
const PINK_LIGHT := Color("#ff8fb0")

# ── Gloomling purple ────────────────────────────────────────────────────────
const GLOOM_GRAD_TOP := Color("#9a63f0")
const GLOOM_GRAD_BOTTOM := Color("#5c26b8")
const GLOOM_BORDER := Color("#3c1685")
const GLOOM_BORDER_ALT := Color("#4a2591")
const GLOOM_LIGHT := Color("#d9b8ff")
const GLOOM_LIGHT_ALT := Color("#c9a2ff")
const GLOOM_HEX := Color("#a163ff")

# ── Rarity ──────────────────────────────────────────────────────────────────
const RARITY_COMMON := Color("#9aa5ba")
const RARITY_RARE := Color("#3f8ee8")
const RARITY_EPIC_TOP := Color("#c85cf0")
const RARITY_EPIC_BOTTOM := Color("#7a3fe0")
const RARITY_LEGENDARY_TOP := Color("#ffe27a")
const RARITY_LEGENDARY_BOTTOM := Color("#f2a92e")

# ── Map palette ─────────────────────────────────────────────────────────────
const MAP_GRASS := Color("#a4c53c")
const MAP_GRASS_ALT := Color("#8fb332")
const MAP_PATH := Color("#f0dda6")
const MAP_PATH_EDGE := Color("#d8bd80")
const MAP_TREE := Color("#2f8f4e")
const MAP_WATER := Color("#3aa7ee")
const PARCHMENT := Color("#f0dda6")
const ON_PARCHMENT := Color("#3a2c08")
const ON_PARCHMENT_MUTED := Color("#6b5518")
const TURF_PLAYER := Color("#27d3f5")
const TURF_GLOOM := Color(150.0 / 255.0, 80.0 / 255.0, 1.0, 0.28)

# ── Text helpers ────────────────────────────────────────────────────────────
static func white(alpha: float) -> Color:
	return Color(1.0, 1.0, 1.0, alpha)


# ── Fonts ───────────────────────────────────────────────────────────────────
# Lilita One: display/headings/buttons/numbers (uppercase labels).
# Nunito 600–900: body + micro-labels (micro = 800, 8–10px, letter-spaced).
static var _display: FontFile
static var _nunito: FontFile
static var _emoji: SystemFont
static var _variations: Dictionary = {}


static func _emoji_fallback() -> SystemFont:
	if _emoji == null:
		_emoji = SystemFont.new()
		_emoji.font_names = PackedStringArray(["Apple Color Emoji", "Noto Color Emoji"])
	return _emoji


static func display_font() -> Font:
	if _display == null:
		_display = load("res://assets/fonts/LilitaOne-Regular.ttf")
		_display.fallbacks = [_emoji_fallback()]
	return _display


static func _nunito_base() -> FontFile:
	if _nunito == null:
		_nunito = load("res://assets/fonts/Nunito-VariableFont.ttf")
		_nunito.fallbacks = [_emoji_fallback()]
	return _nunito


## Nunito at a given weight (600–900), with optional glyph letter-spacing in px.
static func body_font(weight: int = 700, letter_spacing: int = 0) -> Font:
	var key := "%d_%d" % [weight, letter_spacing]
	if not _variations.has(key):
		var fv := FontVariation.new()
		fv.base_font = _nunito_base()
		fv.variation_opentype = {"wght": weight}
		if letter_spacing != 0:
			fv.spacing_glyph = letter_spacing
		_variations[key] = fv
	return _variations[key]
