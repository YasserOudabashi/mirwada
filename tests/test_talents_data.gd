extends "res://tests/test_case.gd"
## US-330 — schema dei talenti + vocabolario chiuso dei comportamenti-talento.
## Solo dati e caricamento: TalentSystem e' US-331.


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_vocabolario_comportamenti_talento() -> void:
	var tt: Dictionary = _gd().call("tracked_talents")
	assert_true(tt.size() >= 6, "almeno 6 comportamenti-talento")
	for k in ["giocato_di_notte", "distanza_percorsa", "ingredienti_coltivati"]:
		assert_true(tt.has(k), "'%s' nel vocabolario" % k)
		assert_true(str((tt[k] as Dictionary).get("misura", "")) in ["conteggio", "somma", "secondi"],
			"'%s' ha una misura valida" % k)


func test_i_talenti_si_caricano_e_hanno_i_conteggi_minimi() -> void:
	assert_false((_gd().call("get_talent", "costituzione_robusta") as Dictionary).is_empty(),
		"un talento innato si carica")
	assert_true((_gd().call("talents_per_tipo", "innato") as Array).size() >= 4,
		"almeno 4 talenti innati")
	assert_true((_gd().call("talents_per_tipo", "acquisito") as Array).size() >= 8,
		"almeno 8 talenti acquisiti")


func test_ogni_acquisito_ha_uno_sblocco_con_evento_risolvibile() -> void:
	var tt: Dictionary = _gd().call("tracked_talents")
	var eventi: Dictionary = _gd().call("get_tracked_events")
	for tid in _gd().call("talents_per_tipo", "acquisito"):
		var t: Dictionary = _gd().call("get_talent", tid)
		var sb: Dictionary = t.get("sblocco", {})
		var ev: String = str(sb.get("evento", ""))
		assert_true(tt.has(ev) or eventi.has(ev),
			"lo sblocco di '%s' punta a un evento noto ('%s')" % [tid, ev])
		assert_gt(float(sb.get("target", 0.0)), 0.0, "target di '%s' > 0" % tid)


func test_ogni_effetto_e_ben_formato() -> void:
	for tid in _gd().call("talent_ids"):
		var eff: Dictionary = (_gd().call("get_talent", tid) as Dictionary).get("effetto", {})
		assert_true(str(eff.get("tipo", "")) in ["stat_modifier", "tag_grant", "sblocco_sistema"],
			"effetto di '%s' ha un tipo valido" % tid)


func test_gli_innati_non_hanno_sblocco() -> void:
	for tid in _gd().call("talents_per_tipo", "innato"):
		assert_false((_gd().call("get_talent", tid) as Dictionary).has("sblocco"),
			"il talento innato '%s' non ha uno sblocco" % tid)
