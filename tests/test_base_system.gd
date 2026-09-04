extends "res://tests/test_case.gd"
## US-326 — schema della base e delle 4 stanze.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/BaseSystem") != null:
		_n("/root/BaseSystem").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")


func test_vocabolario_stanze() -> void:
	var gd: Node = _n("/root/GameData")
	assert_eq((gd.call("room_types") as Array).size(), 4, "4 tipi di stanza")
	assert_eq((gd.call("room_levels", "laboratorio") as Array).size(), 2, "2 livelli per il laboratorio")


func test_non_costruita_di_default() -> void:
	var bs: Node = _n("/root/BaseSystem")
	assert_eq(bs.call("livello", "laboratorio"), 0, "0 = non costruita")
	assert_eq(bs.call("bonus", "laboratorio"), {}, "nessun bonus senza costruzione")


func test_costruisci_sale_a_livello_1_e_consuma_il_costo() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "lingotto_ferro", 2)
	inv.call("aggiungi", "cristallo_grezzo", 1)

	assert_true(bs.call("costruisci", "laboratorio"), "costruisci riesce con tutto il costo")
	assert_eq(bs.call("livello", "laboratorio"), 1, "livello 1")
	assert_eq(inv.call("conta", "lingotto_ferro"), 0, "materiali consumati")
	var b: Dictionary = bs.call("bonus", "laboratorio")
	assert_eq(int(b.get("rischio_esperimento")), 20, "bonus del livello 1")


func test_costruisci_senza_materiali_rifiuta_senza_consumo() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "lingotto_ferro", 1)   # ne servono 2

	assert_false(bs.call("costruisci", "laboratorio"), "materiali insufficienti -> rifiuto")
	assert_eq(bs.call("livello", "laboratorio"), 0, "ancora non costruita")
	assert_eq(inv.call("conta", "lingotto_ferro"), 1, "e non consuma nulla")


func test_potenzia_richiede_gia_costruita() -> void:
	assert_false(_n("/root/BaseSystem").call("potenzia", "laboratorio"), "non costruita -> potenzia rifiuta")


func test_potenzia_sale_di_livello_col_bonus_giusto() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "lingotto_ferro", 6)
	inv.call("aggiungi", "cristallo_grezzo", 4)
	bs.call("costruisci", "laboratorio")   # consuma 2+1, resta 4+3

	assert_true(bs.call("potenzia", "laboratorio"), "potenzia riesce")
	assert_eq(bs.call("livello", "laboratorio"), 2, "livello 2")
	assert_eq(inv.call("conta", "lingotto_ferro"), 0, "il costo del livello 2 e' stato consumato")
	assert_eq(int((bs.call("bonus", "laboratorio") as Dictionary).get("rischio_esperimento")), 40,
		"bonus del livello 2, non la somma dei due")


func test_oltre_il_massimo_rifiuta() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	for i in 3:
		inv.call("aggiungi", "lingotto_ferro", 10)
		inv.call("aggiungi", "cristallo_grezzo", 10)
	bs.call("costruisci", "laboratorio")
	bs.call("potenzia", "laboratorio")   # -> livello 2, il massimo dei dati
	assert_false(bs.call("potenzia", "laboratorio"), "gia' al massimo -> rifiuto")


func test_round_trip_del_save() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "cuoio_conciato", 1)
	bs.call("costruisci", "giardino")
	var snap: Dictionary = bs.call("per_salvataggio")
	bs.call("pulisci")
	assert_eq(bs.call("livello", "giardino"), 0, "svuotato")
	bs.call("da_salvataggio", snap)
	assert_eq(bs.call("livello", "giardino"), 1, "livello tornato dal save")


func test_da_salvataggio_non_fidato() -> void:
	var bs: Node = _n("/root/BaseSystem")
	bs.call("da_salvataggio", "non un oggetto")
	assert_eq(bs.call("livello", "laboratorio"), 0, "raw non-oggetto -> nessuna stanza")
	bs.call("da_salvataggio", {"stanza_inventata": 3, "laboratorio": 99})
	assert_eq(bs.call("livello", "stanza_inventata"), 0, "tipo fuori vocabolario scartato")
	assert_eq(bs.call("livello", "laboratorio"), 2, "livello oltre il massimo dei dati clampato (2 livelli)")
