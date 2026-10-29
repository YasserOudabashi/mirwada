extends Node2D
## US-8B71: le icone degli status attivi (GameData.icona_stato, 16 px) in fila sopra la testa, a mezza grandezza
## come le altre icone del mondo. Negli ultimi secondi di uno status a tempo l'icona lampeggia.
##
## NIENTE class_name: coerente col resto del progetto.

const PASSO := 10.0                  # unita' tra un'icona e l'altra (8 dell'icona + 2)
const LAMPEGGIO := 2.0               # secondi finali in cui l'icona lampeggia

var _stats: Node = null
var _icone: Dictionary = {}          # status id -> Sprite2D


func collega(stats: Node) -> void:
	_stats = stats
	stats.status_cambiati.connect(_ridisegna)
	_ridisegna()


func _ridisegna() -> void:
	for c in get_children():
		c.free()
	_icone.clear()
	var gd: Node = get_node_or_null("/root/GameData")
	var ids: Array = (_stats.call("status_attivi") as Array).filter(func(i: String) -> bool:
		return gd != null and gd.call("icona_stato", i) != null)
	ids.sort()
	for k in ids.size():
		var s := Sprite2D.new()
		s.name = str(ids[k])
		s.texture = gd.call("icona_stato", ids[k])
		s.scale = Vector2(0.5, 0.5)
		s.position = Vector2((k - (ids.size() - 1) / 2.0) * PASSO, 0)
		add_child(s)
		_icone[ids[k]] = s
	set_process(not _icone.is_empty())


func _process(_delta: float) -> void:
	var acceso: bool = fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
	for id in _icone:
		var resta: float = float(_stats.call("status_rimasto", id))
		(_icone[id] as Sprite2D).modulate.a = 0.35 if resta >= 0.0 and resta < LAMPEGGIO and not acceso else 1.0
