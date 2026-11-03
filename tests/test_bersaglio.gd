extends "res://tests/test_case.gd"
## US-8B44a — le primitive che colpiscono un altro (data/schema/primitives.json "bersaglio": "nemico") cadono sul nemico
## vivo piu' vicino davanti, entro balance.json combattimento.bersaglio; senza nemico l'abilita' non parte e non costa;
## un costo voluto su di se' ("bersaglio": "self" nell'abilita') resta su chi lancia; sopra la testa "nessun bersaglio".

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")


## Lontano dall'origine: altri test lasciano nemici nell'albero, e il bersaglio e' il piu' vicino.
const QUI := Vector2(70000, 70000)


func _n(s: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(s)


func prepara() -> void:
	_n("/root/AbilityEngine").call("clear_cooldowns")
	_n("/root/AbilityEngine").call("clear_granted")


## Il giocatore in (0, 0) che guarda in giu' (lo sguardo di partenza), con la spiritualita' piena.
func _giocatore(pathway: String, sequenza: int) -> Node2D:
	_n("/root/Progression").call("configura", pathway, sequenza)
	var p: Node2D = PlayerScene.instantiate()
	Engine.get_main_loop().root.add_child(p)
	p.global_position = QUI
	var s: Node = p.get_node("StatsComponent")
	s.set("spiritualita", float(s.call("get_stat", "spiritualita_max")))
	assert_eq(p.call("get_facing"), Vector2.DOWN, "guarda in giu'")
	return p


func _nemico(pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	Engine.get_main_loop().root.add_child(e)
	e.global_position = QUI + pos
	return e


func _status(n: Node) -> Array:
	return n.get_node("StatsComponent").call("status_attivi")


func _raggio() -> float:
	return float(_n("/root/GameData").call("get_balance", "combattimento")["bersaglio"]["raggio"])


func test_anima_recisa_cade_sul_nemico_davanti() -> void:
	var p := _giocatore("death", 3)
	var davanti := _nemico(Vector2(0, 64))
	var dietro := _nemico(Vector2(0, -40))          # piu' vicino, ma alle spalle
	var lontano := _nemico(Vector2(8, 40 + _raggio()))
	var r: Dictionary = _n("/root/AbilityEngine").call("execute", "death_recisione", p)
	assert_true(bool(r["ok"]), "parte: %s" % r["reason"])
	assert_eq(r.get("bersaglio"), davanti, "il bersaglio e' quello davanti")
	assert_true(_status(davanti).has("anima_recisa"), "l'anima recisa e' sul nemico")
	assert_false(_status(p).has("anima_recisa"), "non su chi lancia")
	assert_false(_status(dietro).has("anima_recisa") or _status(lontano).has("anima_recisa"), "ne' sugli altri")
	var hp: float = float(davanti.get_node("StatsComponent").get("hp"))
	_n("/root/AbilityEngine").call("tick_effects", 1.1)
	assert_true(float(davanti.get_node("StatsComponent").get("hp")) < hp, "il logorio (dot) consuma il nemico")
	for n in [p, davanti, dietro, lontano]:
		n.free()


func test_senza_nemico_davanti_non_parte_e_non_costa() -> void:
	var p := _giocatore("death", 3)
	var s: Node = p.get_node("StatsComponent")
	var sp: float = float(s.get("spiritualita"))
	var dietro := _nemico(Vector2(0, -40))
	var morto := _nemico(Vector2(0, 40))
	morto.get_node("StatsComponent").set("hp", 0.0)
	var r: Dictionary = _n("/root/AbilityEngine").call("execute", "death_recisione", p)
	assert_false(bool(r["ok"]), "non parte")
	assert_eq(str(r["reason"]), "nessun_bersaglio", "per mancanza di bersaglio")
	assert_almost_eq(float(s.get("spiritualita")), sp, "la spiritualita' non si spende")
	assert_almost_eq(float(_n("/root/AbilityEngine").call("cooldown_left", p, "death_recisione")), 0.0, "la ricarica non parte")
	assert_false(_status(p).has("anima_recisa"), "niente su chi lancia")
	for n in [p, dietro, morto]:
		n.free()


func test_un_costo_su_di_se_resta_su_chi_lancia() -> void:
	var p := _giocatore("moon", 5)
	var s: Node = p.get_node("StatsComponent")
	var hp_max: float = float(s.call("get_stat", "hp_max"))
	var r: Dictionary = _n("/root/AbilityEngine").call("execute", "moon_patto_di_sangue", p)
	assert_true(bool(r["ok"]), "il patto di sangue non chiede un bersaglio: %s" % r["reason"])
	assert_true(float(s.call("get_stat", "hp_max")) < hp_max, "e la vita massima cala a chi lo stringe")
	p.free()


## Un caster senza fazione (manichini, test isolati) non e' soggetto: come prima, l'effetto resta su di lui.
func test_un_caster_senza_fazione_resta_su_di_se() -> void:
	var host := Node2D.new()
	var s: Node = preload("res://scripts/stats_component.gd").new()
	s.name = "StatsComponent"
	host.add_child(s)
	Engine.get_main_loop().root.add_child(host)
	s.set("spiritualita", 999.0)
	var r: Dictionary = _n("/root/AbilityEngine").call("execute", "death_recisione", host)
	assert_true(bool(r["ok"]), "parte senza bersaglio")
	assert_true((s.call("status_attivi") as Array).has("anima_recisa"), "resta su di lui")
	host.free()


func test_sopra_la_testa_dice_nessun_bersaglio() -> void:
	var p := _giocatore("death", 8)
	var owned: Array = _n("/root/AbilityEngine").call("owned_abilities", p)
	var slot: int = owned.find("death_stretta_della_terra")
	assert_true(slot >= 0 and slot < 4, "la stretta della terra e' nella hotbar")
	var r: Dictionary = p.call("lancia_abilita_slot", slot)
	assert_eq(str(r["reason"]), "nessun_bersaglio", "senza nemici non parte")
	var avviso: Label = p.get_node_or_null("Avviso")
	assert_true(avviso != null, "c'e' l'avviso sopra la testa")
	assert_ne(tr("HUD_ABILITA_NESSUN_BERSAGLIO"), "HUD_ABILITA_NESSUN_BERSAGLIO", "con la sua voce tradotta")
	if avviso != null:
		assert_eq(avviso.text, tr("HUD_ABILITA_NESSUN_BERSAGLIO"), "dice nessun bersaglio")
	p.call("_avvisa", "in_cooldown")
	assert_eq((p.get_node("Avviso") as Label).text, tr("HUD_ABILITA_NESSUN_BERSAGLIO"), "un motivo senza voce non lo copre")
	p.call("_avvisa", "nessun_bersaglio")
	assert_eq(p.get_children().filter(func(c): return str(c.name).begins_with("Avviso")).size(), 1, "uno alla volta")
	p.free()


## L'illusione a danno percepito ferisce chi ci casca, non chi la crea ("bersaglio": "nemico" nell'abilita').
func test_l_illusione_solida_ferisce_il_nemico() -> void:
	var p := _giocatore("fool", 7)
	var e := _nemico(Vector2(0, 50))
	var hp_p: float = float(p.get_node("StatsComponent").get("hp"))
	var hp_e: float = float(e.get_node("StatsComponent").get("hp"))
	var r: Dictionary = _n("/root/AbilityEngine").call("execute", "fool_illusione_solida", p)
	assert_true(bool(r["ok"]), "parte: %s" % r["reason"])
	_n("/root/AbilityEngine").call("tick_effects", 2.1)
	assert_true(float(e.get_node("StatsComponent").get("hp")) < hp_e, "il nemico si ferisce")
	assert_almost_eq(float(p.get_node("StatsComponent").get("hp")), hp_p, "chi la crea no")
	p.free()
	e.free()
