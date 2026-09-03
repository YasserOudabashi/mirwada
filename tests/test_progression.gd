extends "res://tests/test_case.gd"
## US-201 — stato di progressione: default dai dati, avanzamento + segnale,
## stat_modifiers applicati/rimossi per id, round-trip del save, migrazione
## dal salvataggio di fase 1, campi non fidati.

const StatsComponent := preload("res://scripts/stats_component.gd")

const SLOT := 901


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SaveSystem")


## Stato pulito prima di ogni test: default dei dati, Sequenza 9.
func prepara() -> void:
	var p: Node = _prog()
	if p != null:
		p.configura("", 9)


func _giocatore_finto() -> Node2D:
	var player := Node2D.new()
	player.add_to_group("player")
	var stats: Node = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.configure_from_balance(9)
	player.add_child(stats)
	Engine.get_main_loop().root.add_child(player)
	return player


func test_stato_iniziale_dai_dati() -> void:
	var p: Node = _prog()
	assert_true(p != null, "autoload Progression presente")
	if p == null:
		return
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var atteso: String = str(gd.call("get_balance", "progressione").get("pathway_default", ""))
	assert_eq(p.pathway(), atteso, "pathway dal default dei dati")
	assert_eq(p.sequence(), 9, "Sequenza iniziale 9")
	assert_false(p.sequence_data().is_empty(), "sequence_data risolve nei dati")
	assert_eq(p.tier(), str(p.sequence_data().get("tier", "")), "tier deriva dai dati della Sequenza")


func test_avanza_decrementa_ed_emette_segnale() -> void:
	var p: Node = _prog()
	var visto: Dictionary = {"n": -1, "v": -1}
	var cb := func(nuova: int, vecchia: int) -> void:
		visto["n"] = nuova
		visto["v"] = vecchia
	p.sequence_changed.connect(cb)
	var ok: bool = p.avanza()
	p.sequence_changed.disconnect(cb)
	assert_true(ok, "avanza riuscito da Sequenza 9")
	assert_eq(p.sequence(), 8, "Sequenza scesa a 8")
	assert_eq(visto["n"], 8, "segnale: nuova = 8")
	assert_eq(visto["v"], 9, "segnale: vecchia = 9")


func test_avanza_si_ferma_a_zero() -> void:
	var p: Node = _prog()
	p.configura("", 0)
	assert_false(p.avanza(), "non si avanza oltre la Sequenza 0")
	assert_eq(p.sequence(), 0, "resta a 0")


func test_stat_modifiers_applicati_e_rimossi_per_id() -> void:
	var p: Node = _prog()
	var player: Node2D = _giocatore_finto()
	var stats: Node = player.get_node("StatsComponent")

	p.configura("", 9)
	assert_true(stats.has_modifier("sequence:9"), "modificatore di Sequenza 9 applicato")
	var mods: Dictionary = p.stat_modifiers()
	if mods.has("hp_max"):
		assert_almost_eq(
			stats.get_stat("hp_max"),
			stats.get_base("hp_max") + float(mods["hp_max"]),
			"hp_max = base + delta della Sequenza")

	p.avanza()
	assert_false(stats.has_modifier("sequence:9"), "vecchio modificatore rimosso all'avanzamento")
	assert_true(stats.has_modifier("sequence:8"), "nuovo modificatore di Sequenza 8 applicato")

	player.free()


func test_round_trip_del_save() -> void:
	var p: Node = _prog()
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)

	p.configura("", 6)
	var snap: Dictionary = {"nome_personaggio": "Enel", "progressione": p.per_salvataggio()}
	assert_true(s.salva(SLOT, snap)["ok"], "salva ok")

	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"], "carica ok")
	var pr: Dictionary = (c["dati"] as Dictionary)["progressione"]
	assert_eq(int(pr["sequence"]), 6, "Sequenza round-trip")
	assert_eq(str(pr["pathway_id"]), p.pathway(), "pathway_id round-trip")

	s.cancella(SLOT)


func test_migrazione_da_salvataggio_di_fase_1() -> void:
	var s: Node = _save()
	if s.esiste(SLOT):
		s.cancella(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/slot_%d.json" % SLOT, FileAccess.WRITE)
	# save di fase 1: schema_version 2, nessun campo progressione
	f.store_string('{"schema_version": 2, "nome_personaggio": "vecchio", "tempo_gioco": 5.0, "posizione": [1, 2], "statistiche": {}, "evocazioni": []}')
	f.close()

	var c: Dictionary = s.carica(SLOT)
	assert_true(c["ok"], "carica ok dopo migrazione")
	assert_true(c["migrato"], "flag migrato")
	var pr: Dictionary = (c["dati"] as Dictionary)["progressione"]
	assert_eq(int(pr["sequence"]), 9, "migrazione: Sequenza 9")
	assert_eq(str(pr["pathway_id"]), "", "migrazione: pathway_id vuoto, risolto poi da Progression")

	s.cancella(SLOT)


func test_da_salvataggio_campi_non_fidati() -> void:
	var p: Node = _prog()
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var default_pid: String = str(gd.call("get_balance", "progressione").get("pathway_default", ""))

	p.da_salvataggio({"pathway_id": 123, "sequence": "molto"})
	assert_eq(p.pathway(), default_pid, "pathway_id di tipo sbagliato -> default dei dati")
	assert_eq(p.sequence(), 9, "sequence di tipo sbagliato -> 9")

	p.da_salvataggio("non un dizionario")
	assert_eq(p.sequence(), 9, "raw non-oggetto -> default sano, nessun crash")
