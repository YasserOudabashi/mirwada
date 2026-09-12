extends "res://tests/test_case.gd"
## US-310 — concoction v2: prepara una ricetta consumabile, ottieni un item
## con una qualita'. Percorso separato dalla concoction di avanzamento.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/Inventory") != null:
		_n("/root/Inventory").call("pulisci")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")


func _fornisci(recipe_id: String) -> void:
	var gd: Node = _n("/root/GameData")
	var inv: Node = _n("/root/Inventory")
	for ing in (gd.call("get_recipe", recipe_id).get("ingredienti", {}) as Dictionary):
		inv.call("aggiungi", ing, int(gd.call("get_recipe", recipe_id)["ingredienti"][ing]))


func test_prepara_una_base_da_ricetta_nota() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	_fornisci("ric_cura_minore")
	var r: Dictionary = ps.call("prepara", "ric_cura_minore")
	assert_true(r.get("ok", false), "prepara riesce: %s" % r.get("reason"))
	assert_eq(r.get("item_id"), "pozione_cura_minore", "output corretto")
	assert_eq(r.get("qualita"), "pura", "qualita' = qualita_base (nessun bonus stanza/talento ancora)")
	assert_eq(inv.call("conta", "pozione_cura_minore"), 1, "l'item e' nell'inventario")
	assert_eq(inv.call("conta", "petalo_solare"), 0, "l'ingrediente e' stato consumato")


func test_ingredienti_mancanti_non_consuma() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	inv.call("aggiungi", "petalo_solare", 1)   # ne serve 1 + acqua_sorgiva 1
	var r: Dictionary = ps.call("prepara", "ric_cura_minore")
	assert_false(r.get("ok", true), "senza tutti gli ingredienti non si prepara")
	assert_eq(r.get("reason"), "ingredienti_mancanti", "esito gestito")
	assert_eq(inv.call("conta", "petalo_solare"), 1, "e non consuma nulla")


func test_ricetta_inesistente_e_ignota() -> void:
	var ps: Node = _n("/root/PotionSystem")
	assert_eq(ps.call("prepara", "ricetta_falsa").get("reason"), "ricetta_inesistente", "id ignoto")
	_fornisci("ric_cura_maggiore")   # avanzata, non nota
	var r: Dictionary = ps.call("prepara", "ric_cura_maggiore")
	assert_eq(r.get("reason"), "ricetta_ignota", "una avanzata non scoperta non si prepara")


## US-1106 (fase 11): ignora_scoperta:true fa preparare una ricetta anche se
## il GIOCATORE non l'ha ancora scoperta - un NPC alchimista conosce la sua
## ricetta a prescindere. ric_cura_maggiore (avanzata, non nota di default,
## US-327) e' lo stesso caso del test sopra: qui il bypass la fa riuscire.
func test_ignora_scoperta_prepara_una_ricetta_non_ancora_scoperta() -> void:
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	_fornisci("ric_cura_maggiore")
	assert_false(bool(ps.call("ricetta_nota", "ric_cura_maggiore")), "il giocatore non la conosce ancora")
	var r: Dictionary = ps.call("prepara", "ric_cura_maggiore", true)
	assert_true(bool(r.get("ok", false)), "con ignora_scoperta:true riesce comunque: %s" % r.get("reason"))
	assert_eq(inv.call("conta", "pozione_cura_maggiore"), 1, "l'oggetto e' prodotto")
	assert_false(bool(ps.call("ricetta_nota", "ric_cura_maggiore")),
		"il bypass NON insegna la ricetta al giocatore (resta ignota dopo)")


func test_avanzata_diventa_preparabile_col_flag_conoscenza() -> void:
	var ps: Node = _n("/root/PotionSystem")
	assert_false(ps.call("ricetta_nota", "ric_cura_maggiore"), "avanzata: ignota di default")
	_n("/root/KnowledgeStore").call("impara", "ricetta:ric_cura_maggiore")
	assert_true(ps.call("ricetta_nota", "ric_cura_maggiore"), "il flag KnowledgeStore la rende nota")
	_fornisci("ric_cura_maggiore")
	assert_true(ps.call("prepara", "ric_cura_maggiore").get("ok", false), "e ora si prepara")


func test_non_tocca_la_concoction_di_avanzamento() -> void:
	var ps: Node = _n("/root/PotionSystem")
	ps.call("scarta_pozione")   # stato pulito della concoction di avanzamento
	assert_true((ps.call("pozione_pronta") as Dictionary).is_empty(), "premessa: nessuna pozione di avanzamento")
	_fornisci("ric_vigore")
	ps.call("prepara", "ric_vigore")
	assert_true((ps.call("pozione_pronta") as Dictionary).is_empty(),
		"preparare una consumabile NON crea una pozione di avanzamento")
