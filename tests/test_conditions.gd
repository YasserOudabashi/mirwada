extends "res://tests/test_case.gd"
## US-605 — AbilityEngine verifica le condizioni delle abilita' prima di
## pagare il costo. Valgono solo col giocatore in scena; un caster senza
## contesto (nemici, test isolati) le ignora. execute_stored non le verifica.

const Stats := preload("res://scripts/stats_component.gd")
const Conditions := preload("res://scripts/conditions.gd")
const SPM := 120.0


func _root() -> Node: return Engine.get_main_loop().root
func _e() -> Node: return _root().get_node("AbilityEngine")
func _gd() -> Node: return _root().get_node("GameData")
func _ts() -> Node: return _root().get_node("TimeSystem")
func _prog() -> Node: return _root().get_node("Progression")


func prepara() -> void:
	_e().call("clear_cooldowns")
	_e().call("flush_effects")
	_ts().call("da_salvataggio", {})       # tick 0 -> "alba", giorno
	_ts().call("imposta_pausa", false)
	_prog().call("configura", "", 9)        # nessun Pathway -> ownership aperta


## gruppo_player: se true il caster e' soggetto alle condizioni (US-605).
## grant: id di abilita' da prestare al caster cosi' l'ownership non c'entra
## (il test isola la verifica delle CONDIZIONI, non del possesso).
func _caster(gruppo_player: bool, grant: Array = []) -> Node2D:
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	if gruppo_player:
		c.add_to_group("player")
	_root().add_child(c)
	s.call("configure_from_balance", 7)
	s.set("spiritualita", 9999.0)
	for aid in grant:
		_e().call("grant_temporary", str(aid), c, 9999.0)
	return c


func _cleanup(c: Node) -> void:
	_root().remove_child(c)
	c.free()


func _notte() -> void:
	_ts().call("avanza", SPM * 2)  # alba -> mezzogiorno -> crepuscolo (notte)


func test_condizione_e_notte_blocca_di_giorno_senza_pagare() -> void:
	var c: Node2D = _caster(true, ["moon_furia_notturna"])
	var s: Node = c.get_node("Stats")
	var sp0: float = float(s.get("spiritualita"))
	var r: Dictionary = _e().call("execute", "moon_furia_notturna", c)
	assert_false(r["ok"], "moon_furia_notturna rifiutata di giorno")
	assert_eq(str(r["reason"]), _e().ERR_CONDIZIONE, "motivo: condizione_non_soddisfatta")
	assert_almost_eq(float(s.get("spiritualita")), sp0, "nessun costo pagato sul rifiuto")
	_cleanup(c)


func test_condizione_e_notte_ok_di_notte() -> void:
	_notte()
	var c: Node2D = _caster(true, ["moon_furia_notturna"])
	var r: Dictionary = _e().call("execute", "moon_furia_notturna", c)
	assert_true(r["ok"], "moon_furia_notturna eseguita di notte: %s" % r.get("reason"))
	_cleanup(c)


func test_caster_senza_contesto_ignora_le_condizioni() -> void:
	# giorno, ma il caster non e' nel gruppo "player": nessuna restrizione
	var c: Node2D = _caster(false)  # niente grant: ownership sconosciuta = aperta
	var r: Dictionary = _e().call("execute", "moon_furia_notturna", c)
	assert_true(r["ok"], "un caster senza contesto esegue anche di giorno")
	_cleanup(c)


func test_costellazione_del_custode_solo_a_luna_piena() -> void:
	var c: Node2D = _caster(true, ["hermit_costellazione_del_custode"])
	var r1: Dictionary = _e().call("execute", "hermit_costellazione_del_custode", c)
	assert_false(r1["ok"], "rifiutata se la luna non e' piena (fase '%s')" % _ts().call("fase_lunare"))
	# avanza fino a fase_lunare "piena" (giorno 6: f_idx = 6/3 % 4 = 2)
	_ts().call("avanza", SPM * 4 * 6)
	assert_eq(str(_ts().call("fase_lunare")), "piena", "ora la luna e' piena")
	_e().call("clear_cooldowns")
	var r2: Dictionary = _e().call("execute", "hermit_costellazione_del_custode", c)
	assert_true(r2["ok"], "eseguita a luna piena: %s" % r2.get("reason"))
	_cleanup(c)


func test_abilita_senza_condizioni_non_cambia() -> void:
	var c: Node2D = _caster(true, ["moon_distillato_curativo"])  # giorno
	var r: Dictionary = _e().call("execute", "moon_distillato_curativo", c)
	assert_true(r["ok"], "un'abilita' senza 'condizioni' esegue sempre")
	_cleanup(c)


func test_execute_stored_non_verifica_le_condizioni() -> void:
	# di giorno, caster nel gruppo player: execute() la rifiuterebbe, ma
	# execute_stored (oggetto = permesso) no.
	var c: Node2D = _caster(true)
	var r: Dictionary = _e().call("execute_stored", "moon_furia_notturna", c)
	assert_true(r["ok"], "execute_stored ignora le condizioni")
	_cleanup(c)


func test_conditions_helper_lenient_e_lista_vuota() -> void:
	assert_true(Conditions.tutte_soddisfatte([]), "lista vuota -> soddisfatta")
	assert_true(Conditions.tutte_soddisfatte("non una lista"), "non-lista -> soddisfatta")
	assert_true(Conditions.soddisfatta("tipo_inventato", 1), "tipo ignoto -> non blocca")
