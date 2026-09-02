extends "res://tests/test_case.gd"
## US-010 — postura e parata.

const PosturaComponent := preload("res://scripts/postura_component.gd")
const Hurtbox := preload("res://scripts/hurtbox.gd")
const StatsComponent := preload("res://scripts/stats_component.gd")


func _postura() -> Node:
	var p: Node = PosturaComponent.new()
	p.configura(100.0, 3.0, 15.0)
	return p


func test_erodi_riduce_la_postura() -> void:
	var p: Node = _postura()
	p.erodi(30.0)
	assert_almost_eq(p.postura(), 70.0, "postura ridotta di 30")
	assert_false(p.is_vulnerabile(), "non ancora rotta")
	p.free()


func test_a_zero_diventa_vulnerabile() -> void:
	var p: Node = _postura()
	var conteggio := {"rotte": 0}
	p.postura_rotta.connect(func() -> void: conteggio.rotte += 1)
	p.erodi(120.0)
	assert_true(p.is_vulnerabile(), "vulnerabile a postura zero")
	assert_eq(conteggio.rotte, 1, "segnale postura_rotta una volta")
	p.free()


func test_recupero_dopo_la_vulnerabilita() -> void:
	var p: Node = _postura()
	p.erodi(120.0)
	# simula 3.1 s: il _process non gira fuori dall'albero, lo chiamo a mano
	for i in 31:
		p._process(0.1)
	assert_false(p.is_vulnerabile(), "vulnerabilita' finita dopo la durata")
	assert_almost_eq(p.postura(), 100.0, "postura tornata piena")
	p.free()


func test_parata_perfetta_annulla_il_danno() -> void:
	var host := Node.new()
	var stats: Node = StatsComponent.new()
	stats.configure_from_balance(9)
	host.add_child(stats)
	var hb: Area2D = Hurtbox.new()
	host.add_child(hb)
	var hp0: float = stats.hp
	var visti: Array = []
	hb.parata_riuscita.connect(func(perf: bool, _a: Node) -> void: visti.append(perf))

	hb.set_parata(Hurtbox.Parata.PERFETTA)
	hb.subisci(30.0, 10.0, null)
	assert_almost_eq(stats.hp, hp0, "parata perfetta: nessun danno")
	assert_eq(visti, [true], "segnale parata_riuscita perfetta")
	host.free()


func test_blocco_riduce_il_danno() -> void:
	var host := Node.new()
	var stats: Node = StatsComponent.new()
	stats.configure_from_balance(9)
	host.add_child(stats)
	var hb: Area2D = Hurtbox.new()
	hb.configura_blocco(0.5)
	host.add_child(hb)
	var hp0: float = stats.hp

	hb.set_parata(Hurtbox.Parata.BLOCCO)
	hb.subisci(30.0, 10.0, null)
	assert_almost_eq(stats.hp, hp0 - 15.0, "blocco al 50%: meta' danno")
	host.free()


func test_lo_stagger_erode_la_postura_del_bersaglio() -> void:
	var host := Node.new()
	var post: Node = PosturaComponent.new()
	post.configura(100.0, 3.0, 15.0)
	host.add_child(post)
	var hb: Area2D = Hurtbox.new()
	host.add_child(hb)

	hb.subisci(0.0, 25.0, null)
	assert_almost_eq(post.postura(), 75.0, "lo stagger del colpo erode la postura")
	host.free()
