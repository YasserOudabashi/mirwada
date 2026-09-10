extends "res://tests/test_case.gd"
## US-904 — Eternal Aeon, Sequenze 9-5 (primo Pathway Non-Standard vero:
## nomi, abilita', requisiti del Boon). Stesso schema dei test per-Pathway
## gia' in uso (es. test_mother.gd): le abilita' eseguono senza warning, i
## dati della Sequenza sono coerenti. Le Sequenze 4-0 restano stub fino a
## US-905.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_5 := [
	"ea_eco_del_colpo", "ea_respiro_immutabile", "ea_pagina_ritrovata",
	"ea_richiamo_del_momento_perduto", "ea_sguardo_che_non_dimentica",
]

## Sequenza -> numero atteso di requisiti nel boon (dalla progettazione:
## 9 e 6 hanno un solo tipo, 8 e 7 due tipi, 5 tutti e tre insieme).
const REQUISITI_ATTESI := {9: 1, 8: 2, 7: 2, 6: 1, 5: 3}


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("flush_effects")


func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 7)
	return c


func _cleanup(c: Node) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_ogni_abilita_9_5_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_5:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva: %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_pathway_risolve_dieci_sequenze() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	assert_false(pw.is_empty(), "eternal_aeon si carica")
	assert_eq(str(pw.get("categoria")), "non_standard", "categoria non_standard")
	assert_eq(pw.get("group"), null, "nessun gruppo")
	assert_eq((pw.get("sequences", []) as Array).size(), 10, "10 Sequenze")


func test_sequenze_9_5_non_sono_stub_e_hanno_un_boon_coerente() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		if n < 5:
			continue
		assert_false(bool(d.get("stub", false)), "eternal_aeon_%d non e' stub" % n)
		assert_false(str(d.get("name", "")).is_empty(), "eternal_aeon_%d ha un nome" % n)
		var boon: Dictionary = d.get("boon", {})
		assert_false(boon.is_empty(), "eternal_aeon_%d ha un boon" % n)
		var requisiti: Array = boon.get("requisiti", [])
		assert_eq(requisiti.size(), int(REQUISITI_ATTESI[n]),
			"eternal_aeon_%d: %d requisiti attesi" % [n, REQUISITI_ATTESI[n]])


func test_sequenza_5_usa_tutti_e_tre_i_tipi_di_requisito() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		if int(d.get("sequence")) != 5:
			continue
		var tipi: Array = []
		for req in (d.get("boon", {}).get("requisiti", []) as Array):
			tipi.append(str((req as Dictionary).get("tipo")))
		tipi.sort()
		assert_eq(tipi, ["comportamento", "quest", "sacrificio"],
			"Sequenza 5: quest + comportamento + sacrificio insieme")


func test_sequenze_9_e_6_usano_un_solo_tipo_di_requisito() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		if n != 9 and n != 6:
			continue
		var requisiti: Array = d.get("boon", {}).get("requisiti", [])
		assert_eq(requisiti.size(), 1, "Sequenza %d: un solo requisito" % n)


func test_sequenze_4_0_sono_stub() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		if n > 4:
			continue
		assert_true(bool(d.get("stub", false)), "eternal_aeon_%d e' stub (US-905 la scrive)" % n)
		assert_false(str(d.get("name", "")).is_empty(), "eternal_aeon_%d ha comunque un nome definitivo" % n)
		assert_true(d.get("boon") == null, "eternal_aeon_%d non ha ancora un boon" % n)


func test_gli_id_referenziati_dal_boon_esistono_davvero() -> void:
	var gd: Node = _gd()
	assert_false((gd.call("get_quest", "q_sidon_01") as Dictionary).is_empty(), "q_sidon_01 esiste")
	assert_false((gd.call("get_quest", "q_vesna_01") as Dictionary).is_empty(), "q_vesna_01 esiste")
	assert_false((gd.call("get_item", "clessidra_che_cola_all_indietro") as Dictionary).is_empty(),
		"clessidra_che_cola_all_indietro esiste")
	assert_false((gd.call("get_item", "memoria_cristallizzata") as Dictionary).is_empty(),
		"memoria_cristallizzata esiste")
