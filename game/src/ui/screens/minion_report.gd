extends Screen
## Screen 28 — minion return report. Mock chunk 28: dimmed dispatch ghost rows
## behind a gold-green modal: face pop-in, "<NAME>'S BACK!", personality quote,
## haul / salvage / rumor rows (staggered pop-in), COLLECT CTA.

# One-off mock colors (not in Tokens).
const DIM_BG := Color("#0d1017")
const SALVAGE_PERK := Color("#5d9df0")  # salvage perk line blue

const MODAL_X := 18.0
const MODAL_Y := 200.0
const MODAL_W := 366.0


func build() -> void:
	add_bg(DIM_BG)
	_build_ghost_rows()
	_build_modal()


func _build_ghost_rows() -> void:
	# The dispatch screen dimmed behind the modal (mock: two 25%-opacity cards).
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.25
	UI.place(self, holder, Vector2.ZERO, DESIGN_SIZE)
	UI.place(holder, ChunkyRect.panel(Tokens.BG_CARD, 14.0), Vector2(14, 56), Vector2(374, 60))
	UI.place(holder, ChunkyRect.panel(Tokens.BG_CARD, 14.0), Vector2(14, 125), Vector2(374, 60))


func _build_modal() -> void:
	var report: Dictionary = GameState.minion_report
	var minion := Catalog.minion(String(report["minion"]))

	var modal := ModalPanel.make(Tokens.GREEN_GRAD_TOP, MODAL_W)
	UI.place(self, modal, Vector2(MODAL_X, MODAL_Y))
	# Mock's celebration variant: deeper hard shadow + green glow, 18px v-padding.
	var body := modal.get_child(0) as ChunkyRect
	body.shadow_offset = Vector2(0, 10)
	body.glow_color = Color(Tokens.GREEN_GRAD_TOP, 0.25)
	body.glow_size = 12.0
	var pad := modal.get_child(1) as MarginContainer
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	modal.content.add_theme_constant_override("separation", 11)

	_build_header(modal.content, minion)

	var haul := _haul_row(report)
	modal.content.add_child(haul)
	pop_in(haul, 0.2)

	var salvage := _salvage_row(report)
	modal.content.add_child(salvage)
	pop_in(salvage, 0.35)

	var rumor := _rumor_row(Dictionary(report["rumor"]))
	modal.content.add_child(rumor)
	pop_in(rumor, 0.5)

	# "COLLECT · SEND HIM OUT AGAIN" is mock copy not present in Catalog.COPY.
	var cta := ChunkyButton.make("COLLECT · SEND HIM OUT AGAIN", "cta_cyan",
		Vector2(0, 46), 14)
	cta.pressed.connect(func() -> void: Router.go("minion_dispatch"))
	modal.content.add_child(cta)


func _build_header(into: VBoxContainer, minion: Dictionary) -> void:
	var col := UI.vbox(6, BoxContainer.ALIGNMENT_CENTER)
	into.add_child(col)

	# 74px face, green 3px ring + outer dark-green halo ring (box-shadow).
	var face_wrap := Control.new()
	face_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_wrap.custom_minimum_size = Vector2(80, 80)
	face_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var halo := ChunkyRect.panel(Color(0, 0, 0, 0), 40.0, Tokens.GREEN_SHADOW, 3.0)
	UI.fill(face_wrap, halo)
	UI.place(face_wrap, AvatarFace.make(String(minion["face"]), 74,
		Tokens.GREEN_GRAD_TOP, 3.0), Vector2(3, 3))
	col.add_child(face_wrap)
	pop_in(face_wrap)

	var title := UI.display("%s'S BACK!" % String(minion["name"]).to_upper(), 22,
		Tokens.GREEN_GRAD_TOP)
	title.rotation_degrees = -1.0
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(title)

	var quotes: Array = minion["quotes"]
	var quote := UI.wrap(UI.centered(_italic_body("\"%s\"" % String(quotes[0]), 10,
		Tokens.white(0.55))))
	col.add_child(quote)


func _haul_row(report: Dictionary) -> Control:
	var row := _row_base(Color(0, 0, 0, 0))
	row.hbox.add_child(_row_emoji("🪵"))
	var label := UI.body(String(report["haul_line"]), 11, Tokens.white(0.75), 700)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.hbox.add_child(label)
	var amount := UI.display("+%d" % int(report["haul_materials"]), 14, Tokens.GREEN_GRAD_TOP)
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.hbox.add_child(amount)
	return row.root


func _salvage_row(report: Dictionary) -> Control:
	var row := _row_base(Tokens.RARITY_RARE)
	row.hbox.add_child(_row_emoji("⚙️"))
	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UI.body(String(report["salvage_label"]), 11, Color.WHITE, 700))
	col.add_child(UI.body(String(Catalog.item(String(report["salvage_item"]))["effect_line"]),
		9, SALVAGE_PERK, 800))
	row.hbox.add_child(col)
	return row.root


func _rumor_row(rumor: Dictionary) -> Control:
	var row := _row_base(Tokens.WARNING)
	row.hbox.add_child(_row_emoji("👂"))
	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UI.wrap(UI.body(String(rumor["line"]), 11, Color.WHITE, 700)))
	col.add_child(UI.body(String(rumor["eta_line"]), 9, Tokens.WARNING, 800))
	row.hbox.add_child(col)

	var view := BaseButton.new()
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.fill(view, ChunkyRect.panel(Tokens.BG_CARD, 10.0, Tokens.BORDER, 2.0))
	var view_pad := UI.margin(10, 5)
	UI.fill(view, view_pad)
	var view_label := UI.display(String(rumor["cta"]), 10, Tokens.CYAN_LIGHT)
	view_pad.add_child(view_label)
	# Pre-tree label measures use the 16px default font (theme overrides don't
	# resolve outside the tree); remeasure once the tree settles.
	(func() -> void:
		view.custom_minimum_size = view_label.get_combined_minimum_size() + Vector2(20, 10)
	).call_deferred()
	view.pressed.connect(func() -> void: Router.go("defense_view"))
	row.hbox.add_child(view)
	return row.root


class _Row:
	var root: Control
	var hbox: HBoxContainer


## Inset report row (BG_INSET, radius 11, 9×11 padding, optional accent border).
## PanelContainer so the row hugs its content height (like ModalPanel).
func _row_base(border: Color) -> _Row:
	var out := _Row.new()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ChunkyRect.new()
	rect.fill_top = Tokens.BG_INSET
	rect.corner_radius = 11.0
	if border.a > 0.0:
		rect.border_color = border
		rect.border_width = 2.0
	panel.add_child(rect)
	var pad := UI.margin(11, 9)
	panel.add_child(pad)
	out.hbox = UI.hbox(9)
	pad.add_child(out.hbox)
	out.root = panel
	return out


func _row_emoji(glyph: String) -> Label:
	var e := UI.body(glyph, 15)
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return e


## Faux italic (mock: italic quote): Nunito has no ital axis, shear the glyphs.
func _italic_body(text: String, size: int, color: Color) -> Label:
	var l := UI.body(text, size, color, 700)
	var fv := FontVariation.new()
	fv.base_font = Tokens.body_font(700)
	fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.25, 1), Vector2.ZERO)
	l.add_theme_font_override("font", fv)
	return l
