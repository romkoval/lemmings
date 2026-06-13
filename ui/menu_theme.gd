class_name MenuTheme
extends RefCounted

# Shared visual language for the menus (main menu, settings, world map): a dark
# slate background, gold outlined titles, and accent-bordered rounded panels and
# buttons. Centralised here so every screen reads as one game, not a pile of
# differently-styled scenes.

const BG_DARK := Color(0.06, 0.05, 0.11)
const PANEL_BG := Color(0.14, 0.13, 0.18)
const PANEL_BG_HOVER := Color(0.20, 0.19, 0.26)
const TITLE_GOLD := Color(1.0, 0.86, 0.30)
const TITLE_OUTLINE := Color(0.10, 0.05, 0.0)
const TEXT := Color(0.93, 0.93, 0.96)

# Accent colours by role — reused across screens so e.g. "back" is always the
# same warm red and "confirm" the same green.
const ACCENT_PLAY := Color(0.30, 0.78, 0.40)
const ACCENT_INFO := Color(0.32, 0.60, 1.0)
const ACCENT_EDIT := Color(0.95, 0.72, 0.25)
const ACCENT_SETTINGS := Color(0.70, 0.55, 1.0)
const ACCENT_BACK := Color(0.90, 0.40, 0.40)


static func style_title(label: Label, font_size: int = 52) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TITLE_GOLD)
	label.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 9))


static func panel_box(accent: Color, fill: Color = PANEL_BG, radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(18)
	return sb


static func style_button(btn: Button, accent: Color, font_size: int = 32) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL_BG
		if state == "hover":
			sb.bg_color = PANEL_BG_HOVER
		elif state == "pressed":
			sb.bg_color = accent.darkened(0.5)
		sb.border_color = accent if state != "disabled" else accent.darkened(0.55)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_disabled_color", TEXT.darkened(0.5))
