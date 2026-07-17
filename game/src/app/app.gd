extends Control
## App shell: hosts the current screen and implements the dev/CI entry modes.
##
## User args (after `--` on the command line):
##   (none)            normal run, starts at splash
##   --screen=<id>     open one screen directly
##   --smoke           instantiate every route headlessly, then quit (CI gate)
##   --autoshot=<dir>  screenshot every route to <dir>/NN-<id>.png, then quit
##   --only=<a,b>      limit --autoshot to specific route ids
##   --freeze          disable looping/entrance motion (implied by autoshot)

var _screen_holder: Control


func _ready() -> void:
	get_window().title = "SideQuest"
	var bg := ColorRect.new()
	bg.color = Tokens.BG_CANVAS
	UI.fill(self, bg)
	_screen_holder = Control.new()
	UI.fill(self, _screen_holder)
	Router.route_changed.connect(_on_route_changed)

	var args := _parse_args()
	AppMode.freeze_motion = args.has("freeze") or args.has("autoshot") or args.has("smoke")
	if args.has("smoke"):
		await _run_smoke()
	elif args.has("autoshot"):
		await _run_autoshot(args["autoshot"], args.get("only", ""))
	elif args.has("screen"):
		Router.go(args["screen"])
	else:
		Router.go("splash")


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var eq := arg.find("=")
		if eq >= 0:
			out[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
		elif arg.begins_with("--"):
			out[arg.substr(2)] = true
	return out


func _on_route_changed(id: String) -> void:
	for child in _screen_holder.get_children():
		child.queue_free()
	_screen_holder.add_child(Router.make_screen(id))


func _show_and_settle(id: String) -> void:
	for child in _screen_holder.get_children():
		_screen_holder.remove_child(child)
		child.free()
	_screen_holder.add_child(Router.make_screen(id))
	for i in 3:
		await get_tree().process_frame


func _run_smoke() -> void:
	var failures: Array[String] = []
	var stubbed: Array[String] = []
	for id in Router.ORDER:
		if not ResourceLoader.exists(Router.script_path(id)):
			stubbed.append(id)
		await _show_and_settle(id)
		var screen: Screen = _screen_holder.get_child(0)
		if screen == null or screen.get_child_count() == 0:
			failures.append(id)
	print("SMOKE ROUTES: %d  stubs: %s" % [Router.ORDER.size(), ", ".join(stubbed) if stubbed.size() > 0 else "none"])
	if failures.is_empty():
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL: " + ", ".join(failures))
		get_tree().quit(1)


func _run_autoshot(dir: String, only: String) -> void:
	var ids: Array[String] = Router.ORDER.duplicate()
	if only != "":
		ids.clear()
		for part in only.split(","):
			ids.append(part.strip_edges())
	DirAccess.make_dir_recursive_absolute(dir)
	for id in ids:
		await _show_and_settle(id)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var idx := Router.ORDER.find(id) + 1  # off-registry ids land at 00-
		var path := "%s/%02d-%s.png" % [dir, idx, id]
		var err := img.save_png(path)
		print("SHOT %s -> %s (%s)" % [id, path, error_string(err)])
	print("AUTOSHOT DONE")
	get_tree().quit(0)
