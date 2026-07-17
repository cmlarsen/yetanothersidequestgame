class_name CurrencyPill
## Header currency pills (mock chunk 06): dark rounded pill, emoji glyph,
## display-font amount with thousands separator. Gold first, then materials.


static func gold(amount: int) -> Control:
	return _pill("💰", format_amount(amount), Tokens.GOLD_GRAD_TOP)


static func materials(amount: int) -> Control:
	return _pill("🪵", format_amount(amount), Color.WHITE)


static func _pill(emoji: String, text: String, color: Color) -> Control:
	return Chip.make(text, {
		"emoji": emoji,
		"font": "display",
		"font_size": 12,
		"text_color": color,
		"radius": 30.0,
		"pad_h": 12.0,
		"pad_v": 6.0,
	})


static func format_amount(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if amount < 0 else "") + out
