extends "res://tests/test_case.gd"
## US-714 — preghiere delle Sequenze alte. Il campo 'preghiera' e' PURAMENTE
## semantico + i18n (data/schema/prayer_effects.json, vocabolario chiuso di
## US-703): l'effetto meccanico lo fanno le primitive gia' esistenti
## dell'abilita' (aura/curse/heal). Nessuna primitiva nuova.

const Stats := preload("res://scripts/stats_component.gd")

const ABILITA_CON_PREGHIERA := {
	"darkness_anatema_del_vuoto": "anatema",
	"tg_giuramento_del_crepuscolo": "voto_di_autorita",
	"death_benedizione_dei_caduti": "benedizione_seguaci",
	"hermit_intercessione_arcana": "intercessione",
	"mother_benedizione_della_covata": "benedizione_seguaci",
	"door_anatema_del_varco": "anatema",
}


func _root() -> Node: return Engine.get_main_loop().root
func _e() -> Node: return _root().get_node("AbilityEngine")
func _gd() -> Node: return _root().get_node("GameData")


func prepara() -> void:
	_e().call("clear_cooldowns")
	_e().call("flush_effects")


func _caster() -> Node2D:
	# Node2D NUDO (non nel gruppo "player"): isola l'esecuzione delle primitive
	# dalle condizioni di contesto (US-605), come le altre suite di Sequenza alta.
	var c := Node2D.new()
	var s: Node = Stats.new()
	s.name = "Stats"
	c.add_child(s)
	_root().add_child(c)
	s.call("configure_from_balance", 1)
	s.set("spiritualita", 9999.0)
	return c


func _cleanup(c: Node) -> void:
	_root().remove_child(c)
	c.free()


func test_ogni_abilita_con_preghiera_si_esegue_senza_warning() -> void:
	for aid in ABILITA_CON_PREGHIERA:
		var c: Node2D = _caster()
		var r: Dictionary = _e().call("execute", aid, c)
		assert_true(r["ok"], "%s eseguita: %s" % [aid, r.get("reason")])
		assert_eq((r["warnings"] as PackedStringArray).size(), 0,
			"%s: nessun warning di primitiva: %s" % [aid, r["warnings"]])
		_e().call("clear_cooldowns")
		_cleanup(c)


func test_il_campo_preghiera_e_solo_semantico() -> void:
	# Il campo non deve comparire nei parametri di nessuna primitiva: se
	# l'engine lo leggesse come dato di gameplay sarebbe un parametro non
	# dichiarato (il validator lo boccerebbe, tools/validate_data.py). Qui
	# verifichiamo solo che GameData esponga il valore dichiarato nei dati,
	# preso dal vocabolario chiuso di data/schema/prayer_effects.json (US-703).
	const VOCABOLARIO := ["benedizione_seguaci", "voto_di_autorita", "intercessione", "anatema"]
	for aid in ABILITA_CON_PREGHIERA:
		var ab: Dictionary = _gd().call("get_ability", aid)
		var pray: String = ab.get("preghiera", "")
		assert_eq(pray, ABILITA_CON_PREGHIERA[aid], "%s: preghiera dichiarata" % aid)
		assert_true(VOCABOLARIO.has(pray), "%s: preghiera nel vocabolario chiuso" % pray)
