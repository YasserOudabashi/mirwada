extends "res://tests/test_case.gd"
## US-606 — Darkness, Sequenze 9-7 (Sleepless / Midnight Poet / Nightmare).
## BLOCCO C: chiude la fase 5b per il gruppo eternal_darkness. Nessuna
## primitiva nuova (fear/debuff/dot/light_purify/buff gia' esistono).

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_9_7 := [
	"darkness_forza_del_buio", "darkness_veglia_perpetua",
	"darkness_verso_cupo", "darkness_poesia_amara",
	"darkness_incubo", "darkness_terrore_notturno",
]
const ABILITA_6_4 := [
	"darkness_quiete_dell_anima", "darkness_requiem",
	"darkness_ospite_maligno", "darkness_scaglia_spirito",
	"darkness_manto_d_ombra", "darkness_notte_artificiale",
]
const ABILITA_3_0 := [
	"darkness_aura_di_terrore", "darkness_predica_nera",
	"darkness_cancellazione", "darkness_svanire",
	"darkness_sfortuna_cronica", "darkness_giogo_della_malasorte",
	"darkness_dominio_della_notte",
]


func _root() -> Node: return Engine.get_main_loop().root
func _e() -> Node: return _root().get_node("AbilityEngine")
func _gd() -> Node: return _root().get_node("GameData")


func prepara() -> void:
	_e().call("clear_cooldowns")
	_e().call("flush_effects")


func _caster() -> Node2D:
	# Node2D NUDO (non nel gruppo "player"): le condizioni e_notte sono ignorate
	# (US-605), il test isola l'esecuzione delle primitive.
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	_root().add_child(c)
	s.call("configure_from_balance", 7)
	s.set("spiritualita", 9999.0)
	return c


func _cleanup(c: Node) -> void:
	_root().remove_child(c)
	c.free()


func test_ogni_abilita_darkness_9_7_si_esegue_senza_warning() -> void:
	for aid in ABILITA_9_7:
		var c: Node2D = _caster()
		var r: Dictionary = _e().call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita: %s" % [aid, r.get("reason")])
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva: %s" % [aid, r["warnings"]])
		_e().call("clear_cooldowns")
		_cleanup(c)


func test_incubo_applica_paura_e_abbassa_la_precisione() -> void:
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var prec0: float = s.call("get_stat", "precisione")
	var r: Dictionary = _e().call("execute", "darkness_incubo", c)
	assert_true(r["ok"], "incubo eseguito")
	assert_true(s.call("ha_status", "paura"), "fear applica lo status 'paura'")
	assert_gt(prec0, s.call("get_stat", "precisione"), "l'incubo disorienta la mira (precisione scesa)")
	_cleanup(c)


func test_forza_del_buio_ha_la_condizione_e_notte() -> void:
	var ab: Dictionary = _gd().call("get_ability", "darkness_forza_del_buio")
	var cond: Array = ab.get("condizioni", [])
	assert_eq(cond.size(), 1, "una condizione dichiarata")
	assert_eq(str((cond[0] as Dictionary).get("tipo")), "e_notte", "e' e_notte (Sleepless al buio)")


func test_ogni_abilita_darkness_6_4_si_esegue_senza_warning() -> void:
	for aid in ABILITA_6_4:
		var c: Node2D = _caster()
		var r: Dictionary = _e().call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita: %s" % [aid, r.get("reason")])
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning (shadow_meld ora implementata): %s" % [aid, r["warnings"]])
		_e().call("clear_cooldowns")
		_cleanup(c)


func test_shadow_meld_applica_occultato() -> void:
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	var r: Dictionary = _e().call("execute", "darkness_manto_d_ombra", c)
	assert_true(r["ok"], "manto d'ombra eseguito")
	assert_true(s.call("ha_status", "occultato"), "shadow_meld applica lo status 'occultato'")
	assert_false(bool(_gd().call("get_status_effect", "occultato").get("negativo", true)),
		"'occultato' non e' negativo (e' un vantaggio)")
	_cleanup(c)


func test_notte_artificiale_accende_e_notte_localmente() -> void:
	var ts: Node = _root().get_node("TimeSystem")
	ts.call("da_salvataggio", {})  # giorno
	assert_false(ts.call("e_notte"), "di giorno non e' notte")
	var c: Node2D = _caster()
	(c as Node2D).global_position = Vector2(500, 500)
	_e().call("execute", "darkness_notte_artificiale", c)
	assert_true(ts.call("e_notte", Vector2(520, 510)),
		"dentro l'oscurita' creata, e_notte(posizione) e' vero anche di giorno")
	assert_false(ts.call("e_notte", Vector2(2000, 2000)), "fuori dall'oscurita' resta giorno")
	_cleanup(c)


