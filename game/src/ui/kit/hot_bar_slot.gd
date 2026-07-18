class_name HotBarSlot
extends Control
## One 60×60 hot-bar slot (combat/equip mocks): gradient tile, chunky border,
## hard shadow, icon/emoji, plus state dressing — cooldown conic pie + seconds,
## dashed empty, dimmed locked, charges badge, glow border, top text badge —
## and the micro name label underneath.

const SLOT_SIDE := 60.0
const SLOT_RADIUS := 16.0
const _LABEL_Y := 68.0
const _TOTAL_HEIGHT := 80.0


## cfg keys: emoji|icon, label, state (ready|cooldown|empty|locked),
## cooldown_left, cooldown_frac, charges, glow, border, badge, badge_bg,
## badge_color. See kit README.
static func make(cfg: Dictionary) -> HotBarSlot:
	var s := HotBarSlot.new()
	s.custom_minimum_size = Vector2(SLOT_SIDE, _TOTAL_HEIGHT)
	s.size = Vector2(SLOT_SIDE, _TOTAL_HEIGHT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var state := String(cfg.get("state", "ready"))
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(s, slot, Vector2.ZERO, Vector2(SLOT_SIDE, SLOT_SIDE))
	if state == "empty":
		s._build_empty(slot)
	else:
		s._build_filled(slot, cfg, state)
	if state == "locked":
		slot.modulate = Tokens.white(0.6)
	if cfg.has("charges"):
		s._add_charges(slot, int(cfg["charges"]))
	if cfg.has("badge"):
		s._add_badge(slot, String(cfg["badge"]),
			cfg.get("badge_bg", Tokens.CYAN), cfg.get("badge_color", Tokens.ON_CYAN))
	if cfg.has("label"):
		var lbl := UI.micro(String(cfg["label"]), 8, Tokens.white(0.65))
		UI.place_centered_x(s, lbl, _LABEL_Y)
	return s


func _build_empty(slot: Control) -> void:
	var rect := ChunkyRect.panel(Color(Tokens.SLOT_GRAD_BOTTOM, 0.55), SLOT_RADIUS,
		Tokens.SLOT_BORDER, 3.0)
	rect.dashed = true
	UI.fill(slot, rect)
	var plus := UI.display("+", 20, Tokens.white(0.4))
	_center_in(slot, plus)


func _build_filled(slot: Control, cfg: Dictionary, state: String) -> void:
	var border: Color = cfg.get("border", Tokens.SLOT_BORDER)
	var rect := ChunkyRect.panel(Tokens.SLOT_GRAD_TOP, SLOT_RADIUS, border, 3.0,
		Tokens.SLOT_SHADOW).with_gradient(Tokens.SLOT_GRAD_TOP, Tokens.SLOT_GRAD_BOTTOM)
	if cfg.has("glow"):
		var glow: Color = cfg["glow"]
		rect.border_color = glow
		rect.glow_color = Color(glow, 0.55)
		rect.glow_size = 9.0
	UI.fill(slot, rect)

	var art: Control = null
	if cfg.has("emoji"):
		art = UI.body(String(cfg["emoji"]), 24)
		_center_in(slot, art)
	elif cfg.has("icon"):
		art = Icons.rect(String(cfg["icon"]), 26, cfg.get("icon_color", Tokens.white(0.92)), 2.3)
		UI.place(slot, art, Vector2((SLOT_SIDE - 26.0) / 2.0, (SLOT_SIDE - 26.0) / 2.0))

	match state:
		"cooldown":
			if art != null:
				art.modulate = Tokens.white(0.6)
			var left := float(cfg.get("cooldown_left", 0.0))
			# Sweep fraction: explicit override, else remaining seconds over the
			# mock's implied 10 s max (4.1 s → 148°, matching the 150° mock pie).
			var frac := float(cfg.get("cooldown_frac", clampf(left / 10.0, 0.0, 1.0)))
			var pie := CooldownPie.new()
			pie.fraction = frac
			UI.fill(slot, pie)
			var secs := UI.display("%.1fs" % left, 15)
			_center_in(slot, secs)
		"locked":
			if art != null:
				art.modulate = Tokens.white(0.3)
			UI.place(slot, Icons.rect("lock", 22, Tokens.white(0.85)),
				Vector2((SLOT_SIDE - 22.0) / 2.0, (SLOT_SIDE - 22.0) / 2.0))


func _add_charges(slot: Control, charges: int) -> void:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(slot, chip, Vector2(SLOT_SIDE - 14.0, -6.0), Vector2(20, 20))
	var bg := ChunkyRect.panel(Tokens.PINK, 10.0, Tokens.BG_PANEL, 2.0)
	UI.fill(chip, bg)
	var n := UI.body(str(charges), 10, Color.WHITE, 800)
	_center_in(chip, n)


func _add_badge(slot: Control, text: String, bg_color: Color, text_color: Color) -> void:
	var lbl := UI.body(text, 9, text_color, 800)
	var w := lbl.get_minimum_size().x + 16.0
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(slot, chip, Vector2((SLOT_SIDE - w) / 2.0, -10.0), Vector2(w, 17.0))
	UI.fill(chip, ChunkyRect.panel(bg_color, 6.0))
	_center_in(chip, lbl)


static func _center_in(parent: Control, lbl: Label) -> void:
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(parent, lbl)


## Dark conic sweep for the remaining cooldown (mock: conic-gradient overlay
## clipped to the slot's rounded rect).
class CooldownPie:
	extends Control

	const _DARK := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.82)

	var fraction: float = 0.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if fraction <= 0.0 or size.x <= 0.0:
			return
		var r := HotBarSlot.SLOT_RADIUS
		var rr := ChunkyRect.rounded_points(Rect2(Vector2.ZERO, size), Vector4(r, r, r, r))
		if fraction >= 1.0:
			draw_colored_polygon(rr, _DARK)
			return
		var c := size / 2.0
		var wedge := PackedVector2Array()
		wedge.append(c)
		var steps := maxi(2, int(ceil(32.0 * fraction)))
		var reach := size.length()
		for i in steps + 1:
			var a := -PI / 2.0 + TAU * fraction * float(i) / steps
			wedge.append(c + Vector2(cos(a), sin(a)) * reach)
		for poly in Geometry2D.intersect_polygons(rr, wedge):
			draw_colored_polygon(poly, _DARK)
