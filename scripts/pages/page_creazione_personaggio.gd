extends VBoxContainer
## Frontespizio (US-223). Partita nuova: campo nome con "Enel" gia' scritto
## (design-lore, non un placeholder), sotto una scelta di talenti innati
## (US-332, il numero e' balance.json.talenti.innati_da_scegliere), si
## conferma con la voltata o col bottone -> nuova_partita(nome, slot scelto,
## talenti scelti). Partita in corso: mostra chi sei (nome, Pathway,
## Sequenza, tier, talenti posseduti), sola lettura.

var _campo: LineEdit = null
## id talento -> CheckBox, solo per la creazione.
var _check_talenti: Dictionary = {}


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_campo = null
	_check_talenti.clear()

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

	add_child(_riga(tr("BOOK_FRONTESPIZIO_TALENTI_INVITO") % _numero_da_scegliere()))
	var gd: Node = _n("/root/GameData")
	if gd != null:
		for t in gd.call("talents_per_tipo", "innato"):
			var d: Dictionary = t
			var tid: String = str(d.get("id", ""))
			var cb := CheckBox.new()
			cb.text = str(gd.call("tr_data", d.get("name_i18n", tid)))
			cb.toggled.connect(_su_talento_toggle.bind(tid))
			add_child(cb)
			_check_talenti[tid] = cb

	var ok := Button.new()
	ok.text = tr("BOOK_FRONTESPIZIO_CONFERMA")
	ok.pressed.connect(conferma)
	add_child(ok)


## Al massimo balance.json.talenti.innati_da_scegliere selezionati: oltre
## quel numero, il tocco piu' recente si annulla da solo.
func _su_talento_toggle(premuto: bool, tid: String) -> void:
	if not premuto:
		return
	if _talenti_selezionati().size() > _numero_da_scegliere():
		(_check_talenti[tid] as CheckBox).button_pressed = false


func _talenti_selezionati() -> Array:
	var out: Array = []
	for tid in _check_talenti:
		if (_check_talenti[tid] as CheckBox).button_pressed:
			out.append(tid)
	return out


func _numero_da_scegliere() -> int:
	var gd: Node = _n("/root/GameData")
	var b: Dictionary = gd.call("get_balance", "talenti") if gd != null else {}
	return int(b.get("innati_da_scegliere", 2))


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
	var ts: Node = _n("/root/TalentSystem")
	if ts != null and gd != null:
		var nomi: PackedStringArray = []
		for tid in ts.call("posseduti"):
			nomi.append(str(gd.call("tr_data", gd.call("get_talent", tid).get("name_i18n", tid))))
		if not nomi.is_empty():
			add_child(_riga("%s: %s" % [tr("BOOK_FRONTESPIZIO_TALENTI"), ", ".join(nomi)]))


## Conferma la creazione. Chiamata dal bottone e dalla voltata in avanti.
func conferma() -> void:
	var gs: Node = _n("/root/GameState")
	var book: Node = _n("/root/Book")
	if gs == null or _campo == null:
		return
	gs.call("nuova_partita", _campo.text, int(gs.call("slot_scelto")), _talenti_selezionati())
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
		elif c is CheckBox:
			out.append((c as CheckBox).text)
	return " / ".join(out)


func _riga(testo: String) -> Label:
	var l := Label.new()
	l.text = testo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _n(path: String) -> Node:
	return get_node_or_null(path)
