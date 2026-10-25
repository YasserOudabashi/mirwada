extends CanvasLayer
## Rappresentazione visiva del libro (US-222). Il controller e' l'autoload Book;
## questo nodo disegna la doppia pagina, il titolo, lo stato (sbloccata o
## bianca), i segnalibri e l'animazione di voltata.
##
## FR-8: nessuna informazione vive SOLO nell'animazione. Titolo e stato della
## pagina sono sempre testo; la voltata e' decorazione. Con riduci_animazioni
## (data/audio.json.accessibilita) la voltata diventa una dissolvenza di
## dissolvenza_ridotta_ms.
##
## PROCESS_MODE_ALWAYS: il libro vive col mondo in pausa. La voltata e' un
## contatore in _process (come madness_overlay), non un Tween: i Tween si
## fermano con l'albero in pausa.
##
## NIENTE class_name: coerente col progetto.

@onready var _sfondo: ColorRect = $Sfondo
@onready var _pagina: ColorRect = $Pagina
@onready var _titolo: Label = $Pagina/Titolo
@onready var _contenuto: MarginContainer = $Pagina/Contenuto
@onready var _voltata: ColorRect = $Pagina/Voltata
@onready var _macchie: ColorRect = $Pagina/Macchie
@onready var _note: Label = $Pagina/NoteMargine
@onready var _segnalibri: VBoxContainer = $Segnalibri

## Soglie di follia (data/balance.json.madness). Le macchie del libro sono
## l'equivalente scritto del layer audio dei sussurri (US-214 / FR-8).
var _sog_bordi: float = 15.0
var _sog_note: float = 40.0
var _follia: float = 0.0
var _t_macchie: float = 0.0

## Un tipo di pagina, una scena. Le pagine non ancora scritte ricadono su un
## placeholder. design-ui-libro.md: "il codice implementa un tipo di pagina per
## ogni tipo del vocabolario chiuso".
const PAGINE := {
	"menu_principale": preload("res://scenes/pages/page_menu_principale.tscn"),
	"creazione_personaggio": preload("res://scenes/pages/page_creazione_personaggio.tscn"),
	"diagramma_pathway": preload("res://scenes/pages/page_diagramma_pathway.tscn"),
	"impostazioni": preload("res://scenes/pages/page_impostazioni.tscn"),
	"inventario": preload("res://scenes/pages/page_inventario.tscn"),
	"page_dialogo": preload("res://scenes/pages/page_dialogo.tscn"),
	"mappa": preload("res://scenes/pages/page_mappa.tscn"),
}

var _volta_durata: float = 0.35
var _volta_ridotta_s: float = 0.08
var _volta_left: float = 0.0
var _volta_pagina: String = ""
var _volta_ridotta: bool = false
var _swapped: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var b: Node = _book()
	if b != null:
		b.libro_aperto.connect(_apri)
		b.libro_chiuso.connect(_chiudi)
		b.pagina_cambiata.connect(func(nuova: String, _v: String) -> void: _volta(nuova))
		var cfg: Dictionary = b.call("libro_config")
		_volta_durata = maxf(0.05, float(cfg.get("voltata_ms", 350)) / 1000.0)
		_volta_ridotta_s = maxf(0.02, float(cfg.get("dissolvenza_ridotta_ms", 80)) / 1000.0)
	_applica_aspetto()
	_costruisci_segnalibri()

	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		var m: Dictionary = gd.call("get_balance", "madness")
		_sog_bordi = float(m.get("soglia_distorsioni", 15.0))
		_sog_note = float(m.get("soglia_abilita_autonome", 40.0))
	var mad: Node = get_node_or_null("/root/Madness")
	if mad != null and mad.has_signal("madness_changed"):
		mad.madness_changed.connect(func(v: float, _s: int) -> void:
			_follia = v
			_aggiorna_macchie())
		_follia = float(mad.call("valore"))
	_aggiorna_macchie()

	# US-613b: un dialogo che parte apre il libro sulla pagina page_dialogo;
	# quando finisce (o si chiude il libro a mano) il dialogo termina.
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de != null:
		de.dialogo_avviato.connect(func(_id: String) -> void:
			var pid: String = _pagina_di_tipo("page_dialogo")
			if pid.is_empty():
				return
			if b != null and bool(b.call("e_aperto")):
				b.call("vai_a", pid)
			elif b != null:
				b.call("apri_a", pid))
		de.dialogo_finito.connect(func(_id: String) -> void:
			# US-811: una scelta puo' aprire un negozio E finire il dialogo
			# nella stessa mossa (es. dlg_sidon.json n1: apri_vendita + goto
			# null) — non chiudere il libro sotto al negozio appena aperto.
			if b != null and bool(b.call("e_aperto")) \
					and bool(b.call("pagina", b.call("pagina_corrente")).get("transitoria", false)) \
					and not _pagina_in_negozio():
				b.call("chiudi"))
		if b != null:
			b.libro_chiuso.connect(func() -> void:
				if bool(de.call("in_corso")):
					de.call("termina"))


