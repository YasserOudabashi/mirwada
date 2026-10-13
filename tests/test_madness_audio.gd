extends "res://tests/test_case.gd"
## US-214 — Layer audio della follia: bus whisper guidato dalla follia,
## duck della musica a soglia 80, disattiva_sussurri, one-shot casuali.

func _am() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AudioManager")


func _wi() -> int:
	return AudioServer.get_bus_index("whisper")


func _mi() -> int:
	return AudioServer.get_bus_index("music")


func prepara() -> void:
	var am: Node = _am()
	if am != null:
		am.call("imposta_accessibilita", "disattiva_sussurri", false)
		am.call("aggiorna_follia", 0.0)


func test_whisper_muto_sotto_la_prima_soglia() -> void:
	var am: Node = _am()
	am.call("aggiorna_follia", 5.0)
	assert_true(AudioServer.is_bus_mute(_wi()), "sotto follia 10 il bus whisper e' muto")


func test_volume_del_whisper_guidato_dalla_follia() -> void:
	var am: Node = _am()
	am.call("aggiorna_follia", 35.0)  # soglia madness_min 30 -> volume_db -24
	assert_false(AudioServer.is_bus_mute(_wi()), "whisper attivo a follia 35")
	assert_almost_eq(AudioServer.get_bus_volume_db(_wi()), -24.0, "volume della soglia 30")

	am.call("aggiorna_follia", 85.0)  # soglia 80 -> -10
	assert_almost_eq(AudioServer.get_bus_volume_db(_wi()), -10.0, "volume sale con la follia")


func test_duck_della_musica_a_soglia_80() -> void:
	var am: Node = _am()
	var base: float = AudioServer.get_bus_volume_db(_mi())
	am.call("aggiorna_follia", 85.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(_mi()), base - 20.0, "musica abbassata di duck_music_db")
	am.call("aggiorna_follia", 50.0)  # sotto 80
	assert_almost_eq(AudioServer.get_bus_volume_db(_mi()), base, "musica ripristinata")


func test_disattiva_sussurri_silenzia_senza_toccare_la_meccanica() -> void:
	var am: Node = _am()
	am.call("aggiorna_follia", 85.0)
	assert_false(AudioServer.is_bus_mute(_wi()), "prima e' attivo")

	am.call("imposta_accessibilita", "disattiva_sussurri", true)
	assert_true(AudioServer.is_bus_mute(_wi()), "disattiva_sussurri -> bus muto")

	# la follia (meccanica) e' un altro autoload: qui non la tocchiamo,
	# ma verifichiamo che l'audio resti muto anche ri-aggiornando
	am.call("aggiorna_follia", 90.0)
	assert_true(AudioServer.is_bus_mute(_wi()), "resta muto a follia piu' alta")


func test_one_shot_casuali_solo_sopra_25() -> void:
	var am: Node = _am()
	am.call("aggiorna_follia", 10.0)
	assert_false(am.call("tenta_one_shot"), "sotto follia 25: nessun one-shot")
	am.call("aggiorna_follia", 40.0)
	assert_true(am.call("tenta_one_shot"), "sopra 25: one-shot possibile")

	am.call("imposta_accessibilita", "disattiva_sussurri", true)
	assert_false(am.call("tenta_one_shot"), "disattiva_sussurri sopprime anche i one-shot")


func test_nomi_sussurro_con_fallback() -> void:
	var am: Node = _am()
	am.call("imposta_nomi_npc", [])   # US-612: nomi_sussurro unisce Ancore + NPC incontrati
	am.call("imposta_nomi_sussurro", [])
	assert_gt(float((am.call("nomi_sussurro") as Array).size()), 0.0, "fallback generico se non ci sono nomi")
	am.call("imposta_nomi_sussurro", ["Mirco", "Ancora del giocatore"])
	assert_eq((am.call("nomi_sussurro") as Array).size(), 2, "usa i nomi forniti (NPC/Ancore)")
	am.call("imposta_nomi_sussurro", [])
