extends "res://tests/test_case.gd"
## US-007 — componente statistiche.

## preload esplicito, MAI la class_name globale: risolvere una classe globale
## da uno script caricato a runtime dal runner manda Godot 4.3 in stallo.
const Stats := preload("res://scripts/stats_component.gd")


func _make() -> Stats:
	var s: Stats = Stats.new()
	s.configure_from_balance(9)
	return s


func test_baseline_viene_dai_dati() -> void:
	var s: Stats = _make()
	# hp_curve["9"] = 100, spiritualita_curve["9"] = 50 in data/balance.json.
	# Se questi cambiano nel JSON il test cambia con loro: e' voluto, sono dati.
	assert_almost_eq(s.get_stat("hp_max"), 100.0, "hp_max dalla curva")
	assert_almost_eq(s.get_stat("spiritualita_max"), 50.0, "spiritualita_max dalla curva")
	assert_almost_eq(s.hp, 100.0, "hp pieni all'avvio")
	assert_false(s.is_dead(), "non morto all'avvio")
	s.free()


func test_tutte_le_stat_richieste_esistono() -> void:
	var s: Stats = _make()
	for key in Stats.STAT_KEYS:
		assert_true(s.get_base(key) >= 0.0, "stat '%s' presente" % key)
	s.free()


func test_applicazione_di_un_modificatore() -> void:
	var s: Stats = _make()
	s.apply_modifier("buff_prova", {"hp_max": 50.0, "velocita": 10.0})
	assert_almost_eq(s.get_stat("hp_max"), 150.0, "hp_max con modificatore")
	assert_almost_eq(s.get_stat("velocita"), 100.0, "velocita con modificatore")
	assert_true(s.has_modifier("buff_prova"), "modificatore registrato")
	# La base non e' stata toccata: il modificatore e' un layer sopra.
	assert_almost_eq(s.get_base("hp_max"), 100.0, "base intatta")
	s.free()


func test_rimozione_per_id() -> void:
	var s: Stats = _make()
	s.apply_modifier("a", {"difesa": 5.0})
	s.apply_modifier("b", {"difesa": 3.0})
	assert_almost_eq(s.get_stat("difesa"), 8.0, "due modificatori sommati")

	assert_true(s.remove_modifier("a"), "rimozione riuscita")
	# Rimuove ESATTAMENTE il proprio contributo, lascia l'altro.
	assert_almost_eq(s.get_stat("difesa"), 3.0, "resta solo il modificatore b")
	assert_false(s.has_modifier("a"), "a non c'e' piu'")
	assert_true(s.has_modifier("b"), "b c'e' ancora")

	assert_false(s.remove_modifier("inesistente"), "rimuovere un id ignoto e' innocuo")
	s.free()


func test_riapplicare_lo_stesso_id_non_impila() -> void:
	var s: Stats = _make()
	s.apply_modifier("scudo", {"difesa": 10.0})
	s.apply_modifier("scudo", {"difesa": 10.0})
	s.apply_modifier("scudo", {"difesa": 10.0})
	# Sostituisce, non somma: un buff riapplicato non diventa tre buff.
	assert_almost_eq(s.get_stat("difesa"), 10.0, "difesa dopo 3 applicazioni")
	assert_eq(s.modifier_ids().size(), 1, "un solo modificatore registrato")
	s.free()


func test_segnale_hp_changed() -> void:
	var s: Stats = _make()
	var visti: Array = []
	s.hp_changed.connect(func(v: float, m: float) -> void: visti.append([v, m]))

	s.hp = 70.0
	assert_eq(visti.size(), 1, "un segnale emesso")
	assert_almost_eq(float(visti[0][0]), 70.0, "hp riportati nel segnale")
	assert_almost_eq(float(visti[0][1]), 100.0, "hp_max riportati nel segnale")

	# Stesso valore: nessun segnale, altrimenti la UI ridisegna per niente.
	s.hp = 70.0
	assert_eq(visti.size(), 1, "nessun segnale se il valore non cambia")
	s.free()


func test_segnale_died_una_volta_sola() -> void:
	var s: Stats = _make()
	var morti: Array = []
	s.died.connect(func() -> void: morti.append(1))

	s.hp = 0.0
	assert_true(s.is_dead(), "risulta morto")
	assert_eq(morti.size(), 1, "died emesso una volta")

	s.hp = -50.0
	assert_eq(morti.size(), 1, "died non si ripete")
	s.free()


func test_hp_clampati_al_massimo() -> void:
	var s: Stats = _make()
	s.hp = 9999.0
	assert_almost_eq(s.hp, 100.0, "hp non superano hp_max")
	s.free()


func test_hp_scendono_se_scade_un_buff_di_hp_max() -> void:
	var s: Stats = _make()
	s.apply_modifier("vigore", {"hp_max": 100.0})
	s.hp = 200.0
	assert_almost_eq(s.hp, 200.0, "hp pieni col buff attivo")

	s.remove_modifier("vigore")
	# Senza il clamp, l'entita' resterebbe a 200 hp su un massimo di 100.
	assert_almost_eq(s.get_stat("hp_max"), 100.0, "hp_max tornato alla base")
	assert_almost_eq(s.hp, 100.0, "hp riportati entro il nuovo massimo")
	s.free()


func test_spesa_di_spiritualita() -> void:
	var s: Stats = _make()
	assert_true(s.spend_spiritualita(20.0), "spesa entro il disponibile")
	assert_almost_eq(s.spiritualita, 30.0, "spiritualita' scalata")

	# Spesa insufficiente: rifiuta e NON scala nulla, cosi' un'abilita' non
	# parte a meta'.
	assert_false(s.spend_spiritualita(999.0), "spesa oltre il disponibile rifiutata")
	assert_almost_eq(s.spiritualita, 30.0, "spiritualita' invariata dopo il rifiuto")
	s.free()


func test_clear_modifiers() -> void:
	var s: Stats = _make()
	s.apply_modifier("a", {"velocita": 10.0})
	s.apply_modifier("b", {"velocita": 20.0})
	s.clear_modifiers()
	assert_eq(s.modifier_ids().size(), 0, "nessun modificatore residuo")
	assert_almost_eq(s.get_stat("velocita"), 90.0, "velocita tornata alla base")
	s.free()
