extends VBoxContainer
## Pagina inventario del libro (US-307). Cinque sezioni: Zaino, Indosso,
## Ricettario, Talenti, Base. Zaino e Indosso sono scritte; le altre sono
## segnaposto finche' non arrivano le loro story (alchimia, talenti, base).
##
## Chrome da assets/i18n/strings.csv + tr(); nomi degli item da GameData.tr_data.

const SEZIONI := ["zaino", "indosso", "ricettario", "talenti", "base"]

var _tab: HBoxContainer = null
var _corpo: VBoxContainer = null
var _sezione: String = "zaino"


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_tab = HBoxContainer.new()
	_tab.add_theme_constant_override("separation", 4)
	add_child(_tab)
	for s in SEZIONI:
		var b := Button.new()
		b.text = tr("BOOK_INV_" + s.to_upper())
		b.toggle_mode = true
		b.button_pressed = (s == _sezione)
		b.pressed.connect(_mostra.bind(s))
		_tab.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.add_theme_constant_override("separation", 2)
	sc.add_child(_corpo)
	_mostra(_sezione)


func _mostra(sezione: String) -> void:
	_sezione = sezione
	if _tab != null:
		for i in _tab.get_child_count():
			(_tab.get_child(i) as Button).button_pressed = (SEZIONI[i] == sezione)
	for c in _corpo.get_children():
		_corpo.remove_child(c)
		c.queue_free()
	match sezione:
		"zaino": _zaino()
		"indosso": _indosso()
		_: _corpo.add_child(_riga(tr("BOOK_INV_ARRIVA")))


func _zaino() -> void:
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")
	if inv == null or gd == null:
		return
	var vuoto := true
	for cat in gd.call("item_categories"):
		var voci: Array = inv.call("per_categoria", cat)
		if voci.is_empty():
			continue
		vuoto = false
		_corpo.add_child(_titolo(tr("BOOK_CAT_" + str(cat).to_upper())))
		for v in voci:
			_corpo.add_child(_riga_item(v))
	if vuoto:
		_corpo.add_child(_riga(tr("BOOK_INV_VUOTO")))


func _riga_item(v: Dictionary) -> HBoxContainer:
	var gd: Node = _n("/root/GameData")
	var it: Dictionary = gd.call("get_item", str(v.get("item_id", "")))
	var h := HBoxContainer.new()
	var l := Label.new()
	var nome: String = str(gd.call("tr_data", it.get("name_i18n", v.get("item_id"))))
	var q: int = int(v.get("quantita", 1))
	l.text = nome + ("  x%d" % q if q > 1 else "")
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var cat: String = str(it.get("categoria", ""))
	var iid: String = str(v.get("instance_id", ""))
	if cat == "equip" and not iid.is_empty():
		h.add_child(_azione(tr("BOOK_INV_EQUIPAGGIA"), func() -> void:
			_n("/root/Equipment").call("equipaggia", iid); _mostra("zaino")))
	elif cat == "pergamena" and not iid.is_empty():
		h.add_child(_azione(tr("BOOK_INV_USA"), func() -> void:
			_n("/root/Inventory").call("usa", iid); _mostra("zaino")))
	return h


func _indosso() -> void:
	var eq: Node = _n("/root/Equipment")
	var gd: Node = _n("/root/GameData")
	if eq == null or gd == null:
		return
	for mount in gd.call("equip_slots"):
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = tr("BOOK_SLOT_" + str(mount).to_upper())
		l.custom_minimum_size = Vector2(120, 0)
		h.add_child(l)
		var it: Dictionary = eq.call("equipaggiato", mount)
		var n := Label.new()
		n.text = str(gd.call("tr_data", it.get("name_i18n", ""))) if not it.is_empty() else tr("BOOK_INV_VUOTO")
		n.custom_minimum_size = Vector2(200, 0)
		h.add_child(n)
		if not it.is_empty():
			h.add_child(_azione(tr("BOOK_INV_TOGLI"), func() -> void:
				eq.call("rimuovi_slot", mount); _mostra("indosso")))
		_corpo.add_child(h)
	_corpo.add_child(_riga(tr("BOOK_INV_SIGILLI_TODO")))


func testo_visibile() -> String:
	return "inventario"


# --- Costruttori -----------------------------------------------------

func _azione(testo: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.pressed.connect(cb)
	return b


func _titolo(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 11)
	return l


func _riga(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _n(path: String) -> Node:
	return get_node_or_null(path)
