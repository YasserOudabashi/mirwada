extends "res://tests/test_case.gd"
## US-619 — audio del mondo: audio.json descrive zone (palette/riverbero),
## ambienti giorno/notte per zona, la struttura della musica a layer.
## AudioManager commuta l'ambiente sul ciclo del tempo e sul cambio regione.
## I FILE AUDIO NON LI PRODUCE QUESTO LAVORO (limite dichiarato in progress.txt).

func _root() -> Node: return Engine.get_main_loop().root
func _am() -> Node: return _root().get_node("AudioManager")
func _ws() -> Node: return _root().get_node("WorldState")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _gd() -> Node: return _root().get_node("GameData")


func prepara() -> void:
	_ws().call("pulisci")
	_ts().call("da_salvataggio", {})   # -> alba (giorno)


func test_ambiente_segue_regione_e_momento() -> void:
	var am: Node = _am()
	_ws().call("entra_regione", "marche_crepuscolo")
	am.call("aggiorna_ambiente")
	assert_eq(str(am.call("ambiente_corrente")), "amb_marche_giorno", "di giorno, Marche")
	_ts().call("avanza", 120.0 * 3.0)   # -> notte_fonda
	am.call("aggiorna_ambiente")
	assert_true(_ts().call("e_notte"), "siamo di notte")
	assert_eq(str(am.call("ambiente_corrente")), "amb_marche_notte", "di notte l'ambiente cambia")
	_ws().call("entra_regione", "valle_madre")
	am.call("aggiorna_ambiente")
	assert_eq(str(am.call("ambiente_corrente")), "amb_valle_notte", "cambio regione -> altro ambiente")


func test_struttura_della_musica_a_layer() -> void:
	var mus: Dictionary = _gd().call("get_audio", "music")
	var layer: Dictionary = mus.get("layer", {})
	assert_eq(str(layer.get("sempre_attivo")), "base", "lo stem base e' sempre attivo")
	assert_false((layer.get("in_crossfade", []) as Array).is_empty(), "ci sono stem in crossfade")
	var stati: Array = mus.get("stati", [])
	var sps: Dictionary = layer.get("stato_per_stem", {})
	for s in stati:
		assert_true(sps.has(s), "ogni stato di gioco ha una regola di stem: '%s'" % s)


func test_ogni_zona_musica_delle_regioni_ha_palette_e_ambiente() -> void:
	var mus: Dictionary = _gd().call("get_audio", "music")
	var zone: Dictionary = mus.get("zone", {})
	var amb: Dictionary = mus.get("ambienti", {})
	for r in _gd().call("get_regions"):
		var mz: String = str((r as Dictionary).get("music_zone", ""))
		assert_true(zone.has(mz), "la zona musica '%s' esiste" % mz)
		assert_true((zone[mz] as Dictionary).has("pathway_palette"), "'%s' ha una pathway_palette" % mz)
		assert_true(amb.has(mz), "'%s' ha un ambiente giorno/notte" % mz)
