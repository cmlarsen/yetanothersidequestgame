class_name SegmentedBar
extends Control
## Segmented HP bar (tyrant HP ×4): inset pill track, gradient fill, and
## 3px track-colored dividers between segments so the fill reads as chunks.

const _GAP_W := 3.0

var _fill: ChunkyRect


static func make(width: float, height: float, segments: int,
		from: Color, to: Color) -> SegmentedBar:
	var bar := SegmentedBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(width, height)
	var radius := height * 0.5
	var track := ChunkyRect.panel(Tokens.BG_INSET, radius)
	UI.fill(bar, track)
	bar._fill = ChunkyRect.new()
	bar._fill.with_gradient(from, to)
	bar._fill.corner_radius = radius
	UI.fill(bar, bar._fill)
	for i in segments - 1:
		var gap := ColorRect.new()
		gap.color = Tokens.BG_INSET
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(gap)
		var at := float(i + 1) / segments
		gap.set_anchors_preset(Control.PRESET_FULL_RECT)
		gap.anchor_left = at
		gap.anchor_right = at
		gap.offset_left = -_GAP_W * 0.5
		gap.offset_right = _GAP_W * 0.5
	bar.set_ratio(1.0)
	return bar


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	_fill.visible = r > 0.004
	_fill.anchor_right = r
