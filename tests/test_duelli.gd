extends "res://tests/test_case.gd"
## US-1304 — Il duello con Aldo come scena: accettato nel dialogo, Aldo lascia il posto a un nemico con la sua
## Sequenza; vinto o perso, torna e parte il dialogo giusto, che scrive il suo flag.

const Mondo := preload("res://scripts/world/mondo.gd")

func _root() -> Node: return Engine.get_main_loop().root
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _ts() -> Node: return _root().get_node("TimeSystem")

var _mondo: Node2D = null
var _player: Node2D = null


func prepara() -> void:
	_ks().call("dimentica_tutto")
	_root().get_node("NpcSystem").call("pulisci")
	_de().call("termina")
	_ts().call("forza_momento", "mezzogiorno")      # Aldo e' in piazza
	_mondo = Mondo.new()
	_player = preload("res://scenes/player.tscn").instantiate()
	_mondo.add_child(_player)
	_root().add_child(_mondo)


func _chiudi() -> void:
	_de().call("termina")
	_mondo.free()
	_ts().call("libera_momento")
	_ks().call("dimentica_tutto")


func _scegli(chiave: String) -> bool:
	var valide: Array = _de().call("scelte_valide")
	for i in valide.size():
		if str(valide[i]["text_i18n"]) == chiave:
			return bool(_de().call("scegli", i))
	return false


## Accetta il duello parlando con Aldo; torna il nemico che lo sostituisce.
func _accetta() -> Node:
	_ks().call("imposta", "aldo_duello_disponibile", true)
	_de().call("avvia", "dlg_aldo", "npc_aldo")
	_scegli("dialogue.aldo.n1.sfida")
	_scegli("dialogue.aldo.n2.inizia")
	for e in _mondo.get_children():
		if e.has_meta("duello"):
			return e
	return null


func test_accettare_fa_cominciare_lo_scontro() -> void:
	var aldo: Node2D = _mondo.get_node_or_null("Npc_npc_aldo")
	assert_true(aldo != null, "a mezzogiorno Aldo e' sulla mappa")
	var e: Node = _accetta()
	assert_true(e != null, "al posto di Aldo c'e' un nemico")
	if e != null:
		assert_eq((e as Node2D).position, aldo.position, "nello stesso punto")
		assert_eq(int(e.get("sequenza")), int(_root().get_node("NpcSystem").call("sequenza_npc", "npc_aldo")), "con la Sequenza di Aldo")
		assert_eq(str(e.call("nome")), str(_root().get_node("GameData").call("tr_data", "npc.aldo.name")), "e il suo nome")
	assert_false(aldo.visible, "Aldo che parla non c'e' piu' finche' si combatte")
	assert_false(_ks().call("conosce", "aldo_duello_disponibile"), "l'offerta e' spesa fino al prossimo salto di tier")
	assert_true(_mondo.get_node("Duelli").call("in_corso", "npc_aldo"), "il duello e' in corso")
	_chiudi()


func test_vinto() -> void:
	var e: Node = _accetta()
	e.emit_signal("morto", e)
	assert_true((_mondo.get_node("Npc_npc_aldo") as Node2D).visible, "battuto, Aldo torna")
	assert_false(_mondo.get_node("Duelli").call("in_corso", "npc_aldo"), "il duello e' finito")
	_mondo.get_node("Duelli").call("parla_dopo", "npc_aldo", true)      # nel gioco dopo la pausa dei dati
	assert_eq(str(_de().call("dialogue_id")), "dlg_aldo_vinto", "parte il dialogo della vittoria")
	_scegli("dialogue.aldo_vinto.n1.rispetto")
	assert_true(_ks().call("conosce", "aldo_duello_vinto"), "che scrive la vittoria")
	_chiudi()


func test_perso() -> void:
	var e: Node = _accetta()
	_player.get_node("StatsComponent").emit_signal("died")
	assert_false(is_instance_valid(e) and not e.is_queued_for_deletion(), "caduto il giocatore, l'avversario se ne va")
	assert_true((_mondo.get_node("Npc_npc_aldo") as Node2D).visible, "e Aldo torna")
	_mondo.get_node("Duelli").call("parla_dopo", "npc_aldo", false)
	assert_eq(str(_de().call("dialogue_id")), "dlg_aldo_perso", "parte il dialogo della sconfitta")
	_scegli("dialogue.aldo_perso.n1.ancora")
	assert_true(_ks().call("conosce", "aldo_duello_perso"), "che scrive la sconfitta")
	assert_false(_ks().call("conosce", "aldo_duello_vinto"), "e non la vittoria")
	_chiudi()
