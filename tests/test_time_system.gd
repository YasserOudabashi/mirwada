extends "res://tests/test_case.gd"
## US-604 — TimeSystem: il momento avanza, e_notte() e' coerente, la fase
## lunare avanza sul ciclo lungo, l'eclissi e' un evento schedulato/forzabile,
## il ciclo si ferma in pausa. time_in_state {stato: notte} entra in EventTracker.

const SPM := 120.0  # data/balance.json tempo.secondi_per_momento


func _root() -> Node: return Engine.get_main_loop().root
func _ts() -> Node: return _root().get_node("TimeSystem")
func _et() -> Node: return _root().get_node("EventTracker")


func prepara() -> void:
	_ts().call("da_salvataggio", {})  # tick = 0, momento "alba"
	_ts().call("imposta_pausa", false)
	_et().call("azzera")


func test_il_momento_avanza_col_tempo() -> void:
	var ts: Node = _ts()
	assert_eq(str(ts.call("momento")), "alba", "si parte all'alba")
	var visti: Array = []
	var cb := func(m: String) -> void: visti.append(m)
	ts.connect("momento_cambiato", cb)
	ts.call("avanza", SPM)
	assert_eq(str(ts.call("momento")), "mezzogiorno", "dopo un momento: mezzogiorno")
	ts.call("avanza", SPM)
	assert_eq(str(ts.call("momento")), "crepuscolo", "poi crepuscolo")
	ts.call("avanza", SPM)
	assert_eq(str(ts.call("momento")), "notte_fonda", "poi notte_fonda")
	ts.call("avanza", SPM)
	assert_eq(str(ts.call("momento")), "alba", "il ciclo torna all'alba")
	ts.disconnect("momento_cambiato", cb)
	assert_eq(visti.size(), 4, "un segnale momento_cambiato per ogni passaggio")


func test_e_notte_coerente() -> void:
	var ts: Node = _ts()
	assert_false(ts.call("e_notte"), "alba non e' notte")
	ts.call("avanza", SPM)
	assert_false(ts.call("e_notte"), "mezzogiorno non e' notte")
	ts.call("avanza", SPM)
	assert_true(ts.call("e_notte"), "crepuscolo e' notte")
	ts.call("avanza", SPM)
	assert_true(ts.call("e_notte"), "notte_fonda e' notte")


func test_time_in_state_notte_entra_in_eventtracker() -> void:
	var ts: Node = _ts()
	ts.call("avanza", SPM * 2)  # fino a crepuscolo (notte)
	assert_true(ts.call("e_notte"), "siamo di notte")
	ts.call("avanza", 10.0)
	assert_gt(_et().call("count", "time_in_state", {"stato": "notte"}), 0.0,
		"TimeSystem emette time_in_state {stato: notte} mentre e' notte")


func test_la_fase_lunare_avanza_sul_ciclo_lungo() -> void:
	var ts: Node = _ts()
	assert_eq(str(ts.call("fase_lunare")), "nuova", "si parte a luna nuova")
	# 3 giorni (giorni_per_fase_lunare) * 4 momenti * SPM per il primo passaggio
	ts.call("avanza", SPM * 4 * 3)
	assert_eq(str(ts.call("fase_lunare")), "crescente", "dopo 3 giorni: crescente")
	assert_false(str(ts.call("fase_lunare")) == "eclissi", "l'eclissi non e' una tappa del ciclo")


func test_eclissi_e_un_evento_schedulato_e_forzabile() -> void:
	var ts: Node = _ts()
	var segnali: Array = []  # Array: catturato per riferimento dalla lambda
	var c1 := func() -> void: segnali.append("iniziata")
	var c2 := func() -> void: segnali.append("finita")
	ts.connect("eclissi_iniziata", c1)
	ts.connect("eclissi_finita", c2)
	ts.call("forza_eclissi")
	assert_true(ts.call("in_eclissi"), "eclissi in corso dopo forza_eclissi")
	assert_eq(str(ts.call("fase_lunare")), "eclissi", "fase_lunare() = 'eclissi' durante l'eclissi")
	assert_eq(segnali.count("iniziata"), 1, "segnale eclissi_iniziata")
	ts.call("avanza", 1000.0)  # oltre durata_eclissi_s
	assert_false(ts.call("in_eclissi"), "l'eclissi finisce a scadenza")
	assert_ne(str(ts.call("fase_lunare")), "eclissi", "tornati a una fase normale")
	assert_eq(segnali.count("finita"), 1, "segnale eclissi_finita")
	ts.disconnect("eclissi_iniziata", c1)
	ts.disconnect("eclissi_finita", c2)


func test_il_ciclo_si_ferma_in_pausa() -> void:
	var ts: Node = _ts()
	ts.call("imposta_pausa", true)
	ts.call("_process", 99999.0)  # _process rispetta la pausa
	assert_eq(str(ts.call("momento")), "alba", "in pausa il tempo non scorre")
	ts.call("imposta_pausa", false)


func test_round_trip_del_tempo() -> void:
	var ts: Node = _ts()
	ts.call("avanza", SPM * 2 + 5.0)
	var snap: Dictionary = ts.call("per_salvataggio")
	ts.call("da_salvataggio", {})
	assert_eq(str(ts.call("momento")), "alba", "reset")
	ts.call("da_salvataggio", snap)
	assert_eq(str(ts.call("momento")), "crepuscolo", "momento ripristinato dal save")
