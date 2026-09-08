extends "res://tests/test_case.gd"
## US-5B08 — Door, Sequenze 9-7 (Apprentice / Trickmaster / Astrologer): ogni
## abilita' si esegue senza warning di primitiva; shadow_meld (gia'
## implementata in fase 6) applica lo status 'occultato'; reveal_info del Door
## porta la categoria "percorso" (matrice: Door divina lo spazio); le acting
## sommano 1.0.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"door_passo_breve", "door_grimaldello_mistico",
	"door_via_di_fuga", "door_scambio_di_posto",
	"door_lettura_stellare", "door_occhio_nell_ombra",
]
const ABILITA_6_4 := [
	"door_registra_abilita", "door_riproduci_copia",
	"door_scorciatoia", "door_porta_di_gruppo",
	"door_occultamento_totale", "door_segreto_svanito",
]


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func prepara() -> void:
	var e: Node = _engine()
	if e != null:
		e.call("clear_cooldowns")
		e.call("clear_granted")
		e.call("clear_snapshots")
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


func test_ogni_abilita_door_9_7_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (teleport/shadow_meld/reveal_info): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_shadow_meld_applica_occultato() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	e.call("execute", "door_occhio_nell_ombra", c)
	assert_true(s.call("ha_status", "occultato"),
		"shadow_meld applica lo status 'occultato' (sfugge al rilevamento)")
	_cleanup(c)


func test_reveal_info_del_door_e_sullo_spazio() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var visti: Array = []
	var cb := func(categoria: String, _r: float, _o: Vector2) -> void: visti.append(categoria)
	e.connect("info_rivelata", cb)
	e.call("execute", "door_lettura_stellare", c)
	e.disconnect("info_rivelata", cb)
	assert_true(visti.has("percorso"),
		"il Door divina lo SPAZIO: reveal_info categoria 'percorso' (matrice di proprieta')")
	_cleanup(c)


func test_ogni_abilita_door_6_4_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_6_4:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva: %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		e.call("clear_granted")
		_cleanup(c)


func test_scribe_fotocopia_senza_marcare_sottratto() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "door_registra_abilita", c)
	var rec: Dictionary = (r["effects"] as Array)[0]
	assert_true(e.call("is_granted", c, "tg_stretta_ferrea"),
		"la fotocopia concede l'abilita' al caster (grant_temporary, come lo steal)")
	assert_false(bool(rec["sottratto"]),
		"MA con non_sottrae:true il nemico NON e' marcato derubato (distinzione dall'Error)")
	e.call("clear_granted")
	_cleanup(c)


func test_traveler_e_teleport_coi_parametri_del_door() -> void:
	# Nessun 'if' per il Door: il fast travel e' teleport con distanza grande +
	# porta_alleati:true, come da dati.
	var ab: Dictionary = _gd().call("get_ability", "door_scorciatoia")
	var p: Dictionary = (ab.get("primitive", []) as Array)[0]
	assert_eq(str(p["tipo"]), "teleport", "e' teleport, non una primitiva nuova")
	assert_true(bool(p["porta_alleati"]), "porta gli alleati (il Traveler viaggia in gruppo)")
	assert_gt(float(p["distanza"]), 300.0, "distanza grande (scorciatoia tra zone lontane)")


func test_door_9_4_sono_contenuto_e_le_acting_sommano_uno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "door")
	var madness_prec: float = -1.0
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		if int(d.get("sequence", -1)) < 4:
			continue
		assert_false(bool(d.get("stub", false)),
			"door_%d non e' piu' stub" % int(d.get("sequence")))
		var somma: float = 0.0
		for a in (d.get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0,
			"door_%d: le acting_actions sommano 1.0" % int(d.get("sequence")))
		var mf: float = float(d.get("madness_on_force", 0.0))
		assert_gt(mf, madness_prec, "door_%d: madness_on_force cresce" % int(d.get("sequence")))
		madness_prec = mf
