extends "res://tests/test_case.gd"
## US-019 — bus audio e feedback di colpo (sfx + hitstop + shake insieme).

func _am() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AudioManager")


func test_bus_creati_da_audio_json() -> void:
	for nome in ["music", "sfx", "ambience", "ui", "whisper"]:
		assert_true(AudioServer.get_bus_index(nome) != -1, "bus '%s' creato" % nome)


func test_feedback_emette_lo_shake_dai_dati() -> void:
	var am: Node = _am()
	var visti: Array = []
	var cb := func(i: float) -> void: visti.append(i)
	am.shake_richiesto.connect(cb)

	am.call("feedback", "hit_heavy")  # audio.json: shake 0.5
	Engine.time_scale = 1.0  # ripristina dopo l'hitstop sincrono

	assert_eq(visti.size(), 1, "un evento shake")
	assert_almost_eq(visti[0], 0.5, "intensita' shake dai dati")
	am.shake_richiesto.disconnect(cb)


func test_disattiva_shake_sopprime_lo_shake() -> void:
	var am: Node = _am()
	var visti: Array = []
	var cb := func(_i: float) -> void: visti.append(1)
	am.shake_richiesto.connect(cb)

	am.call("imposta_accessibilita", "disattiva_shake", true)
	am.call("feedback", "hit_heavy")
	Engine.time_scale = 1.0
	am.call("imposta_accessibilita", "disattiva_shake", false)

	assert_eq(visti.size(), 0, "nessuno shake con disattiva_shake")
	am.shake_richiesto.disconnect(cb)


func test_hitstop_parte_e_riduci_hitstop_e_memorizzato() -> void:
	var am: Node = _am()
	am.call("feedback", "hit_light")  # hitstop_ms 40
	assert_true(am.call("hitstop_in_corso"), "hitstop attivo dopo il feedback")
	assert_true(Engine.time_scale < 1.0, "time_scale abbassato durante l'hitstop")
	Engine.time_scale = 1.0

	am.call("imposta_accessibilita", "riduci_hitstop", true)
	assert_eq(am.call("accessibilita", "riduci_hitstop"), true, "opzione memorizzata")
	am.call("imposta_accessibilita", "riduci_hitstop", false)


func test_voce_di_feedback_ignota_non_esplode() -> void:
	var am: Node = _am()
	am.call("feedback", "voce_inventata")
	Engine.time_scale = 1.0
	assert_true(true, "nessun crash su voce ignota")
