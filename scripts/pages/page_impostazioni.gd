extends ScrollContainer
## Colophon del libro (US-225): audio, video, input, lingua. Ogni controllo
## scrive in SettingsStore (user://settings.json) e l'effetto e' immediato.
## Nessun testo hardcoded: tutto da tr() (assets/i18n/strings.csv), come l'HUD.
##
## US-718 (fase 7, Blocco D): se un finale e' stato raggiunto, il colophon
## si estende invece di diventare un tipo di pagina nuovo (page_types.json e'
## un vocabolario chiuso, "va discusso" - estendere una pagina esistente non
## lo tocca). La sezione finale appare per prima, sopra tutto il resto.

const BUS := ["master", "music", "sfx", "ambience", "ui", "whisper"]
const ACC_AUDIO := ["sottotitoli_effetti", "indicatore_visivo_tell",
	"indicatore_direzione_suono", "disattiva_sussurri"]
const ACC_VIDEO := ["disattiva_shake", "riduci_hitstop", "riduci_distorsione",
	"riduci_flash", "riduci_animazioni"]

var _vbox: VBoxContainer = null
var _rimappa_azione: String = ""
var _rimappa_btn: Button = null


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 3)
	add_child(_vbox)

	_sezione_finale()

	_titolo("COLOPHON_AUDIO")
	for b in BUS:
		_slider("COLOPHON_BUS_%s" % b.to_upper(), "audio", "volume_" + b, _bus_db(b), -40.0, 6.0)
	for k in ACC_AUDIO:
		_toggle("COLOPHON_%s" % k.to_upper(), "audio", k, _acc_def(k))

	_titolo("COLOPHON_VIDEO")
	_scala()
	_toggle("COLOPHON_FULLSCREEN", "video", "fullscreen", false)
	for k in ACC_VIDEO:
		_toggle("COLOPHON_%s" % k.to_upper(), "video", k, _acc_def(k))
	_toggle("COLOPHON_MACCHIE_FOLLIA", "video", "macchie_follia", _macchie_def())

	_titolo("COLOPHON_INPUT")
	var schema := Label.new()
	schema.text = tr("COLOPHON_SCHEMA_COMANDI")
	schema.autowrap_mode = TextServer.AUTOWRAP_WORD
	schema.custom_minimum_size = Vector2(360, 0)
	_vbox.add_child(schema)
	for azione in _ss().call("azioni"):
		_rebind(azione)

	_titolo("COLOPHON_LINGUA")
	_lingua()


# --- Finale (US-718) -------------------------------------------------

## Nulla se nessun finale e' stato raggiunto (il caso normale). Altrimenti:
## nome del finale, epilogo della variante di gruppo, e un riassunto di cosa
## passa al personaggio successivo (endgame.eredita, compilato da US-719 -
## finche' non c'e' quella story il contratto e' vuoto e si vede solo il
## titolo/epilogo, mai un placeholder finto).
func _sezione_finale() -> void:
	var eg: Node = _n("/root/EndgameState")
	var gd: Node = _n("/root/GameData")
	if eg == null or gd == null:
		return
	var finale_id: String = str(eg.get("finale"))
	if finale_id.is_empty():
		return
	var ending: Dictionary = gd.call("get_ending", finale_id)
	if ending.is_empty():
		return

	var titolo := Label.new()
	titolo.text = str(gd.call("tr_data", ending.get("name_i18n", finale_id)))
	titolo.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(titolo)

	var epilogo := Label.new()
	epilogo.text = str(gd.call("tr_data", _chiave_epilogo(gd, ending)))
	epilogo.autowrap_mode = TextServer.AUTOWRAP_WORD
	epilogo.custom_minimum_size = Vector2(360, 0)
	_vbox.add_child(epilogo)

	_riepilogo_eredita(eg, gd, ending)
	_vbox.add_child(HSeparator.new())


func _chiave_epilogo(gd: Node, ending: Dictionary) -> String:
	var prog: Node = _n("/root/Progression")
	var pid: String = str(prog.call("pathway")) if prog != null else ""
	var pw: Dictionary = gd.call("get_pathway", pid)
	var gruppo: String = str(pw.get("group", ""))
	var epg: Dictionary = ending.get("epiloghi_per_gruppo", {})
	return str(epg.get("%s_i18n" % gruppo, ""))


