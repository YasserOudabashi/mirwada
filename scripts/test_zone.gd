extends TileMapLayer
## Area di test: NON e' una zona di gioco, e' il banco di prova per tutti i
## sistemi delle story successive (nemici, abilita', HUD, save). La struttura
## e' dipinta a runtime da un semplice schema — bordo di muri, una stanza
## grande a sinistra, un corridoio, una stanza piu' piccola a destra —
## abbastanza per verificare collisioni e limiti di camera.
##
## Il formato dati delle zone vere (regions.json) e' roba di fase 2: qui
## sarebbe sovradimensionato.
##
## NIENTE class_name: coerente col resto del progetto.

const TILE := 32
const W := 40
const H := 30

const SORGENTE := 0
const PAVIMENTO := Vector2i(0, 0)
const MURO := Vector2i(1, 0)
const OSTACOLO := Vector2i(2, 0)

## Cella di comparsa del giocatore, dentro la stanza di sinistra.
const SPAWN := Vector2i(7, 15)

## Muri interni: colonna x, con un varco (gap) verticale che fa da passaggio.
const MURI_INTERNI := [
	{"x": 15, "gap_da": 13, "gap_a": 16},  # stanza sx -> corridoio
	{"x": 28, "gap_da": 12, "gap_a": 15},  # corridoio -> stanza dx
]

## Ostacoli singoli (non attraversabili come i muri, ma sparsi).
const OSTACOLI: Array[Vector2i] = [
	Vector2i(5, 6), Vector2i(6, 6), Vector2i(10, 22), Vector2i(4, 24),
	Vector2i(21, 8), Vector2i(33, 20), Vector2i(34, 21),
]


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	_dipingi()
	_colloca_giocatore()


func _dipingi() -> void:
	for x in W:
		for y in H:
			var bordo: bool = x == 0 or y == 0 or x == W - 1 or y == H - 1
			set_cell(Vector2i(x, y), SORGENTE, MURO if bordo else PAVIMENTO)

	for muro in MURI_INTERNI:
		for y in range(1, H - 1):
			if y < muro["gap_da"] or y > muro["gap_a"]:
				set_cell(Vector2i(muro["x"], y), SORGENTE, MURO)

	# corridoio: pareti sopra e sotto tra i due muri interni
	for x in range(16, 28):
		set_cell(Vector2i(x, 11), SORGENTE, MURO)
		set_cell(Vector2i(x, 18), SORGENTE, MURO)

	for c in OSTACOLI:
		set_cell(c, SORGENTE, OSTACOLO)


func _colloca_giocatore() -> void:
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		return
	player.global_position = to_global(map_to_local(SPAWN))

	var cam := player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("apply_zone_limits"):
		cam.call("apply_zone_limits", Rect2(global_position, Vector2(W * TILE, H * TILE)))
