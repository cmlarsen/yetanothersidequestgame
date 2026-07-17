extends SceneTree
## Cross-consistency checks over Rules / Catalog / GameState / Router: every id
## a screen can render must resolve, and every number that appears in both a
## mock and GAME-RULES must agree. Scripts are load()ed (not class_name-typed)
## so the pass runs standalone:
##   godot --headless --path game --script res://tests/data_sanity.gd

var _failures: Array[String] = []


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _init() -> void:
	var rules: GDScript = load("res://src/rules/rules.gd")
	var catalog: GDScript = load("res://src/data/catalog.gd")
	var router_scr: GDScript = load("res://src/app/router.gd")
	var gs: Node = (load("res://src/data/game_state.gd") as GDScript).new()

	# Level curve.
	_check(rules.xp_for_level(1) == 100, "xp_for_level(1) == 100")
	_check(rules.xp_for_level(2) == 135, "xp_for_level(2) == 135")
	_check(gs.xp_next == float(rules.xp_for_level(gs.level)), "GameState.xp_next derives from Rules")
	_check(gs.xp > 0 and gs.xp < int(gs.xp_next), "GameState.xp within level")

	# Every item id a screen can reach resolves in Catalog.
	for slot in gs.hotbar:
		if slot.has("item"):
			_check(not catalog.item(slot["item"]).is_empty(), "hotbar item resolves: %s" % slot["item"])
	for slot_name in gs.equipment:
		var id: String = gs.equipment[slot_name]
		if id != "":
			_check(not catalog.item(id).is_empty(), "equipment item resolves: %s" % id)
	for entry in gs.inventory:
		_check(not catalog.item(entry["item"]).is_empty(), "inventory item resolves: %s" % entry["item"])
	for id in gs.equip_drawer["items"]:
		_check(not catalog.item(id).is_empty(), "equip drawer item resolves: %s" % id)
	_check(gs.equip_drawer["selected"] in gs.equip_drawer["items"], "equip drawer selection is in its grid")
	for stock in catalog.SHOP_STOCK:
		_check(not catalog.item(stock["item"]).is_empty(), "shop item resolves: %s" % stock["item"])
	for id in gs.rewards["items"]:
		_check(not catalog.item(id).is_empty(), "reward item resolves: %s" % id)
	for loot in gs.run_summary["loot"]:
		_check(not catalog.item(loot["item"]).is_empty(), "run summary item resolves: %s" % loot["item"])
	_check(not catalog.item(gs.minion_report["salvage_item"]).is_empty(), "salvage item resolves")
	_check(not catalog.item(gs.shop_selected).is_empty(), "shop selection resolves")
	_check(not catalog.item(gs.level_up["new_skill"]).is_empty(), "level-up skill resolves")

	# Faces: every face id referenced anywhere must have a PNG.
	var face_ids: Array[String] = []
	for id in catalog.CHARACTERS:
		face_ids.append(id)
	for member in gs.party:
		face_ids.append(member["face"])
	for near in gs.nearby_players:
		face_ids.append(near["face"])
	for id in catalog.MINIONS:
		face_ids.append(catalog.MINIONS[id]["face"])
	for id in catalog.NPCS:
		face_ids.append(catalog.NPCS[id]["face"])
	face_ids.append(gs.death["reviver_face"])
	for face in face_ids:
		_check(FileAccess.file_exists("res://assets/ui/faces/face-%s.png" % face), "face asset exists: %s" % face)

	# Towers: Catalog costs match Rules; placed towers resolve and stay in cap.
	_check(catalog.tower("bonk_turret")["cost"] == rules.BONK_TURRET_COST, "bonk_turret cost matches Rules")
	_check(catalog.tower("chill_bell")["cost"] == rules.CHILL_BELL_COST, "chill_bell cost matches Rules")
	_check(catalog.tower("bastion_post")["cost"] == rules.BASTION_POST_COST, "bastion_post cost matches Rules")
	_check(rules.tower_salvage_refund(catalog.tower("chill_bell")["cost"]) == 8, "chill bell salvage refund == 8 (mock)")
	for t in gs.towers:
		_check(not catalog.tower(t["type"]).is_empty(), "placed tower resolves: %s" % t["type"])
		_check(t["level"] <= rules.TOWER_MAX_LEVEL, "tower level within Rules cap")
	_check(gs.towers_placed == gs.towers.size(), "towers_placed matches towers list")
	_check(gs.tower_cap == rules.TOWER_CAP, "tower_cap matches Rules")
	_check(not catalog.tower(gs.tower_placement["selected"]).is_empty(), "placement selection resolves")
	_check(gs.towers[gs.managed_tower_index]["durability_pct"] == 34, "managed tower is the 34% Chill Bell")

	# Alerts: every deep link is a real route.
	var order: Array = router_scr.ORDER
	for a in catalog.ALERTS:
		_check(a["route"] in order, "alert route in Router.ORDER: %s -> %s" % [a["id"], a["route"]])

	# Quests: state rows resolve and rewards/targets agree with Rules.
	for q in gs.quests:
		_check(not catalog.quest(q["id"]).is_empty(), "quest resolves: %s" % q["id"])
	_check(gs.quests[0]["progress"] == gs.steps_today, "walk quest progress == steps_today")
	_check(catalog.quest("daily_walk")["target"] == rules.DAILY_WALK_STEPS, "walk target matches Rules")
	_check(catalog.quest("daily_walk")["reward_gold"] == rules.DAILY_WALK_GOLD, "walk reward matches Rules")
	_check(catalog.quest("daily_defeat")["target"] == rules.DAILY_DEFEAT_COUNT, "defeat target matches Rules")
	_check(catalog.quest("daily_defeat")["reward_gold"] == rules.DAILY_DEFEAT_GOLD, "defeat reward matches Rules")
	_check(catalog.quest("territory_elm")["target"] == rules.TERRITORY_CLAIM_COUNT, "territory target matches Rules")
	_check(catalog.quest("territory_elm")["reward_gold"] == rules.TERRITORY_CLAIM_GOLD, "territory reward matches Rules")
	_check(gs.steps_goal == rules.DAILY_WALK_STEPS, "steps_goal matches Rules")
	var story_giver: String = catalog.quest("story_grumble_park")["giver"]
	_check(catalog.npc(story_giver)["quest_id"] == "story_grumble_park", "NPC and story quest link both ways")

	# Minions and jobs.
	for m in gs.minions:
		_check(not catalog.minion(m["id"]).is_empty(), "minion resolves: %s" % m["id"])
		if m.has("job"):
			_check(not catalog.job(m["job"]).is_empty(), "minion job resolves: %s" % m["job"])
	_check(not catalog.job(gs.selected_job).is_empty(), "selected job resolves")
	_check(catalog.job("gather_lumber")["duration_min"] == rules.GATHER_LUMBER_MINUTES, "gather duration matches Rules")
	_check(catalog.job("gather_lumber")["yield_min"] == rules.GATHER_LUMBER_YIELD_MIN, "gather yield min matches Rules")
	_check(catalog.job("gather_lumber")["yield_max"] == rules.GATHER_LUMBER_YIELD_MAX, "gather yield max matches Rules")
	_check(catalog.job("scavenge")["injury_pct"] == rules.SCAVENGE_INJURY_PCT, "scavenge injury matches Rules")
	_check(catalog.minion(gs.minion_report["minion"])["quotes"].size() > 0, "reporting minion has a return quote")
	_check(rules.MINION_HIRE_COST == 200, "hire slot price is 200 g")

	# Economy: shop math and locks agree with Rules.
	_check(catalog.item("mystery_box")["value"] == rules.MYSTERY_BOX_COST, "mystery box price matches Rules")
	_check(rules.deal_price(catalog.item("fizzy_bucket")["value"]) == 84, "deal price 120 -> 84 (mock)")
	_check(catalog.item("pocket_blizzard")["level_req"] == rules.POCKET_BLIZZARD_UNLOCK_LEVEL, "blizzard unlock matches Rules")
	_check(catalog.item("cape_of_mild_dramatics")["level_req"] == rules.CAPE_UNLOCK_LEVEL, "cape unlock matches Rules")

	# Mock-pinned screen numbers.
	_check(gs.victory["xp"] == 80 and gs.victory["gold"] == 40, "victory floats +80 XP / +40 gold")
	_check(gs.rewards["gold"] == 250 and gs.rewards["xp"] == 120, "chest rewards +250 g / +120 XP")
	_check(catalog.item(gs.rewards["items"][1])["rarity"] == "legendary", "center reward card is highest rarity")
	_check(gs.run_summary["hexes_kept"] == 4 and gs.run_summary["xp_kept"] == 310
		and gs.run_summary["gold_dropped"] == 120, "run summary tallies match mock")
	_check(gs.death["hexes_lost"] <= rules.DEATH_CONTESTED_HEX_LOSS_CAP, "death hex loss within Rules cap")
	_check(gs.death["countdown_sec"] <= rules.REVIVE_COUNTDOWN_SEC, "revive countdown within Rules timer")
	_check(gs.death["reviver_distance_m"] <= rules.REVIVE_RADIUS_M, "reviver within revive radius")
	_check(rules.fmt_mmss(gs.death["countdown_sec"]) == "0:42", "countdown formats as 0:42")
	_check(rules.fmt_thousands(gs.steps_today) == "1,204", "steps format as 1,204")
	_check(gs.chest["distance_m"] == 18, "chest distance 18 m")
	_check(gs.stats["hp"]["total"] == gs.hp_max, "stats HP total matches hp_max")
	_check(gs.set_pieces_equipped("hammer") == 2, "HAMMER SET 2/4 from equipment")
	_check(gs.hotbar.size() == rules.HOTBAR_SLOTS, "hotbar has 5 slots")
	_check(catalog.mob(gs.combat["mob"])["level"] == 8, "Grumbleshroom is LV 8")
	_check(gs.party.size() <= rules.PARTY_MAX, "party within max size")

	gs.free()
	if _failures.is_empty():
		print("DATA SANITY PASS")
		quit(0)
	else:
		for f in _failures:
			print("  FAIL: " + f)
		print("DATA SANITY FAIL (%d)" % _failures.size())
		quit(1)
