extends "res://tests/test_case.gd"
## US-811 — modalita' negozio nella pagina dialogo: DialogueEngine.
## apri_vendita/QuestSystem.apri_vendita aprono compra/vendi nella stessa
## pagina (nessuna scena separata).

const PageDialogo := preload("res://scenes/pages/page_dialogo.tscn")
## Sidon vende cardine_arrugginito_di_una_porta_perduta (Sequenza 9, valore
## 3) fra i 60 ingredienti aggiunti al suo listino da US-809b.
const ITEM_DA_3 := "cardine_arrugginito_di_una_porta_perduta"


func _root() -> Node: return Engine.get_main_loop().root
func _book() -> Node: return _root().get_node("Book")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _pr() -> Node: return _root().get_node("Progression")
func _inv() -> Node: return _root().get_node("Inventory")


func prepara() -> void:
	_de().call("termina")
	_book().call("azzera")
	_root().get_tree().paused = false
	_pr().call("configura", "twilight_giant", 9)
	_root().get_node("KnowledgeStore").call("dimentica_tutto")
	_inv().call("pulisci")


func _monta_pagina() -> Node:
	var p: Node = PageDialogo.instantiate()
	_root().add_child(p)
	return p


## Apre la vendita guidando davvero il dialogo di Sidon (effetto apri_vendita
## reale della scelta "Fammi vedere la merce", dlg_sidon.json n1, indice 0),
## non un'emissione diretta del segnale: esercita anche DialogueEngine.
func _apri_vendita_sidon(p: Node) -> void:
	_de().call("avvia", "dlg_sidon", "npc_sidon")
	_de().call("scegli", 0)
	p.call("aggiorna")


func test_apri_vendita_da_dialogo_reale() -> void:
	var p: Node = _monta_pagina()
	_apri_vendita_sidon(p)
	assert_true(p.call("in_negozio"), "la scelta di dialogo apre la modalita' negozio")
	p.free()


func test_compra_un_item_scala_le_monete() -> void:
	var p: Node = _monta_pagina()
	_inv().call("aggiungi", "moneta_comune", 10)
	_apri_vendita_sidon(p)

	var res: Dictionary = p.call("compra", ITEM_DA_3)
	assert_true(bool(res.get("ok", false)), "compra riuscita con fondi sufficienti")
	assert_eq(int(_inv().call("conta", ITEM_DA_3)), 1, "l'item entra in Inventory")
	assert_eq(int(_inv().call("conta", "moneta_comune")), 7, "10 - 3 = 7 monete")
	p.free()


func test_compra_senza_fondi_e_rifiutata() -> void:
	var p: Node = _monta_pagina()
	_inv().call("aggiungi", "moneta_comune", 2)   # meno del valore (3)
	_apri_vendita_sidon(p)

	var res: Dictionary = p.call("compra", ITEM_DA_3)
	assert_false(bool(res.get("ok", false)), "compra rifiutata senza fondi sufficienti")
	assert_eq(int(_inv().call("conta", ITEM_DA_3)), 0, "niente item")
	assert_eq(int(_inv().call("conta", "moneta_comune")), 2, "monete invariate")
	p.free()


func test_vendi_un_item_aggiunge_meta_valore() -> void:
	var p: Node = _monta_pagina()
	_inv().call("aggiungi", ITEM_DA_3, 1)
	_apri_vendita_sidon(p)

	var res: Dictionary = p.call("vendi", ITEM_DA_3)
	assert_true(bool(res.get("ok", false)), "vendita riuscita")
	assert_eq(int(_inv().call("conta", ITEM_DA_3)), 0, "l'item esce dall'Inventory")
	# valore 3 / 2 = 1 (arrotondato per difetto, e comunque >= minimo 1).
	assert_eq(int(_inv().call("conta", "moneta_comune")), 1, "meta' valore arrotondato per difetto")
	p.free()


func test_chiudi_esce_dal_negozio() -> void:
	var p: Node = _monta_pagina()
	_apri_vendita_sidon(p)
	assert_true(p.call("in_negozio"), "negozio aperto")

	var chiudi: Button = null
	for c in p.get_children():
		if c is Button and str(c.text) == tr("BOOK_NEGOZIO_CHIUDI"):
			chiudi = c
	assert_true(chiudi != null, "il bottone Chiudi e' a schermo")
	chiudi.pressed.emit()
	assert_false(p.call("in_negozio"), "Chiudi esce dalla modalita' negozio")
	p.free()
