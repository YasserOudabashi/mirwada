extends Area2D
## Campo d'area di aura / decay (US-218C). Figlio del caster. A ogni tick
## trova le hurtbox nel raggio e applica lo status (aura) o il danno (decay).
## Si autodistrugge a fine durata; durata -1 = finche' il caster e' valido.
##
## Costruito a runtime come projectile/melee_arc: nessuna scena dedicata.
##
## NIENTE class_name: coerente col progetto.

var tipo: String = "aura"          # "aura" | "decay"
var raggio: float = 32.0
var durata: float = 5.0            # -1 = persistente
var tick_rate: float = 1.0
var effetto: String = ""           # aura: lo status da applicare
var danno_tick: float = 0.0        # decay: danno per tick
var bersagli_nemici: bool = true   # per ora: colpisce chi NON e' il caster

var _left: float = 0.0
var _acc: float = 0.0
var _caster: Node = null


func setup(spec: Dictionary, caster: Node) -> void:
	tipo = str(spec.get("tipo", "aura"))
	raggio = float(spec.get("raggio", 32.0))
	durata = float(spec.get("durata", 5.0))
	tick_rate = maxf(0.05, float(spec.get("tick_rate", 1.0)))
	effetto = str(spec.get("effetto", ""))
	danno_tick = float(spec.get("danno_tick", 0.0))
	_caster = caster
	_left = durata

	collision_mask = 4  # le hurtbox stanno sul layer 3 (bit 4)
	monitoring = true
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = maxf(1.0, raggio)
	shape.shape = c
	add_child(shape)


func _process(delta: float) -> void:
	if durata >= 0.0:
		_left -= delta
		if _left <= 0.0:
			queue_free()
			return
	elif not is_instance_valid(_caster):
		queue_free()
		return

	_acc += delta
	if _acc < tick_rate:
		return
	_acc -= tick_rate
	_applica_tick()


func _applica_tick() -> void:
	for a in get_overlapping_areas():
		var host: Node = a.get_parent()
		if host == null or host == _caster:
			continue
		var stats: Node = host if host.has_method("applica_status") else host.get_node_or_null("StatsComponent")
		if stats == null:
			for ch in host.get_children():
				if ch.has_method("applica_status"):
					stats = ch
					break
		if stats == null:
			continue
		if tipo == "aura" and not effetto.is_empty():
			stats.call("applica_status", effetto, -1.0)
		elif tipo == "decay" and danno_tick > 0.0:
			stats.set("hp", float(stats.get("hp")) - danno_tick)
