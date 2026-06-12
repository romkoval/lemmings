extends "res://addons/gut/test.gd"

# Mobile fit: phones are the target platform. The top bar must fit the 720px
# design width with the edge margins to spare, every top-bar glyph must exist
# in the font (the old "⏭" drew as a blank box on iOS), and the hint banner
# must sit below the top bar / safe-area inset instead of under the camera
# cutout.

const TEST_LEVEL: String = "user://custom_levels/_gut_mobile_level.json"

const SAMPLE: Dictionary = {
	"id": "_gut_mobile_level", "name": "mobile gut", "custom": true,
	"total_lemmings": 2, "save_required": 1, "time_limit": 120, "release_rate": 50,
	"skill_counts": {"climber": 0, "floater": 0, "bomber": 0, "blocker": 0,
		"builder": 0, "basher": 0, "miner": 0, "digger": 1},
	"entrance_pos": [80, 398], "entrance_direction": 1, "exit_pos": [620, 446],
	"terrain_rects": [{"x": 0, "y": 29, "w": 45, "h": 4}],
	"hint": "Тестовая подсказка для проверки мобильной раскладки",
}


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_LEVEL)
	SaveManager.settings.erase("hints_shown")
	SaveManager.settings["hints_enabled"] = true
	GameManager.reset()


func _hud() -> HUD:
	var hud: HUD = (load("res://ui/hud.tscn") as PackedScene).instantiate() as HUD
	add_child_autoqfree(hud)
	return hud


func test_top_bar_fits_a_phone_screen_at_worst_case_numbers() -> void:
	var hud := _hud()
	await wait_physics_frames(1)
	# Max out every counter so the labels are at their widest.
	GameManager.saved_count = 99
	GameManager.spawned_count = 99
	hud.required_saved = 99
	hud.time_remaining = 3599.0
	await wait_physics_frames(1)
	var available: float = hud.size.x - 2.0 * HUD.EDGE_MARGIN
	assert_lt(hud.top_bar.get_minimum_size().x, available,
		"top bar content must fit the design width minus edge margins")
	var nuke_right: float = hud.nuke_button.global_position.x + hud.nuke_button.size.x
	assert_lte(nuke_right, hud.size.x - HUD.EDGE_MARGIN + 0.5,
		"the rightmost button ends on-screen")


func test_top_bar_button_labels_have_real_glyphs() -> void:
	# "⏭" has no glyph in the bundled font on iOS — buttons must stick to
	# characters the font can actually draw.
	var hud := _hud()
	await wait_physics_frames(1)
	for btn in [hud.fast_button, hud.pause_button, hud.step_button, hud.nuke_button]:
		var font: Font = btn.get_theme_font("font")
		for i in range(btn.text.length()):
			var code: int = btn.text.unicode_at(i)
			assert_true(font.has_char(code),
				"glyph U+%04X ('%s') exists for button '%s'" % [code, btn.text[i], btn.text])


func test_layout_respects_notch_sized_insets() -> void:
	var hud := _hud()
	await wait_physics_frames(1)
	# Dynamic-Island-sized top inset + home-indicator bottom inset.
	hud._apply_insets(24.0, 110.0, 24.0, 52.0)
	assert_eq(hud.top_bar.offset_top, 110.0, "top bar pushed below the cutout")
	assert_eq(hud.bottom_bar.offset_bottom, -52.0, "bottom bar clears the home indicator")
	assert_gte(hud.release_controls.offset_left, 24.0, "rate column inside the left inset")
	assert_lte(hud.zoom_controls.offset_right, -24.0, "zoom column inside the right inset")
	var slot: Rect2 = hud.hint_rect()
	assert_gte(slot.position.y, 110.0 + HUD.TOP_BAR_HEIGHT,
		"hint slot clears the cutout and the top bar")
	assert_gte(slot.position.x, 24.0)
	assert_lte(slot.end.x, hud.size.x - 24.0)


func test_hint_banner_sits_below_the_top_bar_and_clear_of_the_minimap() -> void:
	SaveManager.settings["hints_enabled"] = true
	SaveManager.settings["hints_shown"] = {}
	LevelManager.save_level_json(TEST_LEVEL, SAMPLE)
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate() as Game
	game.initial_level_path = TEST_LEVEL
	add_child_autoqfree(game)
	await wait_physics_frames(2)
	assert_not_null(game._hint_panel, "hint shown on first visit")
	var hud: HUD = game.hud
	assert_gte(game._hint_panel.offset_top, hud.top_bar.offset_bottom,
		"banner starts below the top bar")
	assert_gte(game._hint_panel.offset_left, HUD.EDGE_MARGIN - 0.5,
		"banner inside the left margin")
	assert_lte(game._hint_panel.offset_right, hud.size.x - HUD.EDGE_MARGIN + 0.5,
		"banner inside the right margin")
	if hud.minimap and hud.minimap.visible:
		assert_lte(game._hint_panel.offset_right, hud.size.x + hud.minimap.offset_left,
			"banner stops short of the minimap")
