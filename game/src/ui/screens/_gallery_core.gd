extends Screen
## Off-registry component gallery: every core kit piece in its notable states,
## for tools/dev/shoot.sh visual review against the mock chunks.


func build() -> void:
	add_bg(Tokens.BG_SCREEN)

	var pad := UI.margin(12, 8, 12, 0)
	UI.fill(self, pad)
	var col := UI.vbox(7)
	pad.add_child(col)

	col.add_child(_section("CHUNKY BUTTON — CTA / SECONDARY / TERTIARY / DISABLED"))
	col.add_child(ChunkyButton.make("Start Run", "cta_cyan", Vector2(0, 52), 17, "sword"))
	var row2 := UI.hbox(8)
	col.add_child(row2)
	row2.add_child(_grow(ChunkyButton.make("Claim Reward", "cta_green", Vector2(0, 46), 14)))
	row2.add_child(_grow(ChunkyButton.make("Buy · 450", "cta_gold", Vector2(0, 46), 14)))
	var row3 := UI.hbox(8)
	col.add_child(row3)
	row3.add_child(_grow(ChunkyButton.make("Attack", "cta_red", Vector2(0, 44), 13)))
	row3.add_child(_grow(ChunkyButton.make("View Stats", "secondary", Vector2(0, 44), 13)))
	var row4 := UI.hbox(8)
	col.add_child(row4)
	row4.add_child(_grow(ChunkyButton.make("Decline", "tertiary", Vector2(0, 44), 13)))
	var pressed := ChunkyButton.make("Pressed", "cta_green", Vector2(0, 44), 13)
	pressed.toggle_mode = true
	pressed.button_pressed = true
	row4.add_child(_grow(pressed))
	var disabled := ChunkyButton.make("Locked", "cta_cyan", Vector2(0, 44), 13, "lock")
	disabled.disabled = true
	row4.add_child(_grow(disabled))

	col.add_child(_section("CHIP · CURRENCY PILL"))
	var chips := UI.hbox(6)
	col.add_child(chips)
	chips.add_child(Chip.make("ELM ST · 41% YOURS", {"text_color": Tokens.CYAN_LIGHT}))
	chips.add_child(Chip.make("2 MOBS ACTIVE",
		{"bg": Tokens.RARITY_EPIC_BOTTOM, "border_w": 0.0}))
	var chips2 := UI.hbox(6)
	col.add_child(chips2)
	chips2.add_child(Chip.make("New Area", {
		"icon": "pin", "icon_color": Tokens.GREEN_GRAD_TOP, "font": "display",
		"font_size": 12, "text_color": Tokens.GREEN_GRAD_TOP,
		"border": Tokens.GREEN_GRAD_TOP, "radius": 14.0, "pad_h": 12.0,
		"pad_v": 6.0, "shadow": Color(Tokens.BG_INSET, 0.5)}))
	chips2.add_child(CurrencyPill.gold(GameState.gold))
	chips2.add_child(CurrencyPill.materials(GameState.materials))

	col.add_child(_section("STAT BAR — XP / QUEST / DURABILITY · SEGMENTED ×4"))
	var bars := UI.hbox(12)
	col.add_child(bars)
	var bar_col := UI.vbox(7)
	bars.add_child(bar_col)
	var xp := StatBarChunky.make(180, 8, Tokens.CYAN, Tokens.GREEN_GRAD_TOP, Tokens.BG_INSET, 4.0)
	xp.set_ratio(0.38)
	bar_col.add_child(xp)
	var quest := StatBarChunky.make(180, 9, Tokens.GREEN_GRAD_BOTTOM, Tokens.GREEN_GRAD_BOTTOM,
		Tokens.BG_INSET, 5.0)
	quest.set_ratio(0.6)
	bar_col.add_child(quest)
	var dura := StatBarChunky.make(180, 10, Tokens.RED_GRAD_TOP, Tokens.RED_GRAD_BOTTOM,
		Tokens.BG_INSET, 6.0)
	dura.set_ratio(0.34)
	bar_col.add_child(dura)
	var seg := SegmentedBar.make(160, 16, 4, Tokens.RARITY_EPIC_TOP, Tokens.RARITY_EPIC_BOTTOM)
	seg.set_ratio(0.58)
	bars.add_child(seg)

	col.add_child(_section("TAB ROW · CHUNKY TOGGLE"))
	var controls := UI.hbox(8)
	col.add_child(controls)
	var tabs: Array[String] = ["Daily", "Story", "Terr."]
	controls.add_child(TabRow.make(tabs, 0))
	controls.add_child(UI.spacer())
	controls.add_child(ChunkyToggle.make(true))
	controls.add_child(ChunkyToggle.make(false))

	col.add_child(_section("PARCHMENT · MODAL · PLACEHOLDER 3D · DAMAGE FLOAT"))
	var cards := UI.hbox(10)
	col.add_child(cards)
	cards.add_child(_parchment_demo())
	cards.add_child(_modal_demo())
	var demo_col := UI.vbox(6)
	cards.add_child(demo_col)
	demo_col.add_child(Placeholder3D.make(Vector2(92, 72), "3D MOB RENDER"))
	var float_holder := Control.new()
	float_holder.custom_minimum_size = Vector2(92, 34)
	float_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_col.add_child(float_holder)
	UI.place(float_holder, DamageFloat.make("+80 XP", Tokens.GREEN_GRAD_TOP, 20, -7.0,
		Tokens.GREEN_SHADOW), Vector2(6, 4))

	var sheet := SheetPanel.make(Tokens.BORDER, 150.0)
	UI.place(self, sheet, Vector2(0, DESIGN_SIZE.y - BottomNav.HEIGHT - 150.0))
	sheet.content.add_child(UI.body("\"This is a bench-related emergency, adventurer.\"",
		11, Tokens.white(0.85)))
	sheet.content.add_child(ChunkyButton.make("Accept Quest", "cta_cyan", Vector2(0, 44), 14))

	var nav := BottomNav.make("home", true)
	UI.place(self, nav, Vector2(0, DESIGN_SIZE.y - BottomNav.HEIGHT))


