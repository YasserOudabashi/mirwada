extends "res://tests/test_case.gd"
## US-334 — SynergySources.tag_sinergia_globali() somma i tag di inventario
## equipaggiato+sigilli (Inventory/Equipment, gia' US-306/317), pet, talenti
## e stanze. Non risolve sinergie: verifica solo che la somma raggiunga i
## conteggi richiesti da una sinergia reale dei dati (sinergia_crescita_pozione).


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/PetSystem") != null:
		_n("/root/PetSystem").call("pulisci")
	if _n("/root/BaseSystem") != null:
		_n("/root/BaseSystem").call("pulisci")
	if _n("/root/TalentSystem") != null:
		_n("/root/TalentSystem").call("pulisci")
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")


func test_nessuna_fonte_nessun_tag() -> void:
	assert_true((_n("/root/SynergySources").call("tag_sinergia_globali") as Dictionary).is_empty(),
		"niente pet, talenti o stanze -> nessun tag")


func test_somma_pet_stanze_e_talenti() -> void:
	var ss: Node = _n("/root/SynergySources")
	var ps: Node = _n("/root/PetSystem")
	var ts: Node = _n("/root/TalentSystem")
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")

	ps.call("imposta_pet", "lupo_ombra")   # tag: bestia, crescita
	ts.call("concedi", "pollice_verde")   # effetto: tag_grant pozione
	inv.call("aggiungi", "cuoio_conciato", 1)
	bs.call("costruisci", "giardino")   # tag: crescita
	inv.call("aggiungi", "lingotto_ferro", 2)
	inv.call("aggiungi", "cristallo_grezzo", 1)
	bs.call("costruisci", "laboratorio")   # tag: pozione

	var tag: Dictionary = ss.call("tag_sinergia_globali")
	assert_eq(int(tag.get("crescita", 0)), 2, "pet + giardino: 2 fonti di crescita")
	assert_eq(int(tag.get("pozione", 0)), 2, "talento + laboratorio: 2 fonti di pozione")
	assert_true(tag.has("bestia"), "il tag della specie del pet e' incluso")


## sinergia_crescita_pozione (data/synergies/core.json) richiede crescita:2 e
## pozione:2 da almeno 2 fonti diverse tra stanza/ingrediente/pet - qui la
## copriamo con pet+stanza+talento, senza toccare gli ingredienti coltivati.
func test_sinergia_crescita_pozione_raggiungibile() -> void:
	var ss: Node = _n("/root/SynergySources")
	var gd: Node = _n("/root/GameData")
	_n("/root/PetSystem").call("imposta_pet", "lupo_ombra")
	_n("/root/TalentSystem").call("concedi", "pollice_verde")
	var inv: Node = _n("/root/Inventory")
	var bs: Node = _n("/root/BaseSystem")
	inv.call("aggiungi", "cuoio_conciato", 1)
	bs.call("costruisci", "giardino")
	inv.call("aggiungi", "lingotto_ferro", 2)
	inv.call("aggiungi", "cristallo_grezzo", 1)
	bs.call("costruisci", "laboratorio")

	var syn: Dictionary = gd.call("get_synergy", "sinergia_crescita_pozione")
	var richiesti: Dictionary = syn.get("richiede_tag", {})
	assert_false(richiesti.is_empty(), "premessa: la sinergia esiste nei dati")
	var tag: Dictionary = ss.call("tag_sinergia_globali")
	for t in richiesti:
		assert_true(int(tag.get(t, 0)) >= int(richiesti[t]),
			"tag '%s': %d disponibili, ne servono %d" % [t, int(tag.get(t, 0)), int(richiesti[t])])
