extends "res://tests/test_case.gd"
## US-413 — CRITERIO DI USCITA della fase 4: una sinergia che nasce SOLO
## combinando pet + stanza + talento si attiva quando le tre fonti sono in
## gioco (e non prima), il suo effetto si misura, e ZERO righe di codice la
## nominano. Come US-219 (Twilight Giant) e US-335 (fase 3).

const StatsComponent := preload("res://scripts/stats_component.gd")
const SYN := "sinergia_dottrina_del_guardiano"

var _p: Node2D = null


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	for vecchio in Engine.get_main_loop().root.get_tree().get_nodes_in_group("player"):
		vecchio.free()
	for a in ["/root/Inventory", "/root/Equipment", "/root/BaseSystem", "/root/PetSystem",
			"/root/TalentSystem", "/root/SynergyEngine"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	for a in ["/root/TalentTracker", "/root/EventTracker"]:
		if _n(a) != null:
			_n(a).call("azzera")
	_p = Node2D.new()
	_p.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	st.call("configure_from_balance", 9)
	_p.add_child(st)
	Engine.get_main_loop().root.add_child(_p)


func _fine() -> void:
	if _n("/root/SynergyEngine") != null:
		_n("/root/SynergyEngine").call("pulisci")
	if is_instance_valid(_p):
		_p.free()


func _se() -> Node:
	return _n("/root/SynergyEngine")


func _costruisci(tipo: String) -> void:
	var bs: Node = _n("/root/BaseSystem")
	for item_id in bs.call("costo_prossimo", tipo):
		_n("/root/Inventory").call("aggiungi", item_id, int(bs.call("costo_prossimo", tipo)[item_id]))
	bs.call("costruisci", tipo)


func test_la_sinergia_di_uscita_si_attiva_solo_con_pet_stanza_talento() -> void:
	assert_false((_n("/root/GameData").call("get_synergy", SYN) as Dictionary).is_empty(),
		"la sinergia del criterio di uscita esiste nei dati")

	# solo la stanza: conoscenza, ma non guerra ne' non_letale
	_costruisci("biblioteca")
	_se().call("rivaluta")
	assert_false(_se().call("e_attiva", SYN), "solo la stanza: non basta")

	# stanza + pet: aggiunge guerra, manca ancora non_letale
	_n("/root/PetSystem").call("imposta_pet", "lupo_cinereo")
	_se().call("rivaluta")
	assert_false(_se().call("e_attiva", SYN), "stanza + pet: non basta")

	# stanza + pet + talento: ora ci sono tutti e tre i tag
	var base_dif: float = _p.get_node("StatsComponent").call("get_stat", "difesa")
	_n("/root/TalentSystem").call("concedi", "clemenza")  # tag_grant non_letale
	_se().call("rivaluta")
	assert_true(_se().call("e_attiva", SYN),
		"pet + stanza + talento insieme -> la sinergia si attiva")
	assert_almost_eq(_p.get_node("StatsComponent").call("get_stat", "difesa"), base_dif + 5.0,
		"il suo effetto si misura: modifica_stat difesa +5")

	# tolgo il talento -> si spegne e l'effetto sparisce
	_n("/root/TalentSystem").call("pulisci")
	_se().call("rivaluta")
	assert_false(_se().call("e_attiva", SYN), "tolto il talento -> disattivata")
	assert_almost_eq(_p.get_node("StatsComponent").call("get_stat", "difesa"), base_dif,
		"e il +5 alla difesa e' stato tolto")
	_fine()


func test_nessun_codice_nomina_la_sinergia_di_uscita() -> void:
	var colpevoli: PackedStringArray = []
	for dir in ["res://scripts", "res://scripts/pages"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			for riga in FileAccess.get_file_as_string(dir + "/" + f).split("\n"):
				if riga.split("#")[0].contains(SYN):
					colpevoli.append("%s: %s" % [f, riga.strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"nessuna riga di codice nomina %s: %s" % [SYN, colpevoli])
	_fine()
