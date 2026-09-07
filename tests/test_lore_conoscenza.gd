extends "res://tests/test_case.gd"
## US-621 — la conoscenza dai libri e dai dialoghi: un libro trovato scrive un
## flag testi_* che apre l'Archivio Sepolto; Ottavia insegna una sinergia
## scoperta:"lore" che entra in SynergyEngine._viste.

const AreaGate := preload("res://scripts/area_gate.gd")


func _root() -> Node: return Engine.get_main_loop().root
func _inv() -> Node: return _root().get_node("Inventory")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _se() -> Node: return _root().get_node("SynergyEngine")
func _pr() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_inv().call("pulisci")
	_ks().call("dimentica_tutto")
	_de().call("termina")
	_se().call("pulisci")
	_root().get_node("NpcSystem").call("pulisci")
	_pr().call("configura", "twilight_giant", 9)


func test_un_libro_trovato_scrive_il_flag_e_apre_l_archivio() -> void:
	var creati: Array = _inv().call("aggiungi", "libro_ordine_minore")
	assert_eq(creati.size(), 1, "il libro e' nello zaino")
	assert_false(_ks().call("conosce", "testi_ordine_minore"), "prima di leggerlo, niente flag")

	var r: Dictionary = _inv().call("usa", str(creati[0]))
	assert_true(r["ok"], "il libro si legge")
	assert_eq(str((r["risultato"] as Dictionary).get("flag_appreso")), "testi_ordine_minore",
		"leggere il libro scrive il flag")
	assert_eq(_inv().call("conta", "libro_ordine_minore"), 0, "il libro si consuma")

	# e quel flag apre il gate 'conoscenza' dell'Archivio Sepolto (US-611)
	var ag: Area2D = AreaGate.new()
	ag.call("configura", "archivio_sepolto",
		{"tipo": "conoscenza", "valore": "testi_ordine_minore", "area": "ali_interne"})
	_root().add_child(ag)
	assert_true(ag.call("e_aperto"), "l'ala interna dell'Archivio ora e' aperta")
	ag.free()


func test_ottavia_insegna_una_sinergia_lore() -> void:
	var se: Node = _se()
	assert_false("anti_furia_e_calma" in se.call("viste"), "non ancora vista")
	_pr().call("configura", "twilight_giant", 6)   # tier mid: la prima scelta di Ottavia
	_de().call("avvia", "dlg_ottavia", "npc_ottavia")
	_de().call("scegli", 0)   # "vorrei leggere..." -> n2
	_de().call("scegli", 0)   # "grazie" -> flag + impara_sinergia
	assert_true("anti_furia_e_calma" in se.call("viste"),
		"Ottavia ha insegnato la sinergia lore -> entra in _viste")


func test_impara_sinergia_di_una_non_lore_non_ha_effetto() -> void:
	# impara_sinergia direttamente sul motore: un id inesistente e' rifiutato
	var se: Node = _se()
	assert_false(se.call("impara_sinergia", "sinergia_che_non_esiste"), "id ignoto -> false")
