class_name Icons
## Runtime SVG icon set. The mocks use inline SVGs (stroke 2.2–2.6, round caps);
## rasterizing at request size via ThorVG keeps them crisp at any scale with no
## import pipeline. Icons are authored on a 24×24 viewBox.
##
## Usage: `Icons.tex("bell", 22, Tokens.CYAN)` → cached Texture2D.

static var _cache: Dictionary = {}

# Inner markup per icon. COLOR and SW get substituted at rasterize time.
# Stroke icons wrap in the shared <g>; entries starting with "<FILL>" are
# fill-based and get COLOR as fill instead.
const _ICONS: Dictionary = {
	"pin": '<path d="M12 21c-4-4.5-7-7.9-7-11.4C5 6 8 3 12 3s7 3 7 6.6C19 13.1 16 16.5 12 21z"/><circle cx="12" cy="9.5" r="2.6"/>',
	"bell": '<path d="M18 10a6 6 0 0 0-12 0c0 5-2 6-2 6h16s-2-1-2-6"/><path d="M10.3 20a2 2 0 0 0 3.4 0"/>',
	"compass": '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
	"steps": '<path d="M7 3c1.6 0 2.5 1.4 2.5 3.2S8.7 9.6 7.4 9.6 5 8.4 5 6.6 5.4 3 7 3z"/><path d="M6 10.5h3v2.5a1.5 1.5 0 0 1-3 0z"/><path d="M17 12c1.6 0 2.5 1.4 2.5 3.2s-.8 3.4-2.1 3.4-2.4-1.2-2.4-3 .4-3.6 2-3.6z"/><path d="M16 19.5h3V22a1.5 1.5 0 0 1-3 0z"/>',
	"sword": '<path d="M4 20l6-6"/><path d="M9 15L19 4l1 1-11 10"/><path d="M6 17l1.5 1.5"/><path d="M3.5 21.5L6 19"/>',
	"shield": '<path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6z"/>',
	"home": '<path d="M4 11l8-7 8 7"/><path d="M6 9.5V20h12V9.5"/><path d="M10 20v-5h4v5"/>',
	"map": '<path d="M9 4L4 6v14l5-2 6 2 5-2V4l-5 2z"/><path d="M9 4v14"/><path d="M15 6v14"/>',
	"party": '<circle cx="8.5" cy="8" r="3.2"/><path d="M3 20c0-3 2.5-5 5.5-5s5.5 2 5.5 5"/><circle cx="16.5" cy="9" r="2.6"/><path d="M15.5 15.2c2.9.2 5.5 2 5.5 4.8"/>',
	"bag": '<path d="M6 8h12l1 12H5z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
	"dots": '<circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/>',
	"gear": '<circle cx="12" cy="12" r="3"/><path d="M12 2.5l1.2 2.6 2.8-.6 1 2.7 2.7 1-.6 2.8 2.4 1.6-1.6 2.4.6 2.8-2.7 1-1 2.7-2.8-.6L12 21.5l-1.2-2.6-2.8.6-1-2.7-2.7-1 .6-2.8L2.5 12l1.6-2.4-.6-2.8 2.7-1 1-2.7 2.8.6z" stroke-linejoin="round"/>',
	"lock": '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
	"check": '<path d="M4.5 12.5l5 5 10-11"/>',
	"x": '<path d="M6 6l12 12M18 6L6 18"/>',
	"warning": '<path d="M12 3.5L22 20H2z" stroke-linejoin="round"/><path d="M12 10v4.5"/><circle cx="12" cy="17.3" r="0.4"/>',
	"star": '<FILL><path d="M12 2.5l2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.3l-5.8 3.1 1.1-6.5L2.6 9.3l6.5-.9z"/>',
	"chest": '<path d="M4 8a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v11H4z"/><path d="M4 12h16"/><rect x="10.4" y="10.5" width="3.2" height="4" rx="1"/>',
	"hammer": '<path d="M6 5h9v5H6z" stroke-linejoin="round"/><path d="M15 6.5h3.5v2H15"/><path d="M9.5 10v10.5"/><path d="M11.5 10v10.5"/>',
	"wand": '<path d="M4 20L15 9"/><path d="M15 4.5l1 2.3 2.3 1-2.3 1-1 2.3-1-2.3-2.3-1 2.3-1z" stroke-linejoin="round"/><path d="M19.5 12l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z"/>',
	"scroll": '<path d="M7 4h11a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H7"/><path d="M7 4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2"/><path d="M10 9h6M10 13h6"/>',
	"snowflake": '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/><path d="M12 3l-2 2M12 3l2 2M12 21l-2-2M12 21l2-2"/>',
	"potion": '<path d="M10 3h4"/><path d="M10.5 3v5L6 15a4.8 4.8 0 0 0 4.2 6h3.6A4.8 4.8 0 0 0 18 15l-4.5-7V3"/><path d="M8 14h8"/>',
	"heart": '<path d="M12 20s-7-4.5-9-9c-1.2-2.8.5-6 3.6-6 2 0 3.6 1.2 5.4 3.4C13.8 6.2 15.4 5 17.4 5c3.1 0 4.8 3.2 3.6 6-2 4.5-9 9-9 9z" stroke-linejoin="round"/>',
	"skull": '<path d="M12 3a7.5 7.5 0 0 0-7.5 7.5c0 2.6 1.2 4.7 3 6v3h9v-3c1.8-1.3 3-3.4 3-6A7.5 7.5 0 0 0 12 3z"/><circle cx="9" cy="11" r="1.4"/><circle cx="15" cy="11" r="1.4"/>',
	"share": '<circle cx="6" cy="12" r="2.5"/><circle cx="17.5" cy="6" r="2.5"/><circle cx="17.5" cy="18" r="2.5"/><path d="M8.2 10.8l7-3.6M8.2 13.2l7 3.6"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>',
	"chevron_right": '<path d="M9 5l7 7-7 7"/>',
	"chevron_left": '<path d="M15 5l-7 7 7 7"/>',
	"chevron_down": '<path d="M5 9l7 7 7-7"/>',
	"arrow_down": '<path d="M12 4v14M6 13l6 6 6-6"/>',
	"arrow_right": '<path d="M4 12h14M13 6l6 6-6 6"/>',
	"plus": '<path d="M12 5v14M5 12h14"/>',
	"eye": '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
	"tower": '<path d="M7 21V8l-2-1V4h3v2h2V4h4v2h2V4h3v3l-2 1v13"/><path d="M5 21h14"/><path d="M10.5 21v-4a1.5 1.5 0 0 1 3 0v4"/>',
	"tree": '<path d="M12 3l5 6h-3l4 5h-4l3 4H7l3-4H6l4-5H7z" stroke-linejoin="round"/><path d="M12 18v3.5"/>',
	"question": '<path d="M9 9a3 3 0 1 1 4.5 2.6c-1 .6-1.5 1.2-1.5 2.4"/><circle cx="12" cy="17.5" r="0.4"/>',
	"coin": '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="5"/><path d="M12 9.5v5"/>',
	"wood": '<ellipse cx="7" cy="12" rx="2.6" ry="4.5"/><path d="M7 7.5h9.5c1.6 0 3 2 3 4.5s-1.4 4.5-3 4.5H7"/><ellipse cx="16.5" cy="12" rx="1.1" ry="2"/>',
	"flee": '<path d="M13 4.5a1.8 1.8 0 1 0 3.6 0 1.8 1.8 0 0 0-3.6 0"/><path d="M9 20l2.5-5L9 11l4-3 2.5 3.5H19"/><path d="M9 11l-3.5 1M11.5 15L6 20"/>',
	"target": '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="0.8"/>',
	"moon": '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z" stroke-linejoin="round"/>',
	"sparkle": '<path d="M12 4l1.8 4.2L18 10l-4.2 1.8L12 16l-1.8-4.2L6 10l4.2-1.8z" stroke-linejoin="round"/><path d="M18.5 15l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9z"/>',
	"couch": '<path d="M5 10V8a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v2"/><path d="M3 12a2 2 0 0 1 4 0v1h10v-1a2 2 0 0 1 4 0v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M5 17v2M19 17v2"/>',
	"repair": '<path d="M14.5 6.5a4 4 0 0 0-5.4 5L4 16.6a1.6 1.6 0 0 0 0 2.3l1.1 1.1a1.6 1.6 0 0 0 2.3 0l5.1-5.1a4 4 0 0 0 5-5.4l-2.8 2.8-2.4-2.4z" stroke-linejoin="round"/>',
	# Gloomling mushroom, path copied verbatim from the mock chunks (15/11/22
	# all use the two-eyed body; the eyes read as holes via nonzero winding).
	"shroom": '<FILL><path d="M12 2C7 2 3.5 5.8 3.5 10.5c0 2.6 1.2 4.7 3 6v3c0 .8.7 1.5 1.5 1.5h1v-2h2v2h2v-2h2v2h1c.8 0 1.5-.7 1.5-1.5v-3c1.8-1.3 3-3.4 3-6C20.5 5.8 17 2 12 2zm-4 10a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm8 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4z"/>',
	"shroom_plain": '<FILL><path d="M12 2C7 2 3.5 5.8 3.5 10.5c0 2.6 1.2 4.7 3 6v3c0 .8.7 1.5 1.5 1.5h1v-2h2v2h2v-2h2v2h1c.8 0 1.5-.7 1.5-1.5v-3c1.8-1.3 3-3.4 3-6C20.5 5.8 17 2 12 2z"/>',
	"bolt": '<path d="M13 3L5 13h5l-1 8 8-11h-5z" stroke-linejoin="round"/>',
	"sword_slash": '<path d="M9 15L4 20M9 15l9.5-11 2.5 2.5L10 16z" stroke-linejoin="round"/><path d="M14 4l6 6"/>',
}


static func has_icon(icon_name: String) -> bool:
	return _ICONS.has(icon_name)


static func tex(icon_name: String, size_px: int, color: Color, stroke_width: float = 2.4) -> Texture2D:
	assert(_ICONS.has(icon_name), "unknown icon: " + icon_name)
	var key := "%s_%d_%s_%.1f" % [icon_name, size_px, color.to_html(), stroke_width]
	if _cache.has(key):
		return _cache[key]
	var body: String = _ICONS[icon_name]
	var hex := "#" + color.to_html(false)
	var inner: String
	if body.begins_with("<FILL>"):
		inner = '<g fill="%s" fill-opacity="%.3f">%s</g>' % [hex, color.a, body.substr(6)]
	else:
		inner = '<g fill="none" stroke="%s" stroke-opacity="%.3f" stroke-width="%.2f" stroke-linecap="round">%s</g>' % [
			hex, color.a, stroke_width, body]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>' % inner
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(size_px) / 24.0)
	assert(err == OK, "svg rasterize failed for icon: " + icon_name)
	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


## Convenience: a TextureRect sized to the icon.
static func rect(icon_name: String, size_px: int, color: Color, stroke_width: float = 2.4) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex(icon_name, size_px, color, stroke_width)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(size_px, size_px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
