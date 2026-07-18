class_name Parchment
## Quest-card / speech-bubble paper (chunk 13): parchment fill, path-edge
## border, hard dark drop. Put it as the first child of a sized Control;
## callers add ON_PARCHMENT text on top.


static func make(radius: float = 14.0) -> ChunkyRect:
	var r := ChunkyRect.panel(Tokens.PARCHMENT, radius,
		Tokens.MAP_PATH_EDGE, 2.0, Color(Tokens.BG_INSET, 0.5))
	r.shadow_offset = Vector2(0, 5)
	return r
