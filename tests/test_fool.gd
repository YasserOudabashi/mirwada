extends "res://tests/test_case.gd"
## US-5B05 — Fool, Sequenze 9-7 (Seer / Clown / Magician): ogni abilita' si
## esegue senza warning di primitiva; illusion "danno_percepito" registra un
## dot a tag follia (potenza = intensita') rimovibile da light_purify;
## illusion "copia_nemico" registra il numero di esche; le acting sommano 1.0.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"fool_divinazione_pendolo", "fool_velo_illusorio", "fool_lettura_espressioni",
	"fool_acrobazia", "fool_travestimento_lampo",
	"fool_illusione_solida", "fool_oggetto_dal_nulla",
]
const ABILITA_6_4 := [
	"fool_volto_rubato", "fool_voce_prestata",
	"fool_fili_marionetta", "fool_scambio_bersagli",
	"fool_scambio_con_oggetto", "fool_prestigio_di_stanza",
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


func test_ogni_abilita_fool_9_7_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (illusion implementata): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_illusion_danno_percepito_e_un_dot_follia_rimovibile() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var hp0: float = float(s.get("hp"))
	e.call("execute", "fool_illusione_solida", c)
	assert_gt(float(e.call("pending_count")), 0.0, "il danno percepito e' una entry a tempo")
	e.call("tick_effects", 3.0)
	assert_gt(hp0, float(s.get("hp")), "il danno percepito toglie hp (il bersaglio ci crede)")
	# il bersaglio "capisce": un purify toglie il dot come ogni effetto negativo
	e.call("_p_light_purify", {"potenza": 5}, c, s, "purify")
	var hp_dopo: float = float(s.get("hp"))
	e.call("tick_effects", 3.0)
	assert_almost_eq(float(s.get("hp")), hp_dopo,
		"dopo il purify il danno percepito non fa piu' male", 0.01)
	_cleanup(c)


func test_illusion_copia_nemico_registra_il_numero_di_esche() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var rec: Dictionary = e.call("_p_illusion",
		{"tipo": "illusion", "raggio": 6, "durata": 8.0, "potenza": 3,
		"tipo_illusione": "copia_nemico"}, c, null, "ab")
	assert_eq(int(rec["esche"]), 3,
		"per 'copia_nemico' potenza = numero di esche registrate (le fa comparire il combat, fase 6)")
	_cleanup(c)


func test_illusion_emette_il_segnale_illusione_creata() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var visti: Array = []
	var cb := func(tipo: String, _raggio: float, _origine: Vector2) -> void: visti.append(tipo)
	e.connect("illusione_creata", cb)
	e.call("execute", "fool_oggetto_dal_nulla", c)
	e.disconnect("illusione_creata", cb)
	assert_true(visti.has("oggetto_evocato"),
		"illusion emette illusione_creata col tipo_illusione dai dati")
	_cleanup(c)


func test_ogni_abilita_fool_6_4_si_esegue_senza_warning() -> void:
	var e: Node = _engine()
	for aid in ABILITA_6_4:
		var c: Node2D = _caster()
		var r: Dictionary = e.call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita" % aid)
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva (possess/teleport/illusion): %s" % [aid, r["warnings"]])
		e.call("clear_cooldowns")
		_cleanup(c)


func test_marionettist_possiede_con_controllo_totale() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var r: Dictionary = e.call("execute", "fool_fili_marionetta", c)
	assert_true(r["ok"], "fili della marionetta eseguito")
	assert_true(s.call("ha_status", "posseduto"), "possess applica 'posseduto'")
	var rec: Dictionary = (r["effects"] as Array)[0]
	assert_eq(str(rec["controllo"]), "totale",
		"il Marionettist ha il controllo TOTALE (distinto dal 'sensi' del Parasite Error)")
	_cleanup(c)


func test_fool_4_ha_un_rituale_di_teatro() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "fool")
	for seq in (pw.get("sequences", []) as Array):
		if int((seq as Dictionary).get("sequence", -1)) != 4:
			continue
		var rit: Dictionary = (seq as Dictionary).get("advancement_ritual", {})
		var lt: Array = rit.get("location_tags", [])
		assert_true("teatro" in lt or "palco" in lt,
			"fool_4 (Bizarro Sorcerer) si avanza a teatro / sul palco")


func test_fool_9_4_sono_contenuto_e_le_acting_sommano_uno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "fool")
	var madness_prec: float = -1.0
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		if int(d.get("sequence", -1)) < 4:
			continue
		assert_false(bool(d.get("stub", false)),
			"fool_%d non e' piu' stub" % int(d.get("sequence")))
		var somma: float = 0.0
		for a in (d.get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0,
			"fool_%d: le acting_actions sommano 1.0" % int(d.get("sequence")))
		var mf: float = float(d.get("madness_on_force", 0.0))
		assert_gt(mf, madness_prec,
			"fool_%d: madness_on_force cresce" % int(d.get("sequence")))
		madness_prec = mf