func _pagina_di_tipo(tipo: String) -> String:
	var b: Node = _book()
	if b == null:
		return ""
	for p in b.call("pagine"):
		if str((p as Dictionary).get("tipo", "")) == tipo:
			return str((p as Dictionary).get("id", ""))
	return ""


## true se l'istanza di pagina attualmente montata e' un page_dialogo in
## modalita' negozio (US-811). Non presume quale tipo di pagina sia: si
## limita a chiedere in_negozio() a chi ce l'ha.
func _pagina_in_negozio() -> bool:
	if _contenuto.get_child_count() == 0:
		return false
	var inst: Node = _contenuto.get_child(0)
	return inst.has_method("in_negozio") and bool(inst.call("in_negozio"))


func _book() -> Node:
	return get_node_or_null("/root/Book")


func _apri(pagina: String) -> void:
	visible = true
	_volta_left = 0.0
	_voltata.size.x = 0.0
	_pagina.modulate.a = 1.0
	_volta_pagina = pagina
	_swapped = true
	_rendi(pagina)
	_aggiorna_macchie()
	_audio("sfx_apri")


func _chiudi() -> void:
	visible = false
	_volta_left = 0.0


func _volta(pagina: String) -> void:
	if not visible:
		_rendi(pagina)
		return
	_audio("sfx_volta")
	_volta_pagina = pagina
	_volta_ridotta = _ridotto()
	_volta_left = _volta_ridotta_s if _volta_ridotta else _volta_durata
	_swapped = false


func _process(delta: float) -> void:
	# respiro delle macchie di follia (US-229), solo se attive e non congelate
	if visible and _macchie.material is ShaderMaterial and _macchie_abilitate() \
			and not _macchie_congelate() and _follia >= _sog_bordi:
		_t_macchie += delta
		var base: float = _intensita_macchie()
		var respiro: float = 1.0 + sin(_t_macchie * TAU * 0.15) * 0.18
		(_macchie.material as ShaderMaterial).set_shader_parameter("intensita", clampf(base * respiro, 0.0, 1.0))

	if _volta_left <= 0.0:
		return
	_volta_left = maxf(0.0, _volta_left - delta)
	var durata: float = _volta_ridotta_s if _volta_ridotta else _volta_durata
	var t: float = 1.0 - _volta_left / maxf(0.001, durata)

	if not _swapped and t >= 0.5:
		_rendi(_volta_pagina)
		_swapped = true

	if _volta_ridotta:
		# dissolvenza: la pagina sfuma via e ritorna
		_pagina.modulate.a = absf(t - 0.5) * 2.0
	else:
		# la pagina si solleva: una fascia d'ombra attraversa la piega
		var w: float = _pagina.size.x
		_voltata.position.x = t * w
		_voltata.size.x = clampf(w * 0.14, 6.0, w)
		_pagina.modulate.a = 1.0

	if _volta_left <= 0.0:
		_voltata.size.x = 0.0
		_pagina.modulate.a = 1.0


func _rendi(pagina: String) -> void:
	var b: Node = _book()
	if b == null:
		return
	var p: Dictionary = b.call("pagina", pagina)
	var gd: Node = get_node_or_null("/root/GameData")
	var nome: String = str(p.get("name_i18n", pagina))
	_titolo.text = str(gd.call("tr_data", nome)) if gd != null else nome
	_aggiorna_macchie()

	for c in _contenuto.get_children():
		_contenuto.remove_child(c)   # subito fuori: get_child(0) e' sempre la pagina viva
		c.queue_free()

	if not b.call("pagina_sbloccata", pagina):
		_contenuto.add_child(_riga("· appunto a matita ·\nquesta pagina si aprira' piu' avanti"))
		return

	var scena: PackedScene = PAGINE.get(str(p.get("tipo", "")), null)
	if scena != null:
		var inst: Node = scena.instantiate()
		_contenuto.add_child(inst)
		if inst.has_method("aggiorna"):
			inst.call("aggiorna")
	else:
		# tipo nel vocabolario ma pagina non ancora scritta: placeholder.
		_contenuto.add_child(_riga("[ %s ]" % str(p.get("tipo", ""))))


