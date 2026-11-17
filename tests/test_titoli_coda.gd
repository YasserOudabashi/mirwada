extends "res://tests/test_case.gd"
## 2026-11-17 — I titoli di coda: dopo il finale scorrono il finale, il viaggio (Pathway, Ancore, scelte) e i
## crediti; saltati o finiti, si torna al libro sul colophon.

func _root() -> Node: return Engine.get_main_loop().root


func _testi(t: Node) -> String:
	var out: PackedStringArray = []
	for l in t.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)


func test_i_titoli_raccontano_il_viaggio_e_i_crediti() -> void:
	var gd: Node = _root().get_node("GameData")
	var ks: Node = _root().get_node("KnowledgeStore")
	ks.call("dimentica_tutto")
	ks.call("imposta", "vesna_resta", true)
	_root().get_node("AnchorSystem").call("pulisci")
	_root().get_node("AnchorSystem").call("register", "anchor_mirco")
	var t: CanvasLayer = preload("res://scripts/titoli_coda.gd").new()
	t.set("finale_id", "apoteosi")
	_root().add_child(t)
	var testo: String = _testi(t)
	assert_true(testo.contains(str(gd.call("tr_data", "ending.apoteosi.name"))), "il nome del finale")
	assert_true(testo.contains(str(gd.call("tr_data", "titoli.scelta.vesna_resta"))), "la scelta fatta")
	assert_false(testo.contains(str(gd.call("tr_data", "titoli.scelta.vesna_se_ne_va"))), "non quella non fatta")
	assert_true(testo.contains(str(gd.call("tr_data", "anchor.mirco"))), "l'Ancora rimasta")
	assert_true(testo.contains("Godot Engine"), "i crediti dai dati")
	assert_true(testo.contains("Kenney"), "e gli autori dei suoni da audio_fonti.json")
	var finiti: Array = []
	t.connect("finiti", func() -> void: finiti.append(true))
	t.call("finisci")
	t.call("finisci")                                # una volta sola
	await Engine.get_main_loop().create_timer(1.0).timeout
	assert_eq(finiti.size(), 1, "saltati, finiscono una volta")
	ks.call("dimentica_tutto")
	_root().get_node("AnchorSystem").call("pulisci")
