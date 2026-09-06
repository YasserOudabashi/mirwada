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
		"ricettario": _ricettario()
		"base": _base()
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


func _ricettario() -> void:
	var gd: Node = _n("/root/GameData")
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	if gd == null or ps == null:
		return
	var ordine := {"base": 0, "avanzata": 1, "leggendaria": 2}
	var ids: Array = gd.call("recipe_ids")
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ta: int = int(ordine.get(gd.call("get_recipe", a).get("tier"), 9))
		var tb: int = int(ordine.get(gd.call("get_recipe", b).get("tier"), 9))
		return ta < tb if ta != tb else a < b)

	for rid in ids:
		var r: Dictionary = gd.call("get_recipe", rid)
		var ingr: Dictionary = r.get("ingredienti", {})
		var h := HBoxContainer.new()
		if bool(ps.call("ricetta_nota", rid)):
			var l := Label.new()
			l.text = "%s  (%s)" % [str(gd.call("tr_data", r.get("name_i18n", rid))), str(r.get("tier"))]
			l.custom_minimum_size = Vector2(300, 0)
			h.add_child(l)
			var ha_tutto := true
			for ing in ingr:
				if inv == null or inv.call("conta", ing) < int(ingr[ing]):
					ha_tutto = false
			var b := Button.new()
			b.text = tr("BOOK_RIC_PREPARA")
			b.disabled = not ha_tutto
			b.pressed.connect(func() -> void:
				_n("/root/PotionSystem").call("prepara", rid); _mostra("ricettario"))
			h.add_child(b)
		else:
			# offuscata: sai che esiste e quanti ingredienti, non quale
			var l := Label.new()
			l.text = tr("BOOK_RIC_SCONOSCIUTA") % ingr.size()
			l.modulate = Color(1, 1, 1, 0.55)
			h.add_child(l)
		_corpo.add_child(h)


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


func _base() -> void:
	var gd: Node = _n("/root/GameData")
	var bs: Node = _n("/root/BaseSystem")
	var inv: Node = _n("/root/Inventory")
	if gd == null or bs == null:
		return
	for tipo in gd.call("room_type_ids"):
		var rt: Dictionary = gd.call("get_room_type", tipo)
		var lv: int = int(bs.call("livello", tipo))
		_corpo.add_child(_titolo(str(gd.call("tr_data", rt.get("name_i18n", tipo)))))
		_corpo.add_child(_riga(tr("BOOK_BASE_NON_COSTRUITA") if lv == 0 else tr("BOOK_BASE_LIVELLO") % lv))
		var bonus: Dictionary = bs.call("bonus", tipo)
		if not bonus.is_empty():
			_corpo.add_child(_riga("%s %s" % [tr("BOOK_BASE_BONUS"), _riassunto(bonus)]))
		var costo: Dictionary = bs.call("costo_prossimo", tipo)
		if costo.is_empty():
			_corpo.add_child(_riga(tr("BOOK_BASE_MAX")))
			continue
		_corpo.add_child(_riga("%s %s" % [tr("BOOK_BASE_COSTO"), _riassunto_costo(costo)]))
		var riga := HBoxContainer.new()
		var b := Button.new()
		b.text = tr("BOOK_BASE_COSTRUISCI") if lv == 0 else tr("BOOK_BASE_POTENZIA")
		b.disabled = not _coperto(inv, costo)
		var azione: String = "costruisci" if lv == 0 else "potenzia"
		b.pressed.connect(func() -> void:
			_n("/root/BaseSystem").call(azione, tipo); _mostra("base"))
		riga.add_child(b)
		_corpo.add_child(riga)
	_giardino(bs)


func _giardino(bs: Node) -> void:
	if int(bs.call("numero_appezzamenti")) <= 0:
		return
	_corpo.add_child(_titolo(tr("BOOK_BASE_GIARDINO_TITOLO")))
	var gd: Node = _n("/root/GameData")
	var stato: Array = bs.call("appezzamenti")
	for i in stato.size():
		var a: Dictionary = stato[i]
		var h := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(220, 0)
		if str(a.get("item_id", "")).is_empty():
			l.text = tr("BOOK_BASE_APPEZZAMENTO_VUOTO")
		elif bool(a.get("pronto", false)):
			var nome: String = str(gd.call("tr_data", (gd.call("get_item", a["item_id"]) as Dictionary).get("name_i18n", a["item_id"])))
			l.text = "%s — %s" % [nome, tr("BOOK_BASE_PRONTO")]
		else:
			l.text = tr("BOOK_BASE_IN_CRESCITA") % int(ceil(float(a.get("crescita", 0.0))))
		h.add_child(l)
		if bool(a.get("pronto", false)):
			var idx: int = i
			h.add_child(_azione(tr("BOOK_BASE_RACCOGLI"), func() -> void:
				_n("/root/BaseSystem").call("raccogli", idx); _mostra("base")))
		_corpo.add_child(h)


func _coperto(inv: Node, costo: Dictionary) -> bool:
	if inv == null:
		return false
	for item_id in costo:
		if int(inv.call("conta", item_id)) < int(costo[item_id]):
			return false
	return true


func _riassunto(d: Dictionary) -> String:
	var parti: Array = []
	for k in d:
		parti.append("%s %s" % [k, d[k]])
	return ", ".join(parti)


func _riassunto_costo(costo: Dictionary) -> String:
	var gd: Node = _n("/root/GameData")
	var parti: Array = []
	for item_id in costo:
		var nome: String = str(gd.call("tr_data", (gd.call("get_item", item_id) as Dictionary).get("name_i18n", item_id)))
		parti.append("%s x%d" % [nome, int(costo[item_id])])
	return ", ".join(parti)


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
