class_name DamageFloat
## Combat/reward floaters ("+80 XP", "-14"): rotated display-font label with
## a hard text shadow, per the victory-screen popIns.


static func make(text: String, color: Color, font_size: int, rot_deg: float,
		shadow: Color) -> Label:
	var l := UI.display(text.to_upper(), font_size, color)
	UI.shadowed(l, shadow, clampi(roundi(font_size * 0.14), 2, 4))
	l.rotation_degrees = rot_deg
	l.resized.connect(func() -> void: l.pivot_offset = l.size * 0.5)
	return l
