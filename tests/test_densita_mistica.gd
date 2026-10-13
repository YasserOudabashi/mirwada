extends "res://tests/test_case.gd"
## US-618 — densita' mistica: WorldState.densita_mistica_corrente() dalla
## regione; il recupero di spiritualita' e l'attenuazione del malus di
## forzatura scalano con essa; la percezione della densita' parte da Seq 5.

const StatsComponent := preload("res://scripts/stats_component.gd")


func _root() -> Node: return Engine.get_main_loop().root
func _ws() -> Node: return _root().get_node("WorldState")
func _pr() -> Node: return _root().get_node("Progression")
func _ps() -> Node: return _root().get_node("PerceptionSystem")
func _found() -> Node: return _root().get_node("Foundation")


func prepara() -> void:
	_ws().call("pulisci")
	_pr().call("configura", "twilight_giant", 9)


func test_densita_corrente_dalla_regione_e_override() -> void:
	var ws: Node = _ws()
	assert_almost_eq(ws.call("densita_mistica_corrente"), 0.2, "fuori regione: bassa (0.2)")
	ws.call("entra_regione", "mirwada")
	assert_almost_eq(ws.call("densita_mistica_corrente"), 0.2, "la citta' e' bassa")
	ws.call("entra_regione", "archivio_sepolto")
	assert_almost_eq(ws.call("densita_mistica_corrente"), 0.7, "l'Archivio e' 0.7")
	ws.call("imposta_densita_override", 0.95)
	assert_almost_eq(ws.call("densita_mistica_corrente"), 0.95, "una zona puo' forzare un override locale")
	ws.call("imposta_densita_override", -1.0)
	assert_almost_eq(ws.call("densita_mistica_corrente"), 0.7, "tolto l'override torna quella della regione")


func _guadagno_spiritualita(regione: String, secondi: int) -> float:
	_ws().call("entra_regione", regione)
	var player := Node2D.new()
	player.add_to_group("player")
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	player.add_child(st)
	_root().add_child(player)
	st.call("configure_from_balance", 9)
	st.set("spiritualita", 1.0)
	var prima: float = st.get("spiritualita")
	for i in secondi:
		st.call("_process", 1.0)
	var dopo: float = st.get("spiritualita")
	player.free()
	return dopo - prima


func test_il_recupero_di_spiritualita_scala_con_la_densita() -> void:
	var g_bassa: float = _guadagno_spiritualita("mirwada", 3)          # 0.2
	var g_alta: float = _guadagno_spiritualita("archivio_sepolto", 3)  # 0.7
	assert_gt(g_bassa, 0.0, "in citta' si recupera comunque")
	assert_gt(g_alta, g_bassa, "in una regione a densita' alta si recupera di piu'")


func test_i_nemici_non_rigenerano_spiritualita() -> void:
	_ws().call("entra_regione", "archivio_sepolto")
	var nemico := Node2D.new()   # NON nel gruppo player
	var st: Node = StatsComponent.new()
	st.name = "StatsComponent"
	nemico.add_child(st)
	_root().add_child(nemico)
	st.call("configure_from_balance", 9)
	st.set("spiritualita", 1.0)
	for i in 5:
		st.call("_process", 1.0)
	assert_almost_eq(st.get("spiritualita"), 1.0, "un nemico non recupera")
	nemico.free()


func test_percezione_della_densita_da_sequenza_5() -> void:
	var ps: Node = _ps()
	_ws().call("entra_regione", "archivio_sepolto")
	_pr().call("configura", "twilight_giant", 9)
	assert_almost_eq(ps.call("densita_percepita"), -1.0, "a Seq 9 non la percepisci")
	_pr().call("configura", "twilight_giant", 5)
	assert_almost_eq(ps.call("densita_percepita"), 0.7, "da Seq 5 la senti")
	_pr().call("configura", "twilight_giant", 3)
	assert_almost_eq(ps.call("densita_percepita"), 0.7, "e resta sentita salendo")


func test_forzare_costa_meno_dove_la_densita_e_alta() -> void:
	var f: Node = _found()
	_ws().call("entra_regione", "mirwada")           # 0.2
	var malus_citta: float = f.call("malus_forzatura")
	_ws().call("entra_regione", "frontiera_porte")   # 0.9
	var malus_frontiera: float = f.call("malus_forzatura")
	assert_true(malus_citta < 0.0, "il malus e' negativo")
	assert_gt(malus_frontiera, malus_citta, "alla Frontiera il malus e' meno severo (piu' vicino a 0)")


func test_spawn_rate_sale_con_la_densita() -> void:
	var ws: Node = _ws()
	ws.call("entra_regione", "mirwada")
	var r_citta: float = ws.call("spawn_rate_corrente")
	ws.call("entra_regione", "frontiera_porte")
	assert_gt(ws.call("spawn_rate_corrente"), r_citta, "fuori citta' si spawna/trova di piu'")
