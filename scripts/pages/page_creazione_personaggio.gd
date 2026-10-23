extends VBoxContainer
## Frontespizio (US-223). Partita nuova: campo nome con "Enel" gia' scritto
## (design-lore, non un placeholder), si conferma con la voltata o col
## bottone -> nuova_partita(nome, slot scelto). Partita in corso: mostra chi
## sei (nome, Pathway, Sequenza, tier), sola lettura.

var _campo: LineEdit = null
## US-332: id dei talenti innati spuntati alla creazione.
var _scelti: Array = []
var _max_talenti: int = 0
## Modalita' scelta (data/modalita.json): si passa a nuova_partita.
var _modalita: String = ""
var _descr_modalita: Label = null


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_campo = null
	_scelti = []
	_modalita = ""
	_descr_modalita = null

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
	_talenti_innati(gs)
	_scelta_modalita()
	var ok := Button.new()
	ok.text = tr("BOOK_FRONTESPIZIO_CONFERMA")
	ok.pressed.connect(conferma)
	add_child(ok)


## La scelta di 1-2 talenti innati (US-332). Il numero e' un dato
## (balance.json talenti.innati_alla_creazione).
func _talenti_innati(gs: Node) -> void:
	var gd: Node = _n("/root/GameData")
	if gd == null:
		return
	_max_talenti = int((gd.call("get_balance", "talenti") as Dictionary).get("innati_alla_creazione", 0))
	if _max_talenti <= 0:
		return
	add_child(_riga(tr("BOOK_FRONTESPIZIO_TALENTI") % _max_talenti))
	var griglia := GridContainer.new()                # due colonne: la pagina resta dentro il libro
	griglia.columns = 2
	add_child(griglia)
	for tid in gd.call("talents_per_tipo", "innato"):
		var t: Dictionary = gd.call("get_talent", tid)
		var cb := CheckBox.new()
		cb.text = str(gd.call("tr_data", t.get("name_i18n", tid)))
		cb.toggled.connect(func(premuto: bool) -> void:
			_su_talento(cb, str(tid), premuto))
		griglia.add_child(cb)


## Facile / Difficile (decisione 2026-10-20): un bottone per modalita' dei dati,
## a scelta unica, gia' premuto quello di default. Testi: MODALITA_<ID> e
## MODALITA_<ID>_DESCR in strings.csv.
func _scelta_modalita() -> void:
	var gd: Node = _n("/root/GameData")
	if gd == null:
		return
	_modalita = str(gd.call("modalita_default"))
	var riga := HBoxContainer.new()                     # etichetta e bottoni su una riga sola
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	var etichetta := Label.new()
	etichetta.text = tr("BOOK_FRONTESPIZIO_MODALITA")
	riga.add_child(etichetta)
	var gruppo := ButtonGroup.new()
	for mid in gd.call("modalita_ids"):
		var b := Button.new()
		b.name = "Modalita_%s" % mid
		b.text = tr("MODALITA_%s" % str(mid).to_upper())
		b.toggle_mode = true
		b.button_group = gruppo
		b.button_pressed = str(mid) == _modalita
		b.pressed.connect(_su_modalita.bind(str(mid)))
		riga.add_child(b)
	add_child(riga)
	_descr_modalita = _riga(tr("MODALITA_%s_DESCR" % _modalita.to_upper()))
	add_child(_descr_modalita)


func _su_modalita(mid: String) -> void:
	_modalita = mid
	if _descr_modalita != null:
		_descr_modalita.text = tr("MODALITA_%s_DESCR" % mid.to_upper())


func _su_talento(cb: CheckBox, tid: String, premuto: bool) -> void:
	if premuto:
		if _scelti.size() >= _max_talenti:
			cb.set_pressed_no_signal(false)  # oltre il limite: annulla la spunta
			return
		if not _scelti.has(tid):
			_scelti.append(tid)
	else:
		_scelti.erase(tid)


func _mostra_identita(gs: Node) -> void:
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	add_child(_riga(str(gs.call("get", "nome_personaggio"))))
	add_child(_riga("%s: %s" % [tr("BOOK_FRONTESPIZIO_MODALITA_PARTITA"),
		tr("MODALITA_%s" % str(gs.call("get", "modalita")).to_upper())]))
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
		var nomi: Array = []
		for tid in ts.call("posseduti"):
			nomi.append(str(gd.call("tr_data", (gd.call("get_talent", tid) as Dictionary).get("name_i18n", tid))))
		add_child(_riga("%s %s" % [tr("BOOK_FRONTESPIZIO_I_TUOI_TALENTI"),
			", ".join(nomi) if not nomi.is_empty() else tr("BOOK_FRONTESPIZIO_NESSUN_TALENTO")]))


## Conferma la creazione. Chiamata dal bottone e dalla voltata in avanti.
func conferma() -> void:
	var gs: Node = _n("/root/GameState")
	var book: Node = _n("/root/Book")
	if gs == null or _campo == null:
		return
	gs.call("nuova_partita", _campo.text, int(gs.call("slot_scelto")), _scelti, _modalita)
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