func _riga(testo: String) -> Label:
	var l := Label.new()
	l.text = testo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# --- Macchie di follia (US-229) --------------------------------------
# I bordi delle pagine si scuriscono, compaiono note a margine in una grafia
# non tua: la forma SCRITTA dei sussurri di US-214 (FR-8, ogni canale audio
# ha l'equivalente visivo). Con disattiva_sussurri / riduci_animazioni / il
# toggle 'macchie di follia' spento, le macchie si CONGELANO a uno stato
# neutro. La follia continua a salire e a fare danno: non cambia la meccanica.

func _aggiorna_macchie() -> void:
	if _macchie == null:
		return
	var abilitate: bool = _macchie_abilitate()
	var congelate: bool = _macchie_congelate()

	var intensita: float = 0.0
	if abilitate and _follia >= _sog_bordi:
		intensita = 0.22 if congelate else _intensita_macchie()   # congelata = neutro fisso
	if _macchie.material is ShaderMaterial:
		(_macchie.material as ShaderMaterial).set_shader_parameter("intensita", intensita)

	# le note a margine sono TESTO: restano leggibili anche congelate (FR-8)
	if abilitate and _follia >= _sog_note:
		_note.text = _nota_margine()
		_note.visible = true
	else:
		_note.visible = false


func _intensita_macchie() -> float:
	var frazione: float = clampf((_follia - _sog_bordi) / maxf(1.0, 100.0 - _sog_bordi), 0.0, 1.0)
	return lerpf(0.25, 0.85, frazione)


func _macchie_abilitate() -> bool:
	# interruttore dei dati (data/ui/book.json) AND opzione del colophon (US-225)
	var b: Node = _book()
	var da_dati: bool = bool(b.call("config", "macchie_follia", true)) if b != null else true
	var ss: Node = get_node_or_null("/root/SettingsStore")
	var da_opzioni: bool = bool(ss.call("get_val", "video", "macchie_follia", true)) if ss != null else true
	return da_dati and da_opzioni


func _macchie_congelate() -> bool:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return false
	return bool(am.call("accessibilita", "disattiva_sussurri")) \
		or bool(am.call("accessibilita", "riduci_animazioni"))


func _nota_margine() -> String:
	var am: Node = get_node_or_null("/root/AudioManager")
	var nomi: Array = am.call("nomi_sussurro") if am != null else []
	var nome: String = str(nomi[randi() % nomi.size()]) if not nomi.is_empty() else "qualcuno"
	var chiave: String = ["BOOK_MACCHIA_1", "BOOK_MACCHIA_2", "BOOK_MACCHIA_3"][int(_follia / 20.0) % 3]
	return tr(chiave).format([nome])


# --- Aspetto del libro (2026-10-25) -------------------------------------
# Carta di cuoio e pergamena, titolo col filetto, segnalibri di stoffa e un Theme
# per tutte le pagine (font Alegreya, inchiostro scuro), dai dati: data/ui/book.json
# "tema" (immagini da tools/art/build_libro.py). Senza "tema" il libro resta piatto.

var _stili_segnalibro: Dictionary = {}


