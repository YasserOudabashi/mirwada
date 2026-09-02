extends "res://tests/test_case.gd"
## US-012 / US-013 — motore delle abilita' e le 5 primitive.

const Stats := preload("res://scripts/stats_component.gd")


func _engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AbilityEngine")


## Caster minimo: un Node2D nell'albero con uno StatsComponent figlio.
func _caster() -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	Engine.get_main_loop().root.add_child(c)
	s.call("configure_from_balance", 9)
	return c


func _cleanup(c: Node2D) -> void:
	Engine.get_main_loop().root.remove_child(c)
	c.free()


func test_abilita_sconosciuta_non_crasha() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var r: Dictionary = e.call("execute", "non_esiste_proprio", c)
	assert_false(r["ok"], "esecuzione rifiutata")
	assert_eq(r["reason"], "abilita_sconosciuta", "motivo del rifiuto")
	_cleanup(c)


func test_caster_senza_stats_rifiutato() -> void:
	var e: Node = _engine()
	var nudo := Node2D.new()
	Engine.get_main_loop().root.add_child(nudo)
	var r: Dictionary = e.call("execute", "fool_velo_illusorio", nudo)
	assert_false(r["ok"], "esecuzione rifiutata")
	assert_eq(r["reason"], "caster_senza_stats", "motivo del rifiuto")
	Engine.get_main_loop().root.remove_child(nudo)
	nudo.free()


func test_costo_scalato_dalla_spiritualita() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("clear_cooldowns")
	var s: Node = c.get_node("Stats")
	var prima: float = float(s.get("spiritualita"))

	var r: Dictionary = e.call("execute", "fool_velo_illusorio", c)
	assert_true(r["ok"], "abilita' eseguita")
	# costo_spiritualita = 12 in data/abilities/fool.json
	assert_almost_eq(float(s.get("spiritualita")), prima - 12.0, "spiritualita' scalata del costo")
	_cleanup(c)


func test_spiritualita_insufficiente_non_esegue_nulla() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("clear_cooldowns")
	var s: Node = c.get_node("Stats")
	s.set("spiritualita", 1.0)

	var r: Dictionary = e.call("execute", "fool_velo_illusorio", c)
	assert_false(r["ok"], "esecuzione rifiutata")
	assert_eq(r["reason"], "spiritualita_insufficiente", "motivo del rifiuto")
	# Nulla e' stato scalato: niente abilita' a meta'.
	assert_almost_eq(float(s.get("spiritualita")), 1.0, "spiritualita' intatta")
	assert_eq((r["effects"] as Array).size(), 0, "nessun effetto applicato")
	_cleanup(c)


func test_cooldown_blocca_la_seconda_esecuzione() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("clear_cooldowns")

	var primo: Dictionary = e.call("execute", "fool_velo_illusorio", c)
	assert_true(primo["ok"], "prima esecuzione riuscita")
	assert_true(e.call("is_on_cooldown", c, "fool_velo_illusorio"), "cooldown avviato")

	var secondo: Dictionary = e.call("execute", "fool_velo_illusorio", c)
	assert_false(secondo["ok"], "seconda esecuzione bloccata")
	assert_eq(secondo["reason"], "in_cooldown", "motivo del rifiuto")
	# cooldown = 6.0 nel JSON
	assert_gt(float(e.call("cooldown_left", c, "fool_velo_illusorio")), 5.0, "cooldown residuo")
	_cleanup(c)


func test_composizione_di_due_primitive() -> void:
	# Il criterio di US-013: fool_velo_illusorio compone illusion + buff_stat.
	# illusion e' nel registro chiuso ma non ancora implementata: deve produrre
	# un AVVISO e lasciare proseguire, non far fallire l'abilita'.
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("clear_cooldowns")
	var s: Node = c.get_node("Stats")

	var r: Dictionary = e.call("execute", "fool_velo_illusorio", c)
	assert_true(r["ok"], "abilita' eseguita")

	var warnings: PackedStringArray = r["warnings"]
	assert_eq(warnings.size(), 1, "un solo avviso")
	assert_true(str(warnings[0]).contains("illusion"), "l'avviso riguarda illusion")

	var effects: Array = r["effects"]
	assert_eq(effects.size(), 1, "una primitiva eseguita davvero")
	assert_eq((effects[0] as Dictionary)["tipo"], "buff_stat", "e' il buff_stat")

	# evasione +0.15 dal JSON, applicata come modificatore
	assert_almost_eq(float(s.call("get_stat", "evasione")), 0.15, "evasione buffata")
	assert_true(s.call("has_modifier", "fool_velo_illusorio:evasione"), "modificatore per id")
	_cleanup(c)


