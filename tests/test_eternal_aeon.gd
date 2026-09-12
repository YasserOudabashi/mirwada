extends "res://tests/test_case.gd"
## US-904/US-905 — Eternal Aeon, primo Pathway Non-Standard vero, completo
## 10/10 Sequenze: nomi, abilita', requisiti del Boon. Stesso schema dei
## test per-Pathway gia' in uso (es. test_mother.gd): le abilita' eseguono
## senza warning, i dati della Sequenza sono coerenti.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA := [
	"ea_eco_del_colpo", "ea_respiro_immutabile", "ea_pagina_ritrovata",
	"ea_richiamo_del_momento_perduto", "ea_sguardo_che_non_dimentica",
	"ea_verso_che_lega", "ea_voce_che_non_dovrebbe_esistere",
	"ea_messaggio_senza_distanza", "ea_distacco_dal_presente",
	"ea_ritorno_che_non_dovrebbe_essere",
]

## Sequenza -> numero atteso di requisiti nel boon (dalla progettazione:
## 9, 6 e 2 hanno un solo tipo, 8, 7, 3, 1 e 0 ne hanno due, 5 tutti e tre
## insieme).
const REQUISITI_ATTESI := {9: 1, 8: 2, 7: 2, 6: 1, 5: 3, 4: 1, 3: 2, 2: 1, 1: 2, 0: 2}


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


func test_ogni_abilita_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA:
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


func test_nessuna_sequenza_e_ancora_stub() -> void:
	# US-905 ha scritto anche le Sequenze 4-0: il Pathway e' 10/10 completo.
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		assert_false(bool(d.get("stub", false)), "eternal_aeon_%d non e' stub" % n)
		assert_false(str(d.get("name", "")).is_empty(), "eternal_aeon_%d ha un nome" % n)
		assert_false((d.get("abilities", []) as Array).is_empty(), "eternal_aeon_%d ha un'abilita'" % n)
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


func test_le_10_sequenze_coprono_tutti_e_tre_i_tipi_di_requisito() -> void:
	# AC di US-905: le 10 Sequenze insieme coprono quest/comportamento/
	# sacrificio almeno una volta ciascuna (gia' soddisfatto da solo dalla
	# Sequenza 5, questo test lo conferma sull'insieme come chiede l'AC).
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	var tipi_visti: Dictionary = {}
	for seq in (pw.get("sequences", []) as Array):
		for req in ((seq as Dictionary).get("boon", {}).get("requisiti", []) as Array):
			tipi_visti[str((req as Dictionary).get("tipo"))] = true
	for tipo in ["quest", "comportamento", "sacrificio"]:
		assert_true(bool(tipi_visti.get(tipo, false)), "'%s' compare in almeno una Sequenza" % tipo)


func test_sequenze_9_6_e_2_usano_un_solo_tipo_di_requisito() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		if n != 9 and n != 6 and n != 2:
			continue
		var requisiti: Array = d.get("boon", {}).get("requisiti", [])
		assert_eq(requisiti.size(), 1, "Sequenza %d: un solo requisito" % n)


func test_gli_id_referenziati_dal_boon_esistono_davvero() -> void:
	var gd: Node = _gd()
	for qid in ["q_sidon_01", "q_vesna_01", "q_mirco_01", "q_lena_01"]:
		assert_false((gd.call("get_quest", qid) as Dictionary).is_empty(), "%s esiste" % qid)
	for iid in ["clessidra_che_cola_all_indietro", "memoria_cristallizzata", "tempo_solidificato"]:
		assert_false((gd.call("get_item", iid) as Dictionary).is_empty(), "%s esiste" % iid)


func test_ogni_requisito_comportamento_ability_id_referenzia_un_abilita_reale() -> void:
	var gd: Node = _gd()
	var pw: Dictionary = gd.call("get_pathway", "eternal_aeon")
	for seq in (pw.get("sequences", []) as Array):
		for req in ((seq as Dictionary).get("boon", {}).get("requisiti", []) as Array):
			var r: Dictionary = req
			if str(r.get("tipo")) != "comportamento":
				continue
			var aid: String = str((r.get("filtri", {}) as Dictionary).get("ability_id", ""))
			if aid.is_empty():
				continue
			assert_false((gd.call("get_ability", aid) as Dictionary).is_empty(),
				"ability_id '%s' referenziato da un requisito esiste davvero" % aid)
