extends Node2D
## Manichino da allenamento: hp che si rigenerano subito, cosi' regge colpi
## all'infinito. Per la scena di debug (US-018).
##
## NIENTE class_name: coerente col progetto.

@onready var _stats: Node = $StatsComponent

var colpi_ricevuti: int = 0


func _ready() -> void:
	_stats.configure_from_balance(9)
	var hb: Node = get_node_or_null("Hurtbox")
	if hb != null and hb.has_signal("colpito"):
		hb.colpito.connect(func(_d: float, _s: float, _da: Node, _tag: String) -> void:
			colpi_ricevuti += 1)


func _process(_delta: float) -> void:
	# hp "infiniti": ogni frame tornano al massimo.
	_stats.set("hp", _stats.get_stat("hp_max"))
