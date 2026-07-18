class_name StatBarChunky
extends Control
## Rounded inset track + vertical-gradient fill (XP, HP, durability, quest
## progress). The fill is anchor-driven so the bar can stretch in containers.

var _fill: ChunkyRect


static func make(width: float, height: float, from: Color, to: Color,
		bg: Color = Tokens.BG_INSET, radius: float = 8.0) -> StatBarChunky:
	var bar := StatBarChunky.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(width, height)
	var track := ChunkyRect.panel(bg, radius)
	UI.fill(bar, track)
	bar._fill = ChunkyRect.new()
	bar._fill.with_gradient(from, to)
	bar._fill.corner_radius = radius
	UI.fill(bar, bar._fill)
	bar.set_ratio(1.0)
	return bar


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	_fill.visible = r > 0.004
	_fill.anchor_right = r