func test_primitiva_fuori_registro_e_errore() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	# Distinzione chiave: fuori dal registro chiuso = bug nei dati.
	var vera: Dictionary = Engine.get_main_loop().root.get_node("GameData").call(
		"get_primitive", "primitiva_inventata")
	assert_true(vera.is_empty(), "la primitiva inventata non e' nel registro")
	_cleanup(c)


func test_buff_stat_moltiplicativo() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	# Moltiplicativo: il delta e' calcolato sulla base, cosi' resta additivo
	# e rimovibile per id come tutti gli altri.
	e.call("_p_buff_stat", {"stat": "hp_max", "valore": 0.5, "moltiplicativo": true},
		c, s, "test_ab")
	assert_almost_eq(float(s.call("get_stat", "hp_max")), 150.0, "hp_max +50% della base")
	assert_true(s.call("remove_modifier", "test_ab:hp_max"), "rimovibile per id")
	assert_almost_eq(float(s.call("get_stat", "hp_max")), 100.0, "tornato alla base")
	_cleanup(c)


func test_heal_istantaneo() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("hp", 40.0)
	e.call("_p_heal", {"quantita": 25.0, "istantaneo": true}, c, s, "test_ab")
	assert_almost_eq(float(s.get("hp")), 65.0, "hp curati")
	_cleanup(c)


func test_projectile_generato_coi_parametri_giusti() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	# tag_danno e' una STRINGA dal vocabolario chiuso data/schema/damage_tags.json,
	# come nei dati veri: il tipo Array negli script era un bug latente.
	var spec: Dictionary = e.call("_p_projectile",
		{"danno": 12.0, "velocita": 260.0, "gittata": 180.0, "pierce": 2,
		 "tag_danno": "spirito"},
		c, c.get_node("Stats"), "test_ab")

	assert_eq(spec["tipo"], "projectile", "tipo del record")
	assert_almost_eq(float(spec["danno"]), 12.0, "danno risolto")
	assert_almost_eq(float(spec["gittata"]), 180.0, "gittata risolta")
	assert_eq(spec["pierce"], 2, "pierce risolto")
	assert_true(spec["spawned"], "nodo generato nell'albero")

	# Il nodo esiste davvero fra i fratelli del caster.
	var trovato: Node = null
	for n in c.get_parent().get_children():
		if n.get("origine") == "test_ab":
			trovato = n
	assert_true(trovato != null, "proiettile presente nella scena")
	if trovato != null:
		assert_eq(trovato.get("pierce"), 2, "pierce sul nodo")
		# pierce 2 = puo' colpire 3 entita' prima di sparire
		assert_eq(trovato.call("colpi_residui"), 3, "colpi residui con pierce 2")
		trovato.free()
	_cleanup(c)


func test_melee_arc_filtra_per_angolo() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	c.global_position = Vector2.ZERO
	var spec: Dictionary = e.call("_p_melee_arc",
		{"danno": 20.0, "angolo": 90.0, "raggio": 40.0, "stagger": 5.0},
		c, c.get_node("Stats"), "test_ab")
	assert_true(spec["spawned"], "arco generato")

	var arc: Node = null
	for n in c.get_children():
		if n.get("origine") == "test_ab":
			arc = n
	assert_true(arc != null, "arco presente")
	if arc != null:
		# Direzione predefinita: destra, apertura 90 grandi = +-45.
		assert_true(arc.call("dentro_arco", Vector2(30, 0)), "davanti: dentro")
		assert_false(arc.call("dentro_arco", Vector2(-30, 0)), "dietro: fuori")
		assert_false(arc.call("dentro_arco", Vector2(200, 0)), "oltre il raggio: fuori")
		assert_true(arc.call("dentro_arco", Vector2(20, 15)), "in diagonale stretta: dentro")
	_cleanup(c)


func test_dash_consegna_l_ordine_al_caster() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	# Un caster che non sa fare dash non deve far fallire nulla.
	var spec: Dictionary = e.call("_p_dash",
		{"distanza": 96.0, "durata": 0.18, "invulnerabile": true}, c, c.get_node("Stats"), "ab")
	assert_almost_eq(float(spec["distanza"]), 96.0, "distanza risolta")
	assert_true(spec["invulnerabile"], "flag invulnerabile risolto")
	assert_false(spec["applied"], "nessun controller: ordine non applicato, ma nessun crash")
	_cleanup(c)


