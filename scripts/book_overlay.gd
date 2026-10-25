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
