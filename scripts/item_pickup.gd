extends "res://scripts/characteristic_pickup.gd"
## US-806: oggetto generico a terra dal layout (ingrediente, valuta, ...).
## Riusa Area2D/setup(id, posizione)/_raccolta del genitore: 'id' passato a
## setup() e' l'item_id (stesso campo char_id, riletto qui come tale).
##
## NIENTE class_name: coerente col resto del progetto.

var quantita: int = 1


func raccogli() -> bool:
	if _raccolta or char_id.is_empty():
		return false
	_raccolta = true
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	if inv != null:
		inv.call("aggiungi", char_id, quantita)
	queue_free()
	return true
