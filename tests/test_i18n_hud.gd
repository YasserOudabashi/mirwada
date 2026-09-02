extends "res://tests/test_case.gd"
## US-017 — traduzioni caricate e HUD agganciato ai segnali.

const HudScene := preload("res://scenes/hud.tscn")
const StatsComponent := preload("res://scripts/stats_component.gd")


func test_traduzioni_it_ed_en_presenti() -> void:
	var loc: Array = TranslationServer.get_loaded_locales()
	assert_true(loc.has("it"), "locale it caricato")
	assert_true(loc.has("en"), "locale en caricato")

	var prima: String = TranslationServer.get_locale()
	TranslationServer.set_locale("it")
	assert_eq(tr("HUD_HP"), "Salute", "chiave tradotta in it")
	TranslationServer.set_locale("en")
	assert_eq(tr("HUD_HP"), "Health", "chiave tradotta in en")
	TranslationServer.set_locale(prima)


func test_chiave_mancante_torna_la_chiave() -> void:
	assert_eq(tr("CHIAVE_INVENTATA_XYZ"), "CHIAVE_INVENTATA_XYZ", "chiave ignota -> se stessa, mai crash")


func test_stats_emette_spiritualita_changed() -> void:
	var s: Node = StatsComponent.new()
	s.configure_from_balance(9)
	var visti: Array = []
	s.spiritualita_changed.connect(func(sp: float, _m: float) -> void: visti.append(sp))
	s.spend_spiritualita(10.0)
	assert_eq(visti.size(), 1, "un evento spiritualita_changed")
	assert_almost_eq(visti[0], s.get_stat("spiritualita_max") - 10.0, "valore aggiornato")
	s.free()


func test_hud_aggancia_le_barre_ai_segnali() -> void:
	var host := Node.new()
	host.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	host.add_child(stats)
	Engine.get_main_loop().root.add_child(host)

	var hud: CanvasLayer = HudScene.instantiate()
	Engine.get_main_loop().root.add_child(hud)

	var barra: ProgressBar = hud.get_node("Root/VBox/HP/Barra")
	assert_almost_eq(barra.value, float(stats.get("hp")), "barra hp inizializzata")

	stats.set("hp", float(stats.get("hp")) - 25.0)
	assert_almost_eq(barra.value, float(stats.get("hp")), "barra hp segue il segnale")

	hud.free()
	host.free()
