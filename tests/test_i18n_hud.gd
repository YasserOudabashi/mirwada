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

	var barra: Control = hud.get_node("Root/Vitali/HP/Barra")
	var hp_max: float = stats.get_stat("hp_max")
	assert_almost_eq(float(barra.get("obiettivo")), float(stats.get("hp")) / hp_max, "barra hp inizializzata")
	assert_almost_eq(float(barra.get("pieno")), float(barra.get("obiettivo")), "la prima volta senza scia")

	stats.set("hp", float(stats.get("hp")) - 25.0)
	assert_almost_eq(float(barra.get("obiettivo")), float(stats.get("hp")) / hp_max, "barra hp segue il segnale")
	assert_almost_eq(float(barra.get("pieno")), float(barra.get("obiettivo")), "un colpo: il pieno scende subito")
	assert_gt(float(barra.get("scia")), float(barra.get("pieno")), "e la scia del danno resta dietro (US-8B75d)")
	var numero: Label = hud.get_node("Root/Vitali/HP/Numero")
	assert_true(numero.text.contains(str(roundi(float(stats.get("hp"))))), "il numero dice la vita nuova")
	hud.call("_process", 0.1)
	assert_gt(numero.modulate.a, 0.5, "e si vede appena cambia")
	hud.call("_process", 5.0)
	hud.call("_process", 0.1)
	assert_almost_eq(numero.modulate.a, 0.0, "poi sparisce: i numeri solo quando servono")

	hud.free()
	host.free()


## US-8B75d (richiesta dell'utente): mentre si gioca la hotbar mostra solo il simbolo dell'abilita', mai il nome
## (il nome sta nel libro); lo slot sa quale abilita' ha e lo slot vuoto non ha glifo.
func test_la_hotbar_mostra_solo_simboli() -> void:
	var host := Node.new()
	host.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	host.add_child(stats)
	Engine.get_main_loop().root.add_child(host)
	var root: Node = Engine.get_main_loop().root
	root.get_node("Progression").call("configura", "twilight_giant", 9)
	var owned: Array = root.get_node("AbilityEngine").call("hotbar", host)
	assert_true(owned.size() >= 1, "il Twilight Giant a Sequenza 9 ha almeno un'abilita' nei tasti")
	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	var slot0: Control = hud.get_node("Root/Hotbar/Slot0")
	assert_eq(str(slot0.get("abilita")), str(owned[0]), "lo slot 0 ha l'abilita' del tasto 1")
	assert_eq(slot0.find_children("*", "Label", true, false).size(), 0, "e nessuna scritta")
	assert_eq(hud.get_node("Root/Hotbar").find_children("*", "Label", true, false).size(), 0, "nessun nome nella hotbar")
	if owned.size() < 4:
		assert_false((hud.get_node("Root/Hotbar/Slot3/Glifo") as CanvasItem).visible, "lo slot vuoto non ha glifo")
	hud.free()
	host.free()


## US-802: lo slot lampeggia quando parte la sua abilita' - feedback a colpo
## d'occhio che "hai usato un'abilita'", oltre al numero di spiritualita'.
func test_hotbar_lampeggia_quando_parte_l_abilita() -> void:
	var host := Node.new()
	host.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	host.add_child(stats)
	var root: Node = Engine.get_main_loop().root
	root.add_child(host)
	root.get_node("Progression").call("configura", "twilight_giant", 9)
	root.get_node("AbilityEngine").call("clear_cooldowns")
	var owned: Array = root.get_node("AbilityEngine").call("owned_abilities", host)

	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	var slot0: Control = hud.get_node("Root/Hotbar/Slot0")
	assert_eq(float(slot0.get("lampo")), 0.0, "fermo")

	root.get_node("AbilityEngine").call("execute", str(hud.get_node("Root/Hotbar/Slot0").get("abilita")), host)
	assert_gt(float(slot0.get("lampo")), 0.0, "lo slot che ha lanciato l'abilita' lampeggia")
	assert_gt(float(slot0.get("ricarica")), 0.0, "e si vela per la ricarica")

	hud.free()
	host.free()


## 2026-10-29 / US-8B75d: le poche scritte dell'HUD (i numeri) hanno il contorno scuro, e le barre i colori dei dati.
func test_le_scritte_dell_hud_hanno_il_contorno() -> void:
	var hud: CanvasLayer = HudScene.instantiate()
	Engine.get_main_loop().root.add_child(hud)
	var etichette: Array = hud.find_children("*", "Label", true, false)
	assert_eq(etichette.size(), 2, "solo i numeri di vita e spirito")
	for l in etichette:
		assert_gt(float((l as Label).get_theme_constant("outline_size")), 0.0, "%s col contorno" % l.name)
		assert_eq((l as Label).get_theme_color("font_outline_color"), Color("#181425"), "%s del colore del contorno" % l.name)
	var cfg: Dictionary = Engine.get_main_loop().root.get_node("GameData").call("get_ui_hud")
	for coppia in [["HP", "vita"], ["SP", "spirito"], ["Acting", "recitazione"]]:
		var b: Control = hud.get_node("Root/Vitali/%s/Barra" % coppia[0])
		assert_eq(b.get("cfg"), cfg["barre"][coppia[1]], "la barra %s coi colori dei dati" % coppia[0])
		assert_true((hud.get_node("Root/Vitali/%s/Emblema" % coppia[0]) as TextureRect).texture != null, "e il suo emblema")
	hud.free()