func _section(text: String) -> Label:
	return UI.micro(text, 8, Tokens.white(0.35))


func _grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _parchment_demo() -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(140, 104)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(card, Parchment.make())
	var inner := UI.margin(11, 9)
	UI.fill(card, inner)
	var v := UI.vbox(4)
	inner.add_child(v)
	v.add_child(UI.display("WALK 2,000 STEPS", 11, Tokens.ON_PARCHMENT))
	v.add_child(UI.body("Walk 2,000 steps in one day.", 9, Tokens.ON_PARCHMENT_MUTED, 700))
	var progress := StatBarChunky.make(54, 9, Tokens.GREEN_GRAD_BOTTOM,
		Tokens.GREEN_GRAD_BOTTOM, Color(Tokens.ON_PARCHMENT, 0.25), 6.0)
	progress.set_ratio(0.6)
	var prow := UI.hbox(6)
	v.add_child(prow)
	prow.add_child(progress)
	prow.add_child(UI.micro("1,204 / 2,000", 8, Tokens.ON_PARCHMENT_MUTED))
	card.rotation_degrees = -1.0
	card.pivot_offset = card.custom_minimum_size * 0.5
	return card


func _modal_demo() -> Control:
	var modal := ModalPanel.make(Tokens.GLOOM_BORDER_ALT, 122.0)
	modal.content.add_child(UI.display("GRUMBLESHROOM", 12, Tokens.GLOOM_LIGHT))
	modal.content.add_child(UI.wrap(UI.body("A fungus with opinions.", 9, Tokens.white(0.6))))
	modal.content.add_child(ChunkyButton.make("Attack", "cta_red", Vector2(0, 44), 12))
	return modal
