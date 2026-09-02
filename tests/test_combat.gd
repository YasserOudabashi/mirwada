extends "res://tests/test_case.gd"
## US-008 — spina dorsale del combattimento: Hurtbox instrada il danno,
## rispetta invulnerabilita' e non-autodanno.

const Hurtbox := preload("res://scripts/hurtbox.gd")
const StatsComponent := preload("res://scripts/stats_component.gd")


func _entita() -> Dictionary:
	var host := Node.new()
	var stats: Node = StatsComponent.new()
	stats.configure_from_balance(9)
	host.add_child(stats)
	var hb: Area2D = Hurtbox.new()
	host.add_child(hb)
	return {"host": host, "stats": stats, "hurtbox": hb}


func test_il_colpo_toglie_hp_dallo_stats_del_genitore() -> void:
	var e: Dictionary = _entita()
	var hp0: float = e["stats"].hp
	e["hurtbox"].subisci(15.0, 5.0, null)
	assert_almost_eq(e["stats"].hp, hp0 - 15.0, "hp ridotti del danno")
	e["host"].free()


func test_invulnerabile_annulla_il_colpo() -> void:
	var e: Dictionary = _entita()
	var hp0: float = e["stats"].hp
	e["hurtbox"].set_invulnerabile(true)
	e["hurtbox"].subisci(15.0, 5.0, null)
	assert_almost_eq(e["stats"].hp, hp0, "nessun danno da invulnerabile")
	e["host"].free()


func test_niente_autodanno() -> void:
	var e: Dictionary = _entita()
	var hp0: float = e["stats"].hp
	# 'da' e' il genitore della hurtbox: e' se stessi, va ignorato
	e["hurtbox"].subisci(15.0, 5.0, e["host"])
	assert_almost_eq(e["stats"].hp, hp0, "un colpo dal proprietario non fa danno")
	e["host"].free()


func test_segnale_colpito_emesso() -> void:
	var e: Dictionary = _entita()
	var visti: Array = []
	e["hurtbox"].colpito.connect(func(d: float, s: float, _da: Node) -> void: visti.append([d, s]))
	e["hurtbox"].subisci(9.0, 3.0, null)
	assert_eq(visti, [[9.0, 3.0]], "segnale colpito con danno e stagger")
	e["host"].free()
