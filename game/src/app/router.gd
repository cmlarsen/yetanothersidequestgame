extends Node
## Autoload: navigation over the 28-screen registry. Column/order match the
## YAS v1.0 flow map (docs/design/yas-v1). Screens navigate with
## Router.go("route_id"); the app shell swaps the current screen on
## route_changed. Missing screen scripts resolve to a stub so the shell,
## smoke test, and autoshot run before every screen lands.

signal route_changed(id: String)

## Document order from the flow map (also the autoshot order).
const ORDER: Array[String] = [
	"splash", "location_permission", "notification_permission", "tutorial",
	"character_select",
	"home", "level_up",
	"exploration", "paper_doll", "party", "info_popover",
	"npc_dialogue", "quest_board", "shop",
	"combat", "victory", "equip_drawer", "death",
	"loot_box", "rewards", "run_ended",
	"alerts", "settings",
	"tower_placement", "defense_view", "tower_manage", "minion_dispatch",
	"minion_report",
]

const _SCREEN_DIR := "res://src/ui/screens/"

var current: String = ""
var history: Array[String] = []


func go(id: String) -> void:
	# Off-registry ids are allowed when the script exists (component galleries,
	# dev screens); the 28 ORDER ids always resolve, stubbing if unbuilt.
	assert(id in ORDER or ResourceLoader.exists(script_path(id)), "unknown route: " + id)
	if current != "":
		history.append(current)
	current = id
	route_changed.emit(id)


func back() -> void:
	if history.is_empty():
		return
	current = history.pop_back()
	route_changed.emit(current)


func script_path(id: String) -> String:
	return _SCREEN_DIR + id + ".gd"


func make_screen(id: String) -> Screen:
	var screen: Screen = null
	if ResourceLoader.exists(script_path(id)):
		var scr: GDScript = load(script_path(id))
		if scr != null:
			screen = scr.new()
	if screen == null:
		screen = _make_stub(id)
	screen.route_id = id
	screen.name = id
	return screen


func _make_stub(id: String) -> Screen:
	var s := Screen.new()
	s.ready.connect(func() -> void:
		s.add_bg(Tokens.BG_SCREEN)
		var v := UI.vbox(10, BoxContainer.ALIGNMENT_CENTER)
		UI.fill(s, v)
		v.add_child(UI.centered(UI.display("NOT BUILT", 30, Tokens.white(0.35))))
		v.add_child(UI.centered(UI.micro(id, 11, Tokens.CYAN))))
	return s
