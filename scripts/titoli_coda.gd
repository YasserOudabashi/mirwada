extends CanvasLayer
## Titoli di coda (2026-11-17): dopo il finale, su fondo nero, scorrono il nome del finale e il suo epilogo, il
## viaggio del giocatore (Pathway, Ancore rimaste, le scelte fatte) e i crediti. Esc (o interagisci) va avanti;
## alla fine emette "finiti" e si toglie. Tutto dai dati: data/ui/titoli.json, data/endings.json, data/audio_fonti.json.
## Nessun nome di Pathway, NPC o flag nel codice: le scelte sono la lista "scelte" dei dati ({flag, testo_i18n}).
##
## NIENTE class_name: coerente col progetto.

signal finiti

var finale_id: String = ""
var _cfg: Dictionary = {}
var _colonna := VBoxContainer.new()
var _fondo := ColorRect.new()
var _tempo: float = 0.0
var _finendo: bool = false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS               # il libro e il finale fermano il mondo, i titoli no
	var gd: Node = get_node_or_null("/root/GameData")
	_cfg = gd.call("get_ui_titoli") if gd != null else {}
	_fondo.color = Color(str(_cfg.get("fondo", "#181425")))
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.modulate.a = 0.0
	add_child(_fondo)
	_colonna.alignment = BoxContainer.ALIGNMENT_CENTER
	_colonna.add_theme_constant_override("separation", 6)
	var vista: Vector2 = get_viewport().get_visible_rect().size
	_colonna.custom_minimum_size = Vector2(vista.x * 0.6, 0)
	_colonna.position = Vector2(vista.x * 0.2, vista.y)
	_fondo.add_child(_colonna)
	_scrivi(gd)
	create_tween().tween_property(_fondo, "modulate:a", 1.0, float(_cfg.get("dissolvenza_s", 1.2)))


func _scrivi(gd: Node) -> void:
	if gd == null:
		return
	var ending: Dictionary = gd.call("get_ending", finale_id)
	_riga(gd.call("tr_data", ending.get("name_i18n", finale_id)), "titolo")
	var prog: Node = get_node_or_null("/root/Progression")
	var pw: Dictionary = gd.call("get_pathway", str(prog.call("pathway"))) if prog != null else {}
	var epg: Dictionary = ending.get("epiloghi_per_gruppo", {})
	var ep: String = str(epg.get("%s_i18n" % str(pw.get("group", "")), ""))
	if not ep.is_empty():
		_riga(gd.call("tr_data", ep), "testo")
	_spazio(30)
	_riga(_testo(gd, "viaggio"), "sezione")
	_riga("%s: %s" % [_testo(gd, "pathway"), gd.call("tr_data", pw.get("name_i18n", ""))], "testo")
	var anc: Node = get_node_or_null("/root/AnchorSystem")
	var nomi: Array = []
	for a in (anc.call("active") as Array if anc != null else []):
		nomi.append(str(gd.call("tr_data", (gd.call("get_anchor", str(a)) as Dictionary).get("name_i18n", a))))
	_riga("%s: %s" % [_testo(gd, "ancore_rimaste"), ", ".join(nomi)] if not nomi.is_empty()
		else str(_testo(gd, "nessuna_ancora")), "testo")
	var ks: Node = get_node_or_null("/root/KnowledgeStore")
	for s in _cfg.get("scelte", []):
		if ks != null and bool(ks.call("conosce", str((s as Dictionary).get("flag", "")))):
			_riga(gd.call("tr_data", str((s as Dictionary).get("testo_i18n", ""))), "tenue")
	_spazio(40)
	_riga(_testo(gd, "mirwada"), "titolo")
	_riga(_testo(gd, "crediti"), "sezione")
	for c in _cfg.get("crediti", []):
		_spazio(6)
		_riga(gd.call("tr_data", str((c as Dictionary).get("ruolo_i18n", ""))), "tenue")
		var chi: Array = (c as Dictionary).get("nomi", [])
		if bool((c as Dictionary).get("dai_suoni", false)):
			chi = _autori_dei_suoni()
		for n in chi:
			_riga(str(n), "testo")
	_spazio(60)
	_riga(_testo(gd, "grazie"), "sezione")


func _testo(gd: Node, chiave: String) -> String:
	return str(gd.call("tr_data", str((_cfg.get("testi", {}) as Dictionary).get(chiave + "_i18n", chiave))))


## Gli autori dei suoni scaricati (data/audio_fonti.json), una volta ciascuno.
func _autori_dei_suoni() -> Array:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_fonti.json"))
	var out: Array = []
	if doc is Dictionary:
		for v in ((doc as Dictionary).get("suoni", {}) as Dictionary).values():
			if v is Dictionary and str((v as Dictionary).get("stato", "")) == "scaricato":
				var a: String = str((v as Dictionary).get("autore", ""))
				if not a.is_empty() and not out.has(a):
					out.append(a)
	out.sort()
	return out


func _riga(testo: Variant, stile: String) -> void:
	var l := Label.new()
	l.text = str(testo)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = _colonna.custom_minimum_size.x
	var colori: Dictionary = _cfg.get("colori", {})
	var corpi: Dictionary = _cfg.get("corpo", {})
	var titolo: bool = stile in ["titolo", "sezione"]
	l.add_theme_font_override("font", load("res://assets/ui/font/AlegreyaSC-Bold.ttf" if titolo else "res://assets/ui/font/Alegreya.ttf"))
	l.add_theme_font_size_override("font_size", int(corpi.get("titolo" if stile == "titolo" else ("sezione" if stile == "sezione" else "testo"), 10)))
	var colore: String = str(colori.get("titolo", "#feae34")) if stile == "titolo" else \
		(str(colori.get("tenue", "#8b9bb4")) if stile == "tenue" else str(colori.get("testo", "#ead4aa")))
	l.add_theme_color_override("font_color", Color(colore))
	l.name = "Riga%d" % _colonna.get_child_count()
	_colonna.add_child(l)


func _spazio(alto: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = alto
	_colonna.add_child(c)


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo < float(_cfg.get("pausa_iniziale_s", 1.5)) or _finendo:
		return
	_colonna.position.y -= float(_cfg.get("velocita", 18)) * delta
	if _colonna.position.y + _colonna.size.y < 0.0:
		finisci()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interagisci"):
		get_viewport().set_input_as_handled()
		finisci()


## Fine dei titoli (scorsi tutti o saltati): il fondo sfuma e si torna al libro.
func finisci() -> void:
	if _finendo:
		return
	_finendo = true
	var t := create_tween()
	t.tween_property(_fondo, "modulate:a", 0.0, float(_cfg.get("dissolvenza_s", 1.2)) * 0.5)
	t.tween_callback(func() -> void:
		finiti.emit()
		queue_free())
