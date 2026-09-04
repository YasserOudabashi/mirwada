extends VBoxContainer
## Pagina inventario del libro (US-307). Cinque sezioni: Zaino, Indosso,
## Ricettario (US-314), Talenti (US-333), Base (US-329).
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
		"talenti": _talenti()
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


## US-333: talenti posseduti (innati + acquisiti sbloccati) con l'effetto in
## chiaro, poi gli acquisiti non ancora presi come righe con una barra di
## progresso (conteggio/target di TalentSystem.progresso()). Un acquisito di
## cui non si e' ancora visto nessun progresso (conteggio 0) e' offuscato,
## come le ricette sconosciute in _ricettario().
func _talenti() -> void:
	var gd: Node = _n("/root/GameData")
	var ts: Node = _n("/root/TalentSystem")
	if gd == null or ts == null:
		return

	_corpo.add_child(_titolo(tr("BOOK_TAL_POSSEDUTI")))
	var posseduti: Array = ts.call("posseduti")
	if posseduti.is_empty():
		_corpo.add_child(_riga(tr("BOOK_INV_VUOTO")))
	for tid in posseduti:
		var d: Dictionary = gd.call("get_talent", tid)
		var l := Label.new()
		l.text = "%s — %s" % [
			str(gd.call("tr_data", d.get("name_i18n", tid))),
			_testo_effetto_talento(d.get("effetto", {})),
		]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_corpo.add_child(l)

	_corpo.add_child(_titolo(tr("BOOK_TAL_DA_SBLOCCARE")))
	var mostrati := 0
	for t in gd.call("talents_per_tipo", "acquisito"):
		var d: Dictionary = t
		var tid: String = str(d.get("id", ""))
		if bool(ts.call("possiede", tid)):
			continue
		mostrati += 1
		var prog: Dictionary = ts.call("progresso", tid)
		var conteggio: float = float(prog.get("conteggio", 0.0))
		var target: float = float(prog.get("target", 1.0))
		var h := HBoxContainer.new()
		if conteggio <= 0.0:
			var l := Label.new()
			l.text = tr("BOOK_TAL_SCONOSCIUTO")
			l.modulate = Color(1, 1, 1, 0.55)
			h.add_child(l)
		else:
			var l := Label.new()
			l.text = str(gd.call("tr_data", d.get("name_i18n", tid)))
			l.custom_minimum_size = Vector2(220, 0)
			h.add_child(l)
			var bar := ProgressBar.new()
			bar.min_value = 0.0
			bar.max_value = max(target, 1.0)
			bar.value = min(conteggio, target)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(140, 0)
			h.add_child(bar)
			var pl := Label.new()
			pl.text = tr("BOOK_TAL_PROGRESSO") % [int(conteggio), int(target)]
			h.add_child(pl)
		_corpo.add_child(h)
	if mostrati == 0:
		_corpo.add_child(_riga(tr("BOOK_INV_VUOTO")))


## Descrizione minimale, non tradotta parola per parola: mostra la chiave
## dell'effetto cosi' com'e' nei dati, come _testo_bonus() fa gia' per i
## bonus di stanza.
func _testo_effetto_talento(eff: Dictionary) -> String:
	match str(eff.get("tipo", "")):
		"stat_modifier":
			var pct: String = "%%" if bool(eff.get("moltiplicativo", false)) else ""
			return "%s %s%s" % [str(eff.get("stat", "")), str(eff.get("valore", 0)), pct]
		"tag_grant":
			return str(eff.get("tag", ""))
		"sblocco_sistema":
			return "%s +%s" % [str(eff.get("chiave", "")), str(eff.get("valore", 0))]
		_:
			return ""


