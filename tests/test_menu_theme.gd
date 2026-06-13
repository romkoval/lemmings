extends "res://addons/gut/test.gd"

# US-2.6 styling pass: the shared MenuTheme gives every menu one look. Sanity
# that its helpers produce the expected overrides so screens stay consistent.


func test_style_button_sets_all_states_and_accent() -> void:
	var btn := Button.new()
	add_child_autoqfree(btn)
	MenuTheme.style_button(btn, MenuTheme.ACCENT_PLAY, 30)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := btn.get_theme_stylebox(state) as StyleBoxFlat
		assert_not_null(sb, "%s stylebox set" % state)
		assert_eq(sb.corner_radius_top_left, 14, "rounded corners")
	assert_eq(btn.get_theme_stylebox("normal").border_color, MenuTheme.ACCENT_PLAY,
		"accent drives the border")
	assert_eq(btn.get_theme_font_size("font_size"), 30)


func test_style_title_is_gold_with_outline() -> void:
	var lbl := Label.new()
	add_child_autoqfree(lbl)
	MenuTheme.style_title(lbl, 52)
	assert_eq(lbl.get_theme_color("font_color"), MenuTheme.TITLE_GOLD)
	assert_gt(lbl.get_theme_constant("outline_size"), 0, "title is outlined for legibility")


func test_panel_box_carries_the_accent_border() -> void:
	var sb := MenuTheme.panel_box(MenuTheme.ACCENT_SETTINGS)
	assert_eq(sb.border_color, MenuTheme.ACCENT_SETTINGS)
	assert_gt(sb.border_width_left, 0)
	assert_gt(sb.corner_radius_top_left, 0)