func test_darkness_4_ha_il_rituale_notturno() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "darkness")
	for s in (pw.get("sequences", []) as Array):
		if int((s as Dictionary).get("sequence")) != 4:
			continue
		var rit: Dictionary = (s as Dictionary).get("advancement_ritual", {})
		assert_false(rit.is_empty(), "darkness_4 ha un advancement_ritual")
		assert_eq(str(rit.get("momento")), "notte_fonda", "il rituale del Nightwatcher e' a notte fonda")
		assert_gt((rit.get("location_tags", []) as Array).size(), 0.0, "coi suoi luoghi")


func test_ogni_abilita_darkness_3_0_si_esegue_senza_warning() -> void:
	for aid in ABILITA_3_0:
		var c: Node2D = _caster()
		var r: Dictionary = _e().call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita: %s" % [aid, r.get("reason")])
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning (illusion ora implementata): %s" % [aid, r["warnings"]])
		_e().call("clear_cooldowns")
		_cleanup(c)


func test_illusion_emette_il_segnale_e_il_danno_percepito_e_un_dot() -> void:
	var c: Node2D = _caster()
	var visto: Array = []
	var cb := func(tipo: String, _r: float, _o: Vector2) -> void: visto.append(tipo)
	_e().connect("illusione_creata", cb)
	var r: Dictionary = _e().call("execute", "darkness_svanire", c)
	_e().disconnect("illusione_creata", cb)
	assert_true(r["ok"], "svanire eseguito")
	assert_true(visto.has("cancellazione_percettiva"),
		"illusion emette illusione_creata col tipo dichiarato")
	# danno_percepito -> un dot: lo verifico sulla primitiva isolata
	var c2: Node2D = _caster()
	var s2: Node = c2.get_node("Stats")
	var hp0: float = float(s2.get("hp"))
	_e().call("_p_illusion", {"raggio":4,"durata":6.0,"potenza":3,"tipo_illusione":"danno_percepito"}, c2, s2, "ab")
	_e().call("tick_effects", 2.0)
	assert_gt(hp0, float(s2.get("hp")), "danno_percepito e' un dot a tag follia (hp scesi)")
	_cleanup(c)
	_cleanup(c2)


func test_darkness_1_non_e_piu_stub_ma_l_abilita_resta_quella_di_us503() -> void:
	# US-608: darkness_1 (Knight of Misfortune) esce da stub. L'abilita'
	# darkness_sfortuna_cronica resta quella di US-503 (senza probability_shift).
	var pw: Dictionary = _gd().call("get_pathway", "darkness")
	for s in (pw.get("sequences", []) as Array):
		if int((s as Dictionary).get("sequence")) != 1:
			continue
		assert_false(bool((s as Dictionary).get("stub", true)), "darkness_1 non e' piu' stub")
		assert_true((s as Dictionary).get("abilities", []).has("darkness_sfortuna_cronica"),
			"tiene ancora l'abilita' di US-503")
	var ab: Dictionary = _gd().call("get_ability", "darkness_sfortuna_cronica")
	for p in (ab.get("primitive", []) as Array):
		assert_ne(str((p as Dictionary).get("tipo")), "probability_shift",
			"nessuna primitiva differita (probability_shift)")


func test_darkness_completo_ritual_seq0_e_i_luoghi() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "darkness")
	var stub_rimasti: Array = []
	for s in (pw.get("sequences", []) as Array):
		if bool((s as Dictionary).get("stub", false)):
			stub_rimasti.append((s as Dictionary).get("sequence"))
		var n: int = int((s as Dictionary).get("sequence"))
		if n <= 4:
			var rit: Dictionary = (s as Dictionary).get("advancement_ritual", {})
			assert_false(rit.is_empty(), "darkness_%d ha un rituale" % n)
	assert_eq(stub_rimasti.size(), 0, "DARKNESS COMPLETO: 0 Sequenze stub (%s)" % stub_rimasti)


func test_darkness_tutte_e_10_non_piu_stub_acting_1() -> void:
	var pw: Dictionary = _gd().call("get_pathway", "darkness")
	var madness_prec: float = -1.0
	for seq in (pw.get("sequences", []) as Array):
		var d: Dictionary = seq
		var n: int = int(d.get("sequence"))
		if n > 9:
			continue
		assert_false(bool(d.get("stub", false)), "darkness_%d non e' piu' stub" % n)
		var somma: float = 0.0
		for a in (d.get("acting_actions", []) as Array):
			somma += float((a as Dictionary).get("progresso", 0.0))
		assert_almost_eq(somma, 1.0, "darkness_%d: acting sommano 1.0" % n)
		var mf: float = float(d.get("madness_on_force", 0.0))
		assert_gt(mf, madness_prec, "darkness_%d: madness_on_force cresce" % n)
		madness_prec = mf
		assert_false(_gd().call("get_formula", "formula_darkness_%d" % n).is_empty(),
			"formula_darkness_%d esiste" % n)
