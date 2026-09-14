extends "res://scripts/characteristic_pickup.gd"
## US-806: oggetto generico a terra dal layout (ingrediente, valuta, ...).
## Riusa Area2D/setup(id, posizione)/_raccolta del genitore: 'id' passato a
## setup() e' l'item_id (stesso campo char_id, riletto qui come tale).
##
## NIENTE class_name: coerente col resto del progetto.

## Ordine delle 6 categorie non-ingrediente in oggetti.png, colonne 3-8
## (le colonne 0-2 sono le varianti di "ingrediente" — vedi
## tools/generate_sprites.py.OGGETTI_COLONNE, stesso ordine).
const _CATEGORIE_COLONNA := ["equip", "sigillo", "pergamena", "materiale", "valuta", "consumabile"]
const _TILE := 32

var quantita: int = 1


## US-813: l'icona della categoria dell'item (con variante per gli
## ingredienti, scelta dal tag dominante) invece del rombo generico.
func _crea_marker() -> Node2D:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var it: Dictionary = gd.call("get_item", char_id) if gd != null else {}
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/placeholder/oggetti.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(_colonna_icona(it) * _TILE, 0, _TILE, _TILE)
	return sprite


func _colonna_icona(it: Dictionary) -> int:
	if str(it.get("categoria", "")) == "ingrediente":
		var tag: Array = it.get("tag", [])
		if tag.has("crescita"):
			return 0  # erba
		if tag.has("terra"):
			return 1  # minerale
		return 2  # fiala
	var i: int = _CATEGORIE_COLONNA.find(str(it.get("categoria", "")))
	return 3 + i if i >= 0 else 3 + _CATEGORIE_COLONNA.size() - 1


func raccogli() -> bool:
	if _raccolta or char_id.is_empty():
		return false
	_raccolta = true
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	if inv != null:
		inv.call("aggiungi", char_id, quantita)
	queue_free()
	return true