func test_tutte_e_cinque_le_primitive_sono_registrate() -> void:
	var e: Node = _engine()
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	for tipo in ["projectile", "melee_arc", "buff_stat", "heal", "dash"]:
		# Ogni primitiva implementata deve esistere nel registro chiuso.
		assert_false((gd.call("get_primitive", tipo) as Dictionary).is_empty(),
			"'%s' nel registro" % tipo)


func test_buff_scade_dopo_la_durata() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("clear_cooldowns")
	e.call("flush_effects")
	var s: Node = c.get_node("Stats")

	e.call("execute", "fool_velo_illusorio", c)
	assert_almost_eq(float(s.call("get_stat", "evasione")), 0.15, "buff attivo")
	assert_eq(e.call("pending_count"), 1, "una scadenza in coda")

	# durata 8.0: a 7 secondi c'e' ancora, a 8 no. Tempo simulato, non reale.
	e.call("tick_effects", 7.0)
	assert_almost_eq(float(s.call("get_stat", "evasione")), 0.15, "ancora attivo a 7s")
	e.call("tick_effects", 1.5)
	assert_almost_eq(float(s.call("get_stat", "evasione")), 0.0, "scaduto dopo 8s")
	assert_eq(e.call("pending_count"), 0, "coda svuotata")
	_cleanup(c)


func test_heal_nel_tempo() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("flush_effects")
	var s: Node = c.get_node("Stats")
	s.set("hp", 40.0)

	e.call("_p_heal", {"quantita": 30.0, "istantaneo": false, "durata": 3.0},
		c, s, "ab")
	e.call("tick_effects", 1.0)
	assert_almost_eq(float(s.get("hp")), 50.0, "un terzo curato dopo 1s")
	e.call("tick_effects", 2.0)
	# Non deve curare piu' del totale dichiarato, nemmeno con delta grossi.
	assert_almost_eq(float(s.get("hp")), 70.0, "totale curato a fine durata")
	assert_eq(e.call("pending_count"), 0, "effetto concluso")
	_cleanup(c)


func test_effetto_muore_col_bersaglio() -> void:
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("flush_effects")
	var s: Node = c.get_node("Stats")
	e.call("_p_buff_stat", {"stat": "difesa", "valore": 5.0, "durata": 5.0}, c, s, "ab")
	assert_eq(e.call("pending_count"), 1, "scadenza in coda")

	_cleanup(c)  # il caster sparisce mentre il buff e' attivo
	e.call("tick_effects", 1.0)
	# Nessun crash e nessun riferimento appeso a un nodo liberato.
	assert_eq(e.call("pending_count"), 0, "effetto rimosso col bersaglio")


func test_melee_arc_si_libera_dopo_la_vita() -> void:
	# Il bug: l'arco veniva aggiunto come figlio del caster e mai liberato.
	var e: Node = _engine()
	var c: Node2D = _caster()
	e.call("_p_melee_arc", {"danno": 5.0, "angolo": 90.0, "raggio": 40.0},
		c, c.get_node("Stats"), "test_vita")

	var arc: Node = null
	for n in c.get_children():
		if n.get("origine") == "test_vita":
			arc = n
	assert_true(arc != null, "arco presente")
	if arc != null:
		arc.call("_process", 0.1)
		assert_false(arc.is_queued_for_deletion(), "vivo entro la finestra")
		arc.call("_process", 0.2)
		assert_true(arc.is_queued_for_deletion(), "liberato oltre la finestra")
	_cleanup(c)


func test_heal_con_bersaglio_non_self_non_cura_il_caster() -> void:
	# Il bug: il parametro "bersaglio" del registro era ignorato e la cura
	# finiva sempre sul caster, anche quando i dati dicevano "alleato".
	var e: Node = _engine()
	var c: Node2D = _caster()
	var s: Node = c.get_node("Stats")
	s.set("hp", 40.0)

	var spec: Dictionary = e.call("_p_heal",
		{"quantita": 25.0, "istantaneo": true, "bersaglio": "alleato"},
		c, s, "test_ab")
	assert_false(spec["applied"], "bersaglio non risolvibile: cura non applicata")
	assert_almost_eq(float(s.get("hp")), 40.0, "hp del caster intatti")

	# "self" esplicito continua a funzionare come prima.
	e.call("_p_heal", {"quantita": 25.0, "istantaneo": true, "bersaglio": "self"},
		c, s, "test_ab")
	assert_almost_eq(float(s.get("hp")), 65.0, "cura su self applicata")
	_cleanup(c)