func _applica_aspetto() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var t: Dictionary = (gd.call("get_ui_book") as Dictionary).get("tema", {}) if gd != null else {}
	if t.is_empty():
		return
	var col: Dictionary = t.get("colori", {})
	var inchiostro: Color = _colore(col, "inchiostro", Color(0.24, 0.15, 0.19))
	var titolo: Color = _colore(col, "titolo", Color(0.45, 0.24, 0.22))
	var evidenza: Color = _colore(col, "evidenza", Color(0.64, 0.15, 0.2))
	var tenue: Color = _colore(col, "tenue", Color(0.72, 0.44, 0.31))
	var carta: Color = _colore(col, "carta", Color(0.92, 0.83, 0.67))
	var carta_scura: Color = _colore(col, "carta_scura", Color(0.89, 0.65, 0.45))

	# la carta disegnata al posto del rettangolo piatto; la piega e' nel disegno
	var foglio := TextureRect.new()
	foglio.name = "Carta"
	foglio.texture = _texture_ui(str(t.get("carta", "")))
	foglio.set_anchors_preset(Control.PRESET_FULL_RECT)
	foglio.stretch_mode = TextureRect.STRETCH_SCALE
	foglio.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foglio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pagina.add_child(foglio)
	_pagina.move_child(foglio, 0)
	_pagina.color = Color(0, 0, 0, 0)
	($Pagina/Piega as CanvasItem).visible = false

	var font: Font = _font_ui(str(t.get("font", "")))
	var font_titolo: Font = _font_ui(str(t.get("font_titolo", "")))
	if font_titolo != null:
		_titolo.add_theme_font_override("font", font_titolo)
	_titolo.add_theme_font_size_override("font_size", int(t.get("dimensione_titolo", 17)))
	_titolo.add_theme_color_override("font_color", titolo)
	var orn := TextureRect.new()
	orn.name = "Ornamento"
	orn.texture = _texture_ui(str(t.get("ornamento", "")))
	orn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.anchor_left = 0.5
	orn.anchor_right = 0.5
	if orn.texture != null:
		orn.offset_left = -orn.texture.get_width() / 2.0
		orn.offset_right = orn.texture.get_width() / 2.0
	orn.offset_top = 40.0
	orn.offset_bottom = 47.0
	_pagina.add_child(orn)

	var th := Theme.new()
	if font != null:
		th.default_font = font
	th.default_font_size = int(t.get("dimensione", 12))
	for tipo in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit", "PopupMenu",
			"ItemList", "TabBar", "LinkButton", "MenuButton", "TooltipLabel"]:
		th.set_color("font_color", tipo, inchiostro)
	th.set_color("default_color", "RichTextLabel", inchiostro)
	for tipo in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", tipo, _riquadro(carta_scura, Color(titolo, 0.8)))
		th.set_stylebox("hover", tipo, _riquadro(carta_scura, evidenza))
		th.set_stylebox("pressed", tipo, _riquadro(titolo, titolo))
		th.set_stylebox("disabled", tipo, _riquadro(Color(carta_scura, 0.2), Color(tenue, 0.6)))
		th.set_stylebox("focus", tipo, _riquadro(Color(0, 0, 0, 0), evidenza))
		th.set_color("font_hover_color", tipo, evidenza)
		th.set_color("font_focus_color", tipo, inchiostro)
		th.set_color("font_pressed_color", tipo, carta)
		th.set_color("font_hover_pressed_color", tipo, carta)
		th.set_color("font_disabled_color", tipo, Color(tenue, 0.8))
	var vuoto := StyleBoxEmpty.new()
	for tipo in ["CheckBox", "CheckButton"]:
		th.set_stylebox("normal", tipo, vuoto)
		th.set_stylebox("pressed", tipo, vuoto)
		th.set_stylebox("hover", tipo, _riquadro(Color(carta_scura, 0.35), Color(0, 0, 0, 0)))
		th.set_stylebox("hover_pressed", tipo, _riquadro(Color(carta_scura, 0.35), Color(0, 0, 0, 0)))
		th.set_stylebox("focus", tipo, vuoto)
		th.set_color("font_hover_color", tipo, evidenza)
		th.set_color("font_pressed_color", tipo, inchiostro)
		th.set_color("font_hover_pressed_color", tipo, evidenza)
		th.set_color("font_focus_color", tipo, inchiostro)
		th.set_color("font_disabled_color", tipo, Color(tenue, 0.8))
	var spunta_no: Texture2D = _texture_ui(str(t.get("spunta_no", "")))
	var spunta_si: Texture2D = _texture_ui(str(t.get("spunta_si", "")))
	if spunta_no != null and spunta_si != null:
		th.set_icon("unchecked", "CheckBox", spunta_no)
		th.set_icon("checked", "CheckBox", spunta_si)
		th.set_icon("unchecked_disabled", "CheckBox", spunta_no)
		th.set_icon("checked_disabled", "CheckBox", spunta_si)
		th.set_icon("radio_unchecked", "CheckBox", spunta_no)
		th.set_icon("radio_checked", "CheckBox", spunta_si)
	var campo := _riquadro(carta, titolo)
	campo.border_width_top = 0
	campo.border_width_left = 0
	campo.border_width_right = 0
	th.set_stylebox("normal", "LineEdit", campo)
	var campo_attivo: StyleBoxFlat = campo.duplicate()
	campo_attivo.border_color = evidenza
	th.set_stylebox("focus", "LineEdit", campo_attivo)
	th.set_color("caret_color", "LineEdit", inchiostro)
	th.set_color("selection_color", "LineEdit", Color(evidenza, 0.3))
	th.set_color("font_selected_color", "LineEdit", inchiostro)
	var pista := _riquadro(Color(tenue, 0.45), Color(0, 0, 0, 0))
	pista.content_margin_top = 2
	pista.content_margin_bottom = 2
	th.set_stylebox("slider", "HSlider", pista)
	th.set_stylebox("grabber_area", "HSlider", _riquadro(titolo, titolo))
	th.set_stylebox("grabber_area_highlight", "HSlider", _riquadro(evidenza, evidenza))
	th.set_stylebox("scroll", "VScrollBar", _riquadro(Color(carta_scura, 0.35), Color(0, 0, 0, 0)))
	th.set_stylebox("grabber", "VScrollBar", _riquadro(Color(titolo, 0.7), Color(0, 0, 0, 0)))
	th.set_stylebox("grabber_highlight", "VScrollBar", _riquadro(evidenza, Color(0, 0, 0, 0)))
	th.set_stylebox("grabber_pressed", "VScrollBar", _riquadro(evidenza, Color(0, 0, 0, 0)))
	th.set_stylebox("panel", "PopupMenu", _riquadro(carta, titolo))
	th.set_stylebox("hover", "PopupMenu", _riquadro(titolo, titolo))
	th.set_color("font_hover_color", "PopupMenu", carta)
	th.set_stylebox("panel", "TooltipPanel", _riquadro(carta, titolo))
	_pagina.theme = th
	_segnalibri.theme = th

	# segnalibri: nastri di stoffa che escono dal bordo destro della copertina
	var nastro: Texture2D = _texture_ui(str(t.get("segnalibro", "")))
	var nastro_su: Texture2D = _texture_ui(str(t.get("segnalibro_su", "")))
	if nastro != null:
		var n := StyleBoxTexture.new()
		n.texture = nastro
		var su := StyleBoxTexture.new()
		su.texture = nastro_su if nastro_su != null else nastro
		_stili_segnalibro = {"normal": n, "hover": su, "pressed": su, "hover_pressed": su, "focus": StyleBoxEmpty.new()}
		_segnalibri.offset_left = -23.0
		_segnalibri.offset_right = -11.0


