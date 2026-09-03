extends VBoxContainer
## Frontespizio (US-223). Partita nuova: campo nome con "Enel" gia' scritto
## (design-lore, non un placeholder), si conferma con la voltata o col
## bottone -> nuova_partita(nome, slot scelto). Partita in corso: mostra chi
## sei (nome, Pathway, Sequenza, tier), sola lettura.

var _campo: LineEdit = null


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_campo = null

	var gs: Node = _n("/root/GameState")
	if gs != null and bool(gs.call("partita_in_corso")):
		_mostra_identita(gs)
	else:
		_mostra_creazione(gs)


func _mostra_creazione(gs: Node) -> void:
	add_child(_riga(tr("BOOK_FRONTESPIZIO_INVITO")))
	_campo = LineEdit.new()
	_campo.text = str(gs.call("nome_default")) if gs != null else "Enel"
	_campo.custom_minimum_size = Vector2(220, 24)
	_campo.select_all()
	add_child(_campo)
	var ok := Button.new()
	ok.text = tr("BOOK_FRONTESPIZIO_CONFERMA")
	ok.pressed.connect(conferma)
	add_child(ok)


func _mostra_identita(gs: Node) -> void:
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	add_child(_riga(str(gs.call("get", "nome_personaggio"))))
	if prog != null:
		var pid: String = str(prog.call("pathway"))
		var pw: Dictionary = gd.call("get_pathway", pid) if gd != null else {}
		var nome_pw: String = str(gd.call("tr_data", pw.get("name_i18n", pid))) if gd != null else pid
		add_child(_riga("%s  ·  %s %d  ·  %s" % [
			nome_pw, tr("BOOK_FRONTESPIZIO_SEQUENZA"), int(prog.call("sequence")),
			str(prog.call("tier")),
		]))


## Conferma la creazione. Chiamata dal bottone e dalla voltata in avanti.
func conferma() -> void:
	var gs: Node = _n("/root/GameState")
	var book: Node = _n("/root/Book")
	if gs == null or _campo == null:
		return
	gs.call("nuova_partita", _campo.text, int(gs.call("slot_scelto")))
	if book != null:
		book.call("chiudi")


## Il libro chiede se questa pagina gestisce la voltata in avanti (US-223:
## "si conferma con la prima voltata di pagina").
func intercetta_avanti() -> bool:
	if _campo != null:
		conferma()
		return true
	return false


func testo_visibile() -> String:
	var out: PackedStringArray = []
	for c in get_children():
		if c is Label:
			out.append((c as Label).text)
		elif c is LineEdit:
			out.append((c as LineEdit).text)
	return " / ".join(out)


func _riga(testo: String) -> Label:
	var l := Label.new()
	l.text = testo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _n(path: String) -> Node:
	return get_node_or_null(path)
