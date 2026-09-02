extends "res://tests/test_case.gd"
## US-003 — hot-reload dei dati.
##
## Il criterio difficile e' "il ricaricamento non invalida i riferimenti gia'
## ottenuti dai sistemi attivi". Si verifica sull'IDENTITA' dell'oggetto, non
## sul contenuto: dopo reload() il Dictionary deve essere lo STESSO, altrimenti
## un sistema che se l'era tenuto continuerebbe a leggere dati morti.

func _data() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func test_reload_conserva_l_identita_dei_riferimenti() -> void:
	var gd: Node = _data()

	var ability_prima: Dictionary = gd.call("get_ability", "fool_velo_illusorio")
	var sequenza_prima: Dictionary = gd.call("get_sequence", "fool_9")
	var pathway_prima: Dictionary = gd.call("get_pathway", "twilight_giant")
	assert_false(ability_prima.is_empty(), "abilita' presente prima del reload")

	gd.call("reload")

	var ability_dopo: Dictionary = gd.call("get_ability", "fool_velo_illusorio")
	var sequenza_dopo: Dictionary = gd.call("get_sequence", "fool_9")
	var pathway_dopo: Dictionary = gd.call("get_pathway", "twilight_giant")

	assert_true(is_same(ability_prima, ability_dopo), "l'abilita' e' lo stesso oggetto")
	assert_true(is_same(sequenza_prima, sequenza_dopo), "la sequenza e' lo stesso oggetto")
	assert_true(is_same(pathway_prima, pathway_dopo), "il pathway e' lo stesso oggetto")

	# E il riferimento vecchio non e' rimasto svuotato dal clear() interno.
	assert_false(ability_prima.is_empty(), "il riferimento vecchio ha ancora i dati")
	assert_eq(ability_prima.get("sequence_id", ""), "fool_9", "e i dati sono quelli giusti")


func test_reload_non_duplica_nulla() -> void:
	var gd: Node = _data()
	var pathway_prima: int = gd.call("pathway_ids").size()
	var sequenze_prima: int = gd.call("sequence_count")
	var abilita_prima: int = gd.call("ability_count")

	gd.call("reload")
	gd.call("reload")

	# Due reload di fila devono lasciare i conteggi identici: se l'indice
	# crescesse, _upsert starebbe inserendo invece di aggiornare.
	assert_eq(gd.call("pathway_ids").size(), pathway_prima, "pathway dopo 2 reload")
	assert_eq(gd.call("sequence_count"), sequenze_prima, "sequenze dopo 2 reload")
	assert_eq(gd.call("ability_count"), abilita_prima, "abilita' dopo 2 reload")


func test_reload_riporta_conteggi_e_errori() -> void:
	var gd: Node = _data()
	gd.call("reload")
	assert_eq(gd.call("files_loaded"), 24, "file ricaricati riportati")
	assert_eq((gd.call("last_errors") as PackedStringArray).size(), 0, "errori riportati")


func test_dati_ancora_integri_dopo_reload() -> void:
	var gd: Node = _data()
	gd.call("reload")
	assert_eq(gd.call("pathway_ids").size(), 10, "10 pathway dopo il reload")
	assert_eq(gd.call("sequence_count"), 100, "100 sequenze dopo il reload")
	assert_true(gd.call("has_tag", "spirito"), "vocabolario dei tag dopo il reload")
	assert_false((gd.call("get_primitive", "projectile") as Dictionary).is_empty(),
		"registro delle primitive dopo il reload")