func _riepilogo_eredita(eg: Node, gd: Node, ending: Dictionary) -> void:
	var eredita: Dictionary = eg.get("eredita")
	var profilo: String = str(ending.get("eredita_profilo", ""))
	var righe: Array = []
	if (eredita.get("conoscenza", []) as Array).size() > 0:
		righe.append(tr("COLOPHON_FINALE_EREDITA_CONOSCENZA") % (eredita["conoscenza"] as Array).size())
	if eredita.has("ancora") and not (eredita["ancora"] as Dictionary).is_empty():
		var a: Dictionary = eredita["ancora"]
		var ad: Dictionary = gd.call("get_anchor", str(a.get("id", "")))
		righe.append(tr("COLOPHON_FINALE_EREDITA_ANCORA") %
			str(gd.call("tr_data", ad.get("name_i18n", a.get("id", "")))))
	if (eredita.get("reputazione", {}) as Dictionary).size() > 0:
		righe.append(tr("COLOPHON_FINALE_EREDITA_REPUTAZIONE") % (eredita["reputazione"] as Dictionary).size())
	if not str(eredita.get("oggetto", "")).is_empty():
		var it: Dictionary = gd.call("get_item", str(eredita["oggetto"]))
		righe.append(tr("COLOPHON_FINALE_EREDITA_OGGETTO") %
			str(gd.call("tr_data", it.get("name_i18n", eredita["oggetto"]))))

	# US-719: Ancora/oggetto sono una SCELTA del giocatore, non compilati in
	# automatico (potrebbero essercene piu' di uno). Il profilo del finale
	# dice quali servono; il controllo appare finche' non e' stata fatta.
	var serve_ancora: bool = profilo in ["ancore", "completo"] and not eredita.has("ancora")
	var serve_oggetto: bool = profilo == "completo" and not eredita.has("oggetto")

	if righe.is_empty() and not serve_ancora and not serve_oggetto:
		return
	_titolo("COLOPHON_FINALE_EREDITA_TITOLO")
	for r in righe:
		var l := Label.new()
		l.text = "· " + str(r)
		_vbox.add_child(l)
	if serve_ancora:
		_scelta_ancora()
	if serve_oggetto:
		_scelta_oggetto()


## Un'Ancora attiva scelta per l'eredita' (US-719). Nulla se non ce n'e'
## nessuna attiva adesso (niente da scegliere: il riepilogo mostrera' solo
## le altre voci).
func _scelta_ancora() -> void:
	var anc: Node = _n("/root/AnchorSystem")
	var gd: Node = _n("/root/GameData")
	if anc == null or gd == null:
		return
	var attive: Array = anc.call("active")
	if attive.is_empty():
		return
	var h := HBoxContainer.new()
	var o := OptionButton.new()
	for id in attive:
		var ad: Dictionary = gd.call("get_anchor", str(id))
		o.add_item(str(gd.call("tr_data", ad.get("name_i18n", id))))
	var b := Button.new()
	b.text = tr("COLOPHON_FINALE_SCEGLI_ANCORA")
	b.pressed.connect(func() -> void:
		var es: Node = _n("/root/EndingSystem")
		if es != null:
			es.call("scegli_ancora", str(attive[o.get_selected()]))
		aggiorna())
	h.add_child(o)
	h.add_child(b)
	_vbox.add_child(h)


## Un item impilabile dallo zaino scelto per l'eredita' (US-719). Nulla se lo
## zaino non ha item impilabili adesso.
func _scelta_oggetto() -> void:
	var inv: Node = _n("/root/Inventory")
	var gd: Node = _n("/root/GameData")
	if inv == null or gd == null:
		return
	var ids: Array = (inv.call("tutto") as Dictionary).get("stack", {}).keys()
	if ids.is_empty():
		return
	var h := HBoxContainer.new()
	var o := OptionButton.new()
	for id in ids:
		var it: Dictionary = gd.call("get_item", str(id))
		o.add_item(str(gd.call("tr_data", it.get("name_i18n", id))))
	var b := Button.new()
	b.text = tr("COLOPHON_FINALE_SCEGLI_OGGETTO")
	b.pressed.connect(func() -> void:
		var es: Node = _n("/root/EndingSystem")
		if es != null:
			es.call("scegli_oggetto", str(ids[o.get_selected()]))
		aggiorna())
	h.add_child(o)
	h.add_child(b)
	_vbox.add_child(h)


