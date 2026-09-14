extends VBoxContainer
## Pagina mappa del libro (US-617). Doppia pagina: le regioni SCOPERTE
## (WorldState), la posizione corrente, i gate noti. Le regioni mai visitate
## sono assenti - fog of war, come il diagramma dei Pathway.
##
## Fast travel = potere (design-world cap. 7): niente teletrasporto da menu.
## Da un nodo mappa si viaggia SOLO se il giocatore ha un mezzo del suo Pathway
## (una primitiva teleport nelle Sequenze gia' raggiunte: door_3 "viaggio
## lungo", death_5 "passo tra i mondi") o un varco permanente aperto dal TG.
## Altrimenti: "servono le strade".
##
## Chrome da assets/i18n/strings.csv + tr(); nomi delle regioni da tr_data.

const AreaGate := preload("res://scripts/area_gate.gd")

const C_CORRENTE := Color(0.4, 0.76, 0.82)


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()

	var gd: Node = _n("/root/GameData")
	var ws: Node = _n("/root/WorldState")
	if gd == null or ws == null:
		return

	var scoperte: Array = ws.call("scoperte")
	var corrente: String = str(ws.call("regione_corrente"))
	if scoperte.is_empty():
		add_child(_riga(tr("BOOK_MAPPA_VUOTA")))
		return

	var puo: bool = _puo_viaggiare()
	add_child(_riga(tr("BOOK_MAPPA_MEZZO_SI") if puo else tr("BOOK_MAPPA_MEZZO_NO")))

	for r in gd.call("get_regions"):
		var rid: String = str((r as Dictionary).get("id", ""))
		if rid not in scoperte:
			continue
		var h := HBoxContainer.new()
		var nome: String = str(gd.call("tr_data", (r as Dictionary).get("name_i18n", rid)))
		var l := Label.new()
		l.custom_minimum_size = Vector2(220, 0)
		if rid == corrente:
			l.text = "▸ " + nome + "  (" + tr("BOOK_MAPPA_QUI") + ")"
			l.add_theme_color_override("font_color", C_CORRENTE)
		else:
			l.text = nome
		h.add_child(l)

		# gate noti della regione (dai dati; il fog of war vero sui gate e' US-621)
		var gate_txt: Array = []
		for g in (r as Dictionary).get("gating", []):
			gate_txt.append(str((g as Dictionary).get("area", "")))
		if not gate_txt.is_empty():
			var gl := Label.new()
			gl.text = tr("BOOK_MAPPA_GATE") + " " + ", ".join(gate_txt)
			gl.modulate = Color(1, 1, 1, 0.55)
			h.add_child(gl)

		if rid != corrente:
			var b := Button.new()
			b.text = tr("BOOK_MAPPA_VIAGGIA")
			b.disabled = not puo
			b.pressed.connect(_viaggia.bind(rid))
			h.add_child(b)
		add_child(h)


func _viaggia(target: String) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	# il nodo mondo si riconosce dal suo contratto pubblico (viaggia_a), non
	# dal nome dello script: world_scene.gd l'ha sostituito a region_scene.gd
	# (US-1002B, fase 10 - mondo continuo, mai piu' una scena per regione).
	for c in main.get_children():
		if c.has_method("viaggia_a"):
			if bool(c.call("viaggia_a", target)):
				var book: Node = _n("/root/Book")
				if book != null:
					book.call("chiudi")
			return


## Il giocatore ha un mezzo di fast travel: una primitiva teleport nelle
## Sequenze gia' raggiunte, o un varco permanente inciso nel mondo dal TG.
func _puo_viaggiare() -> bool:
	if AreaGate._possiede_primitiva(get_tree().root, "teleport"):
		return true
	var ws: Node = _n("/root/WorldState")
	for t in (ws.call("terreni") if ws != null else []):
		if str((t as Dictionary).get("tipo_modifica", "")).begins_with("apre_varco"):
			return true
	return false


func testo_visibile() -> String:
	return "mappa"


func _riga(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _n(path: String) -> Node:
	return get_node_or_null(path)
