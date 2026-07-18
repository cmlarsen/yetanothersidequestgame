extends Screen
## Splash (chunk 01): radial key-art backdrop, stacked rotated logo, tagline,
## decorative TAP TO START pill. The whole screen taps → location permission.

# One-off mock colors (screen-specific radial bg + placeholder label).
const _BG_CENTER := Color("#1a3a52")
const _BG_EDGE := Color("#0e1420")
const _PLACEHOLDER_TEXT := Color("#5d9df0")


func build() -> void:
	UI.fill(self, _RadialBg.new(_BG_CENTER, _BG_EDGE))

	var ph := Placeholder3D.make(Vector2(190, 190), "3D KEY ART")
	_restyle_placeholder(ph)
	UI.place(self, ph, Vector2(106, 80))

	# Soft cyan halo behind SIDEQUEST (mock: text-shadow 0 0 34px cyan .5).
	var glow := _glow_rect()
	UI.place(self, glow, Vector2(21, 292), Vector2(360, 128))

	var logo := Control.new()
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, logo, Vector2(0, 302), Vector2(402, 78))
	logo.pivot_offset = Vector2(201, 39)
	logo.rotation_degrees = -2.0
	UI.place_centered_x(logo, _display_spaced("YET ANOTHER", 20, Tokens.white(0.55), 2), 0)
	var title := _display_spaced("SIDEQUEST", 46, Tokens.CYAN, 1)
	UI.shadowed(title, Tokens.CYAN_SHADOW, 4)
	UI.place_centered_x(logo, title, 19)

	UI.place_centered_x(self,
		UI.body(Catalog.COPY["splash_tagline"], 12, Tokens.white(0.5)), 392)

	# Whole screen is the tap target; the pill on top is decorative but routes
	# too so a press on it still advances.
	var tap := BaseButton.new()
	UI.fill(self, tap)
	tap.pressed.connect(func() -> void: Router.go("location_permission"))

	var cta := ChunkyButton.make(Catalog.COPY["splash_cta"], "cta_cyan",
		Vector2(300, 50), 15)
	UI.place_centered_x(self, cta, 738)
	cta.pressed.connect(func() -> void: Router.go("location_permission"))

	UI.place_centered_x(self,
		UI.body(Catalog.COPY["splash_footer"], 9, Tokens.white(0.3), 600), 800)


## Placeholder3D defaults → the splash mock's blue variant (dashed #45607f 3px,
## radius 28, faint cyan fill, blue 9px two-line label). Children are the kit's
## box ChunkyRect then the centered label.
static func _restyle_placeholder(ph: Control) -> void:
	var box := ph.get_child(0) as ChunkyRect
	box.border_color = Tokens.SLOT_BORDER
	box.border_width = 3.0
	box.corner_radius = 28.0
	box.fill_top = Color(Tokens.CYAN, 0.05)
	var label := ph.get_child(1) as Label
	label.text = "3D KEY ART\n(hero on a hex)"
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", _PLACEHOLDER_TEXT)
	label.add_theme_constant_override("line_spacing", 4)


static func _display_spaced(text: String, size: int, color: Color, spacing: int) -> Label:
	var l := UI.display(text, size, color)
	var fv := FontVariation.new()
	fv.base_font = Tokens.display_font()
	fv.spacing_glyph = spacing
	l.add_theme_font_override("font", fv)
	return l


static func _glow_rect() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(Tokens.CYAN, 0.22))
	g.set_color(1, Color(Tokens.CYAN, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 128
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## CSS radial-gradient(circle at 50% 30%, center → edge at 70% farthest-corner),
## approximated with concentric interpolated circles.
class _RadialBg:
	extends Control

	const _STEPS := 140
	const _CENTER := Vector2(201.0, 262.2)
	const _END_RADIUS := 450.7

	var _c0: Color
	var _c1: Color

	func _init(c0: Color, c1: Color) -> void:
		_c0 = c0
		_c1 = c1
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), _c1)
		for i in range(_STEPS, 0, -1):
			var t := float(i) / _STEPS
			draw_circle(_CENTER, _END_RADIUS * t, _c0.lerp(_c1, t))