# --- Costruttori di riga --------------------------------------------

func _titolo(chiave: String) -> void:
	var l := Label.new()
	l.text = tr(chiave)
	l.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(l)


func _toggle(chiave: String, sez: String, opt: String, default: bool) -> void:
	var cb := CheckButton.new()
	cb.text = tr(chiave)
	cb.button_pressed = bool(_ss().call("get_val", sez, opt, default))
	cb.toggled.connect(func(v: bool) -> void: _ss().call("set_val", sez, opt, v))
	_vbox.add_child(cb)


func _slider(chiave: String, sez: String, opt: String, default: float, lo: float, hi: float) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = tr(chiave)
	l.custom_minimum_size = Vector2(160, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0
	s.value = float(_ss().call("get_val", sez, opt, default))
	s.custom_minimum_size = Vector2(180, 0)
	s.value_changed.connect(func(v: float) -> void: _ss().call("set_val", sez, opt, v))
	h.add_child(l)
	h.add_child(s)
	_vbox.add_child(h)


func _scala() -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = tr("COLOPHON_SCALA")
	l.custom_minimum_size = Vector2(160, 0)
	var o := OptionButton.new()
	for n in [1, 2, 3]:
		o.add_item("x%d" % n, n)
	o.select(o.get_item_index(int(_ss().call("get_val", "video", "scala_finestra", 2))))
	o.item_selected.connect(func(i: int) -> void:
		_ss().call("set_val", "video", "scala_finestra", o.get_item_id(i)))
	h.add_child(l)
	h.add_child(o)
	_vbox.add_child(h)


func _lingua() -> void:
	var o := OptionButton.new()
	o.add_item("Italiano", 0)
	o.add_item("English", 1)
	var cur: String = str(_ss().call("get_val", "lingua", "locale", TranslationServer.get_locale()))
	o.select(1 if cur.begins_with("en") else 0)
	o.item_selected.connect(func(i: int) -> void:
		_ss().call("set_val", "lingua", "locale", "en" if i == 1 else "it")
		aggiorna())
	_vbox.add_child(o)


func _rebind(azione: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = azione
	l.custom_minimum_size = Vector2(160, 0)
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 0)
	b.text = _tasto_di(azione)
	b.pressed.connect(func() -> void:
		_rimappa_azione = azione
		_rimappa_btn = b
		b.text = tr("COLOPHON_PREMI_TASTO"))
	h.add_child(l)
	h.add_child(b)
	_vbox.add_child(h)


func _input(event: InputEvent) -> void:
	if _rimappa_azione.is_empty() or not (event is InputEventKey) or not event.pressed:
		return
	var kc: int = (event as InputEventKey).physical_keycode
	_ss().call("set_val", "input", _rimappa_azione, kc)
	if _rimappa_btn != null:
		_rimappa_btn.text = _tasto_di(_rimappa_azione)
	_rimappa_azione = ""
	_rimappa_btn = null
	get_viewport().set_input_as_handled()


func testo_visibile() -> String:
	return "impostazioni"


# --- Default dai dati ----------------------------------------------

func _bus_db(bus_nome: String) -> float:
	var gd: Node = _n("/root/GameData")
	var buses: Dictionary = gd.call("get_audio", "buses") if gd != null else {}
	var b: Variant = buses.get(bus_nome, {})
	return float(b.get("volume_db", 0.0)) if typeof(b) == TYPE_DICTIONARY else 0.0


func _acc_def(chiave: String) -> bool:
	var gd: Node = _n("/root/GameData")
	var acc: Dictionary = gd.call("get_audio", "accessibilita") if gd != null else {}
	return bool(acc.get(chiave, false))


func _macchie_def() -> bool:
	var b: Node = _n("/root/Book")
	return bool(b.call("config", "macchie_follia", true)) if b != null else true


func _tasto_di(azione: String) -> String:
	if not InputMap.has_action(azione):
		return "—"
	for ev in InputMap.action_get_events(azione):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "—"


func _ss() -> Node:
	return _n("/root/SettingsStore")


func _n(path: String) -> Node:
	return get_node_or_null(path)
