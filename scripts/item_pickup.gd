extends "res://scripts/characteristic_pickup.gd"
## US-806: oggetto generico a terra dal layout (ingrediente, valuta, ...).
## Riusa Area2D/setup(id, posizione)/_raccolta del genitore: 'id' passato a
## setup() e' l'item_id (stesso campo char_id, riletto qui come tale).
##
## NIENTE class_name: coerente col resto del progetto.

var quantita: int = 1


## US-8B70: l'icona dell'oggetto (GameData.icona_oggetto, 32 px) a mezza grandezza come gli sprite a 64 px:
## a schermo mostra tutti i suoi pixel. Sotto, l'ombra a terra dei personaggi (vfx.json ombra_terra, raggi
## "oggetto") al fondo del disegno. Senza icona resta il rombo del genitore.
func _crea_marker() -> Node2D:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var tex: Texture2D = gd.call("icona_oggetto", char_id) if gd != null else null
	if tex == null:
		return super._crea_marker()
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(0.5, 0.5)
	var dati: Dictionary = gd.call("get_vfx", "ombra_terra")
	var r: Variant = (dati.get("raggi", {}) as Dictionary).get("oggetto")
	if r is Array and (r as Array).size() >= 2:
		var colore := Color(str(dati.get("colore", "#181425")))
		colore.a = float(dati.get("alpha", 0.3))
		var ombra := Node2D.new()
		ombra.name = "OmbraTerra"
		ombra.show_behind_parent = true
		ombra.position = Vector2(0, tex.get_image().get_used_rect().end.y - tex.get_height() / 2.0 - 2.0)
		ombra.scale = Vector2(2, 2)                 # in unita' di gioco, come lo sprite a mezza grandezza
		ombra.draw.connect(func() -> void:
			preload("res://scripts/animation_machine.gd").ellisse_a_righe(ombra, Vector2(r[0], r[1]), colore))
		sprite.add_child(ombra)
	return sprite


func raccogli() -> bool:
	if _raccolta or char_id.is_empty():
		return false
	_raccolta = true
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	if inv != null:
		inv.call("aggiungi", char_id, quantita)
	queue_free()
	return true
