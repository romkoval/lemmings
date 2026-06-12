extends "res://addons/gut/test.gd"

# US-3.5: localization. Russian source strings are the translation keys, so
# every Control auto-translates; formatted strings go through tr() in code.


func after_each() -> void:
	SaveManager.settings["locale"] = "ru"
	SaveManager.apply_locale()


func test_english_catalog_translates_ui_strings() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr("Пауза"), "Pause")
	assert_eq(tr("Строитель"), "Builder")
	assert_eq(tr("ПОБЕДА!"), "VICTORY!")
	assert_eq(tr("Спасено: %d / %d") % [3, 10], "Saved: 3 / 10")
	assert_eq(tr("🔒 Уровень %d") % 4, "🔒 Level 4")


func test_russian_stays_russian() -> void:
	TranslationServer.set_locale("ru")
	assert_eq(tr("Пауза"), "Пауза")
	assert_eq(tr("Вышло: %d") % 7, "Вышло: 7")


func test_saved_locale_is_applied() -> void:
	SaveManager.settings["locale"] = "en"
	SaveManager.apply_locale()
	assert_eq(TranslationServer.get_locale().substr(0, 2), "en")
	SaveManager.settings["locale"] = "ru"
	SaveManager.apply_locale()
	assert_eq(TranslationServer.get_locale().substr(0, 2), "ru")
