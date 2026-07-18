class_name Screen
extends Control
## Base for every 402×874 design-frame screen. Subclasses override build()
## and construct their tree with UI/Icons/ChunkyRect against GameState data.

const DESIGN_SIZE := Vector2(402, 874)

var route_id: String = ""


func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build()


func build() -> void:
	pass


## Solid background layer (most screens: Tokens.BG_SCREEN or the map grass).
func add_bg(color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self, r)
	move_child(r, 0)


## Start a looping bob (mock: translateY ±6px, 2–2.4s) unless motion is frozen.
func bob(node: Control, amplitude: float = 6.0, period: float = 2.0) -> void:
	if AppMode.freeze_motion:
		return
	var base_y := node.position.y
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position:y", base_y - amplitude, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base_y, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Staggered pop-in (mock: popIn scale 0→1.12→1, .5s, .2s stagger).
func pop_in(node: Control, delay: float = 0.0) -> void:
	if AppMode.freeze_motion:
		return
	node.scale = Vector2.ZERO
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15)
