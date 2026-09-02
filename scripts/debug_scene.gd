extends Node2D
## Scena di debug: giocatore, due nemici, un manichino, e un pannello con
## hp / spiritualita' / cooldown / ultima primitiva. Tasti 1-5 eseguono le
## cinque primitive di fase 1 sul giocatore.
##
## NON deve finire nell'export di release: vive sotto scenes/debug/ (i preset
## di export escludono quella cartella) e in piu' si auto-libera se non e'
## una build di debug.
##
## NIENTE class_name: coerente col progetto.

const PRIMITIVE := {
	KEY_1: {"tipo": "projectile", "prim": {"danno": 8.0, "velocita": 180.0, "gittata": 120.0}},
	KEY_2: {"tipo": "melee_arc", "prim": {"danno": 10.0, "angolo": 90.0, "raggio": 28.0}},
	KEY_3: {"tipo": "buff_stat", "prim": {"stat": "velocita", "valore": 40.0, "durata": 3.0}},
	KEY_4: {"tipo": "heal", "prim": {"quantita": 15.0, "istantaneo": true}},
	KEY_5: {"tipo": "dash", "prim": {"distanza": 90.0, "durata": 0.18}},
}

@onready var _player: Node = $Player
@onready var _label: Label = $Pannello/Testo

var _ultima_primitiva: String = "-"


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if PRIMITIVE.has(key.keycode):
		var spec: Dictionary = PRIMITIVE[key.keycode]
		var eng: Node = get_node_or_null("/root/AbilityEngine")
		if eng != null:
			eng.call("esegui_primitiva", spec["tipo"], spec["prim"], _player)
			_ultima_primitiva = spec["tipo"]


func _process(_delta: float) -> void:
	var stats: Node = _player.get_node_or_null("StatsComponent")
	var eng: Node = get_node_or_null("/root/AbilityEngine")
	var righe: Array = []
	if stats != null:
		righe.append("hp  %.0f / %.0f" % [stats.get("hp"), stats.get_stat("hp_max")])
		righe.append("sp  %.0f / %.0f" % [stats.get("spiritualita"), stats.get_stat("spiritualita_max")])
	var cd_dash: float = 0.0
	if eng != null:
		cd_dash = eng.call("cooldown_left", _player, "debug:dash")
	righe.append("cooldown dash  %.1fs" % cd_dash)
	righe.append("ultima primitiva  %s" % _ultima_primitiva)
	righe.append("[1] projectile  [2] melee_arc  [3] buff_stat  [4] heal  [5] dash")
	_label.text = "\n".join(righe)
