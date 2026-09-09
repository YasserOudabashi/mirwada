extends "res://tests/test_case.gd"
## US-716 — data/endings.json: i 3 finali + 4 epiloghi per gruppo. Il motore
## che valuta e sceglie e' US-717 (EndingSystem).

const EREDITA_PROFILI := ["completo", "ancore", "solo_conoscenza"]
const GRUPPI := ["eternal_darkness", "goddess_of_origin", "demon_of_knowledge", "lord_of_mysteries"]
## US-716: posto dal CODICE (EndingSystem ascolta RitualSystem), non da un
## dialogo/quest come gli altri flag di condizione.
const FLAG_ESENTI := ["rituale_sequenza_0_completato"]


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func test_esattamente_i_3_finali() -> void:
	var gd: Node = _gd()
	var ids: Array = []
	for e in gd.call("get_endings"):
		ids.append(str((e as Dictionary).get("id", "")))
	ids.sort()
	assert_eq(ids, ["apoteosi", "consumazione", "rinuncia"], "i 3 finali esatti (FR-9)")


func test_consumazione_ha_la_priorita_piu_alta() -> void:
	# FR-10: e' il game over per follia, deve vincere su qualunque altro
	# finale soddisfatto nello stesso istante.
	var gd: Node = _gd()
	var p_consumazione: float = float(gd.call("get_ending", "consumazione").get("priorita", -1))
	for id in ["apoteosi", "rinuncia"]:
		var p: float = float(gd.call("get_ending", id).get("priorita", -1))
		assert_gt(p_consumazione, p, "consumazione (%s) > %s (%s)" % [p_consumazione, id, p])


func test_ogni_finale_risolve_i_suoi_riferimenti() -> void:
	var gd: Node = _gd()
	for e in gd.call("get_endings"):
		var eid: String = str((e as Dictionary).get("id", ""))
		var ed: Dictionary = e
		assert_true(str(ed.get("name_i18n", "")).begins_with("ending."), "%s: name_i18n" % eid)
		assert_true(gd.call("has_translation", str(ed.get("name_i18n"))), "%s: nome tradotto" % eid)
		assert_true(EREDITA_PROFILI.has(str(ed.get("eredita_profilo"))),
			"%s: eredita_profilo nell'enum" % eid)
		assert_gt(float((ed.get("condizioni", []) as Array).size()), 0.0, "%s: almeno una condizione" % eid)
		for c in (ed.get("condizioni", []) as Array):
			assert_false(str((c as Dictionary).get("tipo", "")).is_empty(), "%s: condizione con un tipo" % eid)
		var epg: Dictionary = ed.get("epiloghi_per_gruppo", {})
		for g in GRUPPI:
			var chiave: String = "%s_i18n" % g
			assert_true(epg.has(chiave), "%s: epilogo per il gruppo '%s'" % [eid, g])
			assert_true(gd.call("has_translation", str(epg[chiave])), "%s: epilogo '%s' tradotto" % [eid, g])


func test_condizioni_flag_non_esenti_poste_da_un_dialogo() -> void:
	var gd: Node = _gd()
	var flag_scritti: Dictionary = {}
	for did in ["dlg_doran", "dlg_antagonista"]:
		var dlg: Dictionary = gd.call("get_dialogue", did)
		for nodo in (dlg.get("nodes", {}) as Dictionary).values():
			for ch in ((nodo as Dictionary).get("choices", []) as Array):
				for eff in ((ch as Dictionary).get("effetti", []) as Array):
					if str((eff as Dictionary).get("tipo", "")) == "flag":
						flag_scritti[str((eff as Dictionary).get("id", ""))] = true
	for e in gd.call("get_endings"):
		var eid: String = str((e as Dictionary).get("id", ""))
		for c in ((e as Dictionary).get("condizioni", []) as Array):
			if str((c as Dictionary).get("tipo", "")) != "flag":
				continue
			var flag: String = str((c as Dictionary).get("valore", ""))
			if FLAG_ESENTI.has(flag):
				continue
			assert_true(flag_scritti.has(flag), "%s: il flag '%s' e' posto da un dialogo" % [eid, flag])
