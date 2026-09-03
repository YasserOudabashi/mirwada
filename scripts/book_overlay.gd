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
@onready var _corpo: Label = $Pagina/Corpo
@onready var _voltata: ColorRect = $Pagina/Voltata
@onready var _segnalibri: VBoxContainer = $Segnalibri

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
	if b.call("pagina_sbloccata", pagina):
		# La pagina vera (rendering del contenuto) arriva con la sua story.
		_corpo.text = "[ %s ]" % str(p.get("tipo", ""))
	else:
		_corpo.text = "· appunto a matita ·\nquesta pagina si aprira' piu' avanti"


func _costruisci_segnalibri() -> void:
	for c in _segnalibri.get_children():
		c.queue_free()
	var b: Node = _book()
	if b == null:
		return
	var gd: Node = get_node_or_null("/root/GameData")
	for id in b.call("segnalibri"):
		var p: Dictionary = b.call("pagina", id)
		var r := Button.new()
		r.custom_minimum_size = Vector2(96, 20)
		r.flat = true
		var nome: String = str(p.get("name_i18n", id))
		r.text = str(gd.call("tr_data", nome)) if gd != null else str(id)
		r.pressed.connect(func() -> void:
			if _book() != null:
				_book().call("vai_a", id))
		_segnalibri.add_child(r)


func _unhandled_input(event: InputEvent) -> void:
	var b: Node = _book()
	if b == null or not b.call("e_aperto"):
		return
	if event.is_action_pressed("pagina_avanti"):
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
	return _corpo.text


func voltata_in_corso() -> bool:
	return _volta_left > 0.0
