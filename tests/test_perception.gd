extends "res://tests/test_case.gd"
## US-218 — Percezione per Sequenza: layer audio + reveal, cumulativi, dai dati.

func _ps() -> Node: return Engine.get_main_loop().root.get_node_or_null("PerceptionSystem")
func _prog() -> Node: return Engine.get_main_loop().root.get_node_or_null("Progression")
func _am() -> Node: return Engine.get_main_loop().root.get_node_or_null("AudioManager")


func _a_sequenza(n: int) -> void:
	_prog().configura("", n)
	_ps().call("aggiorna")


func test_sequenza_9_niente_percezione() -> void:
	_a_sequenza(9)
	assert_true((_ps().call("layers_attivi") as Array).is_empty(), "nessun layer a Seq 9")
	assert_true((_ps().call("reveal_attivi") as Array).is_empty(), "nessun reveal a Seq 9")


func test_sequenza_7_primo_reveal() -> void:
	_a_sequenza(7)
	assert_true(_ps().call("reveal_attivo", "spiriti_vicini"), "spiriti_vicini a Seq 7")
	assert_true("amb_spirit_faint" in (_ps().call("layers_attivi") as Array), "layer ambientale a Seq 7")


func test_sequenza_intermedia_usa_la_voce_verso_l_alto() -> void:
	_a_sequenza(6)   # non c'e' la voce "6": si usa quella di "7"
	assert_eq((_ps().call("reveal_attivi") as Array), ["spiriti_vicini"], "Seq 6 -> percezione di Seq 7")
	_a_sequenza(4)   # si usa "5"
	assert_true(_ps().call("reveal_attivo", "densita_mistica"), "Seq 4 -> percezione di Seq 5")


func test_la_percezione_e_cumulativa() -> void:
	_a_sequenza(7)
	var a: int = (_ps().call("reveal_attivi") as Array).size()
	_a_sequenza(5)
	var b: int = (_ps().call("reveal_attivi") as Array).size()
	_a_sequenza(3)
	var c: int = (_ps().call("reveal_attivi") as Array).size()
	assert_true(a < b and b < c, "scendendo di Sequenza i reveal aumentano (%d < %d < %d)" % [a, b, c])
	# e sono un superset
	for r in (_ps().call("reveal_attivi") as Array):
		pass
	_a_sequenza(5)
	for r in (_ps().call("reveal_attivi") as Array):
		assert_true(r in ["spiriti_vicini", "densita_mistica"], "Seq 5 contiene i reveal di Seq 7")


func test_i_layer_audio_si_accendono() -> void:
	var am: Node = _am()
	_a_sequenza(3)
	var attivi: Array = am.call("layers_ambientali_attivi")
	assert_true("amb_outer_drone" in attivi, "il layer di Seq 3 suona")
	_a_sequenza(9)
	assert_false("amb_outer_drone" in (am.call("layers_ambientali_attivi") as Array),
		"tornando a Seq 9 i layer si spengono")