## US-329: le 4 stanze col livello, il costo del prossimo potenziamento, il
## bonus attuale; costruisci/potenzia se il costo e' coperto. Il giardino ha
## in piu' i suoi appezzamenti (vuoto/in crescita/pronto) col pulsante
## raccogli, e la lista degli ingredienti coltivabili posseduti da piantare.
func _base() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var gd: Node = _n("/root/GameData")
	var inv: Node = _n("/root/Inventory")
	if bs == null or gd == null:
		return
	for tipo in gd.call("room_types"):
		_corpo.add_child(_titolo(tr("BOOK_STANZA_" + str(tipo).to_upper())))
		var liv: int = bs.call("livello", tipo)
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = (tr("BOOK_STANZA_LIVELLO") % liv) if liv > 0 else tr("BOOK_STANZA_NON_COSTRUITA")
		l.custom_minimum_size = Vector2(140, 0)
		h.add_child(l)
		var costo: Dictionary = bs.call("prossimo_costo", tipo)
		if not costo.is_empty():
			var cl := Label.new()
			cl.text = tr("BOOK_STANZA_COSTO") % _testo_costo(costo)
			cl.custom_minimum_size = Vector2(220, 0)
			h.add_child(cl)
			var ha_tutto := true
			for item_id in costo:
				if inv == null or inv.call("conta", item_id) < int(costo[item_id]):
					ha_tutto = false
			var b := Button.new()
			b.text = tr("BOOK_STANZA_COSTRUISCI") if liv == 0 else tr("BOOK_STANZA_POTENZIA")
			b.disabled = not ha_tutto
			b.pressed.connect(func() -> void:
				if liv == 0:
					bs.call("costruisci", tipo)
				else:
					bs.call("potenzia", tipo)
				_mostra("base"))
			h.add_child(b)
		_corpo.add_child(h)
		if liv > 0:
			var bonus: Dictionary = bs.call("bonus", tipo)
			if not bonus.is_empty():
				_corpo.add_child(_riga(tr("BOOK_STANZA_BONUS") % _testo_bonus(bonus)))
		if tipo == "giardino":
			_giardino_dettaglio()


func _giardino_dettaglio() -> void:
	var bs: Node = _n("/root/BaseSystem")
	var gd: Node = _n("/root/GameData")
	var inv: Node = _n("/root/Inventory")
	var liv: int = bs.call("livello", "giardino")
	if liv <= 0:
		return
	var app: Array = bs.call("appezzamenti")
	for i in liv:
		var h := HBoxContainer.new()
		var l := Label.new()
		if i < app.size():
			var a: Dictionary = app[i]
			var nome: String = str(gd.call("tr_data", gd.call("get_item", str(a.get("item_id", ""))).get("name_i18n", "")))
			if bool(a.get("pronto", false)):
				l.text = "%s — %s" % [nome, tr("BOOK_GIARDINO_PRONTO")]
			else:
				l.text = "%s — %s" % [nome, tr("BOOK_GIARDINO_IN_CRESCITA") % int(ceil(float(a.get("tempo_rimasto", 0.0))))]
		else:
			l.text = tr("BOOK_GIARDINO_VUOTO")
		l.custom_minimum_size = Vector2(240, 0)
		h.add_child(l)
		if i < app.size() and bool(app[i].get("pronto", false)):
			h.add_child(_azione(tr("BOOK_GIARDINO_RACCOGLI"), func() -> void:
				bs.call("raccogli", i); _mostra("base")))
		_corpo.add_child(h)
	if app.size() >= liv or inv == null:
		return
	for it in gd.call("items_per_categoria", "ingrediente"):
		var d: Dictionary = it
		if not bool(d.get("coltivabile", false)):
			continue
		var iid: String = str(d.get("id", ""))
		if inv.call("conta", iid) <= 0:
			continue
		var hp := HBoxContainer.new()
		var lp := Label.new()
		lp.text = str(gd.call("tr_data", d.get("name_i18n", iid)))
		lp.custom_minimum_size = Vector2(240, 0)
		hp.add_child(lp)
		hp.add_child(_azione(tr("BOOK_GIARDINO_PIANTA"), func() -> void:
			bs.call("pianta", iid); _mostra("base")))
		_corpo.add_child(hp)


func _testo_costo(costo: Dictionary) -> String:
	var gd: Node = _n("/root/GameData")
	var parti: PackedStringArray = []
	for item_id in costo:
		var nome: String = str(gd.call("tr_data", gd.call("get_item", item_id).get("name_i18n", item_id)))
		parti.append("%s x%d" % [nome, int(costo[item_id])])
	return ", ".join(parti)


func _testo_bonus(bonus: Dictionary) -> String:
	var parti: PackedStringArray = []
	for k in bonus:
		parti.append("%s: %s" % [str(k), str(bonus[k])])
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