func _riquadro(fondo: Color, bordo: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = bordo
	sb.set_border_width_all(1 if bordo.a > 0.0 else 0)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


func _colore(col: Dictionary, k: String, fallback: Color) -> Color:
	return Color(str(col[k])) if col.has(k) else fallback


## Le immagini dell'interfaccia: dalla risorsa importata, o dal disco (headless senza import).
func _texture_ui(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img != null else null


func _font_ui(path: String) -> Font:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path)
	var f := FontFile.new()
	return f if f.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK else null


func _costruisci_segnalibri() -> void:
	for c in _segnalibri.get_children():
		c.queue_free()
	var b: Node = _book()
	if b == null:
		return
	var gd: Node = get_node_or_null("/root/GameData")
	# Nastri sottili sul bordo: il nome sta nel tooltip, non occupano la pagina.
	for id in b.call("segnalibri"):
		var p: Dictionary = b.call("pagina", id)
		var r := Button.new()
		r.custom_minimum_size = Vector2(12, 34)
		for k in _stili_segnalibro:
			r.add_theme_stylebox_override(k, _stili_segnalibro[k])
		var nome: String = str(p.get("name_i18n", id))
		r.tooltip_text = str(gd.call("tr_data", nome)) if gd != null else str(id)
		r.pressed.connect(func() -> void:
			if _book() != null:
				_book().call("vai_a", id))
		_segnalibri.add_child(r)


func _unhandled_input(event: InputEvent) -> void:
	var b: Node = _book()
	if b == null or not b.call("e_aperto"):
		return
	if event.is_action_pressed("pagina_avanti"):
		# alcune pagine (frontespizio: "conferma con la voltata") intercettano
		# la voltata in avanti
		var pag: Node = _contenuto.get_child(0) if _contenuto.get_child_count() > 0 else null
		if pag != null and pag.has_method("intercetta_avanti") and bool(pag.call("intercetta_avanti")):
			get_viewport().set_input_as_handled()
			return
		b.call("avanti")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pagina_indietro"):
		b.call("indietro")
		get_viewport().set_input_as_handled()


func _audio(chiave_cfg: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	var b: Node = _book()
	if am == null or b == null or not am.has_method("suona_ui"):
		return
	am.call("suona_ui", str(b.call("config", chiave_cfg, "")))


func _ridotto() -> bool:
	var am: Node = get_node_or_null("/root/AudioManager")
	return bool(am.call("accessibilita", "riduci_animazioni")) if am != null else false


# --- Interrogabile dai test ---------------------------------------------

func e_visibile() -> bool:
	return visible


func titolo() -> String:
	return _titolo.text


func corpo() -> String:
	var out: PackedStringArray = []
	for c in _contenuto.get_children():
		if c is Label:
			out.append((c as Label).text)
		elif c.has_method("testo_visibile"):
			out.append(str(c.call("testo_visibile")))
	return "\n".join(out)


func voltata_in_corso() -> bool:
	return _volta_left > 0.0
