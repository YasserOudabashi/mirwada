extends TileMapLayer
## US-1010 (fase 10, Blocco B): l'interno di un edificio - un layout piccolo
## e standalone (niente world_offset/campagna/confine/gating/NPC a orario:
## quella complessita' e' solo per il mondo esterno continuo, US-1002). Un
## interno e' sempre indipendente, mai parte della griglia condivisa:
## entrarci e uscirne resta un caricamento di scena locale
## (world_scene.gd::_su_porta_edificio/_su_uscita_edificio), esattamente
## come funzionavano i passaggi fra regioni PRIMA di US-1002. world_scene.gd
## non viene MAI liberato mentre si e' dentro (resta lo stesso nodo
## persistente di US-1002B): si nasconde e ferma, poi torna.
##
## Painting/nemici/oggetti riusano lo stesso linguaggio dati di
## world_scene.gd (stessa legenda di caratteri, stesso formato nemici/
## oggetti) ma sono una copia minima apposta: un interno non ha bisogno di
## _crea_zone/_crea_gate/_crea_npc/_crea_confine/_riempi_campagna (nessuna
## di quelle nozioni si applica a una stanza), quindi non vale la pena
## condividere codice con world_scene.gd oltre alla legenda.
##
## NIENTE class_name: coerente col resto del progetto.

signal uscita

const TILE := 32
const SORGENTE := 0
const _COLONNA_PER_CARATTERE := {
	".": 0, "#": 1, "o": 2, "~": 3, ",": 4, "=": 5, "t": 6, "+": 7,
}
const _COLONNA_PAVIMENTO := 0
const CALPESTABILI := [".", ",", "=", "+"]

## Impostato da chi istanzia questa scena (world_scene.gd) PRIMA di
## aggiungerla all'albero, cosi' _ready() lo trova gia' pronto.
var interno_id: String = ""


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	if interno_id.is_empty():
		return
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var layout: Dictionary = gd.call("get_interno", interno_id)
	if layout.is_empty():
		return
	_dipingi(layout)
	_crea_uscita(layout)
	_crea_nemici(layout)
	_crea_oggetti(layout)


func _dipingi(layout: Dictionary) -> void:
	var mappa: Array = (layout.get("mappa", []) as Array)
	for y in mappa.size():
		var riga: String = str(mappa[y])
		for x in riga.length():
			var col: int = int(_COLONNA_PER_CARATTERE.get(riga[x], _COLONNA_PAVIMENTO))
			set_cell(Vector2i(x, y), SORGENTE, Vector2i(col, 0))


func _cella_spawn(layout: Dictionary) -> Vector2i:
	var sp: Array = (layout.get("spawn", []) as Array)
	return Vector2i(int(sp[0]), int(sp[1])) if sp.size() == 2 else Vector2i(1, 1)


## Posizione globale di spawn - dove il giocatore appare entrando dalla
## porta esterna.
func punto_spawn() -> Vector2:
	var gd: Node = get_node_or_null("/root/GameData")
	var layout: Dictionary = gd.call("get_interno", interno_id) if gd != null else {}
	return to_global(map_to_local(_cella_spawn(layout)))


## L'uscita coincide con la cella di spawn (si rientra dalla stessa porta da
## cui si e' entrati): tornarci vicino riporta alla mappa esterna.
func _crea_uscita(layout: Dictionary) -> void:
	var area := Area2D.new()
	area.name = "Uscita"
	area.position = map_to_local(_cella_spawn(layout))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	area.add_child(shape)
	# Il player appare GIA' su questa cella entrando (e' anche lo spawn):
	# il primo body_entered che l'Area2D vede, appena aggiunta all'albero,
	# e' quel corpo gia' presente - non un vero ritorno alla porta. Stesso
	# problema (e stessa soluzione) della porta esterna, world_scene.gd::
	# _su_porta_edificio/ignora_prossimo_ingresso.
	area.set_meta("ignora_primo_ingresso", true)
	area.body_entered.connect(_su_ingresso_uscita.bind(area))
	add_child(area)


func _su_ingresso_uscita(body: Node, area: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	if bool(area.get_meta("ignora_primo_ingresso", false)):
		area.set_meta("ignora_primo_ingresso", false)
		return
	uscita.emit()


func _crea_nemici(layout: Dictionary) -> void:
	for n in (layout.get("nemici", []) as Array):
		var spec: Dictionary = n as Dictionary
		var sequenza: int = int(spec.get("sequenza", 9))
		var e: Node = preload("res://scenes/enemy.tscn").instantiate()
		e.set("override", (spec.get("override", {}) as Dictionary).duplicate(true))
		e.set("scale", Vector2.ONE * float(spec.get("scala", 1.0)))
		add_child(e)
		e.set("global_position", to_global(map_to_local(
			Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		e.set("sequenza", sequenza)
		e.get_node("StatsComponent").call("configure_from_balance", sequenza)


func _crea_oggetti(layout: Dictionary) -> void:
	for o in (layout.get("oggetti", []) as Array):
		var spec: Dictionary = o as Dictionary
		var pickup := preload("res://scripts/item_pickup.gd").new()
		add_child(pickup)
		pickup.call("setup", str(spec.get("item_id", "")), to_global(map_to_local(
			Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		pickup.set("quantita", int(spec.get("quantita", 1)))
