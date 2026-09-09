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


## US-802: la hotbar non deve mai mostrare un id grezzo o un testo fisso —
## solo tr()/GameData.tr_data() sui dati dell'abilita'.
func test_hotbar_non_ha_testo_hardcoded() -> void:
	var host := Node.new()
	host.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	host.add_child(stats)
	Engine.get_main_loop().root.add_child(host)

	var root: Node = Engine.get_main_loop().root
	root.get_node("Progression").call("configura", "twilight_giant", 9)
	var gd: Node = root.get_node("GameData")
	var owned: Array = root.get_node("AbilityEngine").call("owned_abilities", host)
	assert_true(owned.size() >= 1, "il Twilight Giant a Sequenza 9 possiede almeno un'abilita'")

	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)

	# Confronto diretto con l'output di tr_data (non con un fallback nel
	# codice): passa sia che la voce it.json sia tradotta sia che sia
	# ancora uno stub "TODO <chiave>" (42 note, debito di traduzione
	# preesistente, non di questa story) — quello che conta e' che il testo
	# mostrato SEGUA il catalogo dati, non un valore scritto in hud.gd.
	var slot0: Label = hud.get_node("Root/VBox/Hotbar/Slot0")
	var ab0: Dictionary = gd.call("get_ability", str(owned[0]))
	var nome0: String = str(gd.call("tr_data", ab0.get("name_i18n", "")))
	assert_true(slot0.text.contains(nome0),
		"slot 0 mostra esattamente l'output di GameData.tr_data, non un nome scritto in hud.gd")

	var slot3: Label = hud.get_node("Root/VBox/Hotbar/Slot3")
	assert_true(slot3.text.contains(tr("HUD_HOTBAR_VUOTO")),
		"lo slot senza abilita' mostra la chiave tradotta, non un placeholder fisso")

	hud.free()
	host.free()
