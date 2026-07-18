extends Screen
## Screen 26 — tower manage sheet. Mock chunk 26: hexC map dimmed to 35%,
## bottom sheet with tower header, durability warning card, target-priority
## pills, REPAIR/UPGRADE row, remote note + SALVAGE footer. Tapping the dimmed
## map dismisses (Router.back()).

# One-off mock colors (not in Tokens).
const SCREEN_BG := Color("#0e1420")
const CHILL_GRAD_TOP := Color("#a678ec")
const MEDAL_SHADOW := Color("#080c1480")  # rgba(8,12,20,.5)

const MEDAL_GRADS: Dictionary = {
	"bonk_turret": [Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM],
	"chill_bell": [CHILL_GRAD_TOP, Tokens.RARITY_EPIC_BOTTOM],
	"bastion_post": [Tokens.GOLD_GRAD_TOP, Tokens.GOLD_GRAD_BOTTOM],
}
const PRIORITY_KEYS: Array[String] = ["nearest", "strongest", "guard_home"]
const PRIORITY_LABELS: Array[String] = ["NEAREST", "STRONGEST", "GUARD HOME HEX"]

const SHEET_H := 336.0


func build() -> void:
	add_bg(SCREEN_BG)
	_build_map()
	var dismiss := BaseButton.new()
	UI.place(self, dismiss, Vector2.ZERO, Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - SHEET_H))
	dismiss.pressed.connect(func() -> void: Router.back())
	_build_sheet()


func _build_map() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.35
	UI.place(self, holder, Vector2.ZERO, DESIGN_SIZE)
	var panel_bg := ColorRect.new()
	panel_bg.color = Tokens.BG_PANEL
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(holder, panel_bg)
	UI.place(holder, HexGridMap.preset_c(), Vector2.ZERO)


func _build_sheet() -> void:
	var tower: Dictionary = GameState.towers[GameState.managed_tower_index]
	var info := Catalog.tower(String(tower["type"]))
	var front := GameState.front(String(tower["front_id"]))
	var pct := int(tower["durability_pct"])
	var level := int(tower["level"])

	var sheet := SheetPanel.make(Tokens.BORDER, SHEET_H)
	UI.place(self, sheet, Vector2(0, DESIGN_SIZE.y - SHEET_H))

	var head := UI.hbox(11)
	head.add_child(_medallion(String(tower["type"]), 58.0, 14.0, 26))
	var head_col := UI.vbox(2)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := UI.hbox(6)
	title.add_child(UI.display(String(info["name"]).to_upper(), 17))
	title.add_child(UI.display("LV %d" % level, 17, Tokens.GLOOM_LIGHT_ALT))
	head_col.add_child(title)
	head_col.add_child(UI.wrap(UI.body("%s front · placed %d days ago · %s" % [
		String(front["name"]), int(tower["placed_days_ago"]), String(info["effect_line"])],
		9, Tokens.white(0.5), 800)))
	head.add_child(head_col)
	sheet.content.add_child(head)

	sheet.content.add_child(_durability_card(pct))

	var priority_col := UI.vbox(6)
	priority_col.add_child(UI.micro("TARGET PRIORITY", 9, Tokens.white(0.4)))
	var active := PRIORITY_KEYS.find(String(tower["target_priority"]))
	var priority := TabRow.make(PRIORITY_LABELS, maxi(active, 0))
	_refit_tabs(priority)
	priority_col.add_child(priority)
	sheet.content.add_child(priority_col)

	var buttons := UI.hbox(8)
	var repair := ChunkyButton.make("REPAIR · 🪵 %d" % Rules.TOWER_REPAIR_COST,
		"cta_green", Vector2(0, 46), 13)
	_refit_button(repair)
	repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(repair)
	var upgrade := ChunkyButton.make("UPGRADE LV %d · 🪵 %d" % [level + 1,
		Rules.TOWER_UPGRADE_COST], "secondary", Vector2(0, 46), 12)
	_refit_button(upgrade)
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(upgrade)
	sheet.content.add_child(buttons)

	var footer := UI.hbox(0)
	footer.add_child(UI.body(String(Catalog.COPY["tower_remote_note"]), 9,
		Tokens.white(0.4), 800))
	footer.add_child(UI.spacer())
	var refund := Rules.tower_salvage_refund(int(info["cost"]))
	footer.add_child(UI.body("SALVAGE (🪵 %d back)" % refund, 9, Tokens.PINK, 800))
	sheet.content.add_child(footer)


func _durability_card(pct: int) -> Control:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(0, 62)
	UI.fill(card, ChunkyRect.panel(Tokens.BG_CARD, 13.0, Tokens.RED_GRAD_BOTTOM, 2.0))
	var pad := UI.margin(12, 10)
	UI.fill(card, pad)
	var col := UI.vbox(6)
	pad.add_child(col)
	var row := UI.hbox(0)
	# "falls to rubble at 0" is mock copy not present in Catalog/Rules.
	row.add_child(UI.body("⚠️ DURABILITY %d%% — falls to rubble at 0" % pct, 10,
		Tokens.PINK_LIGHT, 800))
	row.add_child(UI.spacer())
	# Mock pins "34 / 100": pct over the level-1 durability max (Rules'
	# tower_durability_max(2) = 125 disagrees with the mock's denominator).
	row.add_child(UI.display("%d / %d" % [pct, Rules.TOWER_DURABILITY_MAX], 12,
		Tokens.PINK_LIGHT))
	col.add_child(row)
	var bar := StatBarChunky.make(0, 10, Tokens.RED_GRAD_TOP, Tokens.RED_GRAD_BOTTOM,
		Tokens.BG_INSET, 6.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_ratio(pct / 100.0)
	col.add_child(bar)
	return card


## ChunkyButton/TabRow bake min widths from pre-tree measures, where the
## label's theme overrides don't resolve yet (16px default font) — the sheet's
## 366px column then overflows the frame. Remeasure once the tree settles.
static func _refit_button(b: ChunkyButton) -> void:
	var row := b.get_child(1).get_child(0) as Control
	(func() -> void:
		b.custom_minimum_size.x = row.get_combined_minimum_size().x + 36.0).call_deferred()


static func _refit_tabs(tabs: TabRow) -> void:
	(func() -> void:
		for b: Control in tabs.get_children():
			var label := b.get_child(1) as Control
			b.custom_minimum_size.x = maxf(44.0, label.get_combined_minimum_size().x + 28.0)
	).call_deferred()


func _medallion(id: String, side: float, radius: float, emoji_px: int) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(side, side)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := ChunkyRect.new()
	var grads: Array = MEDAL_GRADS[id]
	r.with_gradient(grads[0], grads[1])
	r.corner_radius = radius
	r.border_color = Color.WHITE
	r.border_width = 2.5
	r.shadow_color = MEDAL_SHADOW
	r.shadow_offset = Vector2(0, 4)
	UI.fill(c, r)
	var e := UI.centered(UI.body(String(Catalog.tower(id)["emoji"]), emoji_px, Color.WHITE, 800))
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(c, e)
	return c
