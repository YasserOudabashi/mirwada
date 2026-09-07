extends VBoxContainer
## Pagina "dialogo" del libro (US-613b). Non si sfoglia: ci si finisce quando
## DialogueEngine.avvia() parte. Mostra il nome di chi parla, il testo del nodo
## corrente e un bottone per ogni scelta VALIDA (le altre non compaiono - la
## stessa logica di scelte_valide dell'engine). Il bottone chiama scegli(i).
##
## Si ridisegna a ogni nodo_cambiato. Nessun testo hardcoded: GameData.tr_data.

const C_SPEAKER := Color(0.45, 0.78, 0.82)


func _ready() -> void:
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de != null:
		de.nodo_cambiato.connect(func(_n): aggiorna())
		de.dialogo_finito.connect(func(_id): aggiorna())


func aggiorna() -> void:
	for c in get_children():
		remove_child(c)   # subito fuori: get_children() non li conta piu' (queue_free e' differito)
		c.queue_free()

	var de: Node = get_node_or_null("/root/DialogueEngine")
	var gd: Node = get_node_or_null("/root/GameData")
	if de == null or gd == null or not bool(de.call("in_corso")):
		add_child(_riga("· nessun dialogo in corso ·"))
		return

	var nodo: Dictionary = de.call("nodo_corrente")
	var chi: String = str(de.call("interlocutore"))
	if chi.is_empty():
		chi = str(nodo.get("speaker", ""))
	var npc: Dictionary = gd.call("get_npc", chi)
	var nome: String = str(gd.call("tr_data", npc.get("name_i18n", chi)))

	var l_nome := _riga(nome)
	l_nome.add_theme_color_override("font_color", C_SPEAKER)
	add_child(l_nome)
	add_child(_riga(str(gd.call("tr_data", nodo.get("text_i18n", "")))))

	var vuota := Control.new()
	vuota.custom_minimum_size = Vector2(0, 8)
	add_child(vuota)

	var valide: Array = de.call("scelte_valide")
	for i in valide.size():
		var b := Button.new()
		b.text = str(gd.call("tr_data", (valide[i] as Dictionary).get("text_i18n", "")))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func() -> void: de.call("scegli", i))
		add_child(b)


# --- Interrogabile dai test / verifica a schermo --------------------

func scelte_a_schermo() -> int:
	var n := 0
	for c in get_children():
		if c is Button:
			n += 1
	return n


func _riga(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
