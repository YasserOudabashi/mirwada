extends Node
## Il libro (US-221, parte 1: controller e dati). Ogni schermata del gioco e'
## una pagina dello stesso libro (design-ui-libro.md). Questo autoload e' l'unico
## controller: le pagine vere (rendering, voltata) arrivano una per story.
##
## Aprire il libro FERMA il mondo (get_tree().paused). Il controller e i suoi
## input restano vivi in pausa (PROCESS_MODE_ALWAYS). Il libro si riapre sempre
## sull'ultima pagina consultata.
##
## Le pagine e la loro configurazione sono un dato (data/ui/book.json). Una
## pagina la cui fase di sblocco non e' ancora raggiunta ESISTE ma e' bianca
## (pagina_sbloccata() == false), mai assente.
##
## NIENTE class_name: coerente col resto del progetto.

signal libro_aperto(pagina: String)
signal libro_chiuso()
signal pagina_cambiata(nuova: String, vecchia: String)

## Se balance.json non e' leggibile, non nascondere pagine: mostra tutto.
const FASE_FALLBACK := 999

var _config: Dictionary = {}
var _pagine: Array = []          # voci di 'pages', ordinate per 'ordine'
var _segnalibri: Array = []
var _aperto: bool = false
var _corrente: String = ""
var _ultima: String = ""         # ultima pagina consultata: il libro riapre qui


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null and gd.has_signal("data_reloaded"):
		gd.data_reloaded.connect(func(_f: int, _e: int) -> void: _carica())
	_carica()


func _carica() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var doc: Dictionary = gd.call("get_ui_book") if gd != null else {}
	_config = doc.get("libro", {}) if typeof(doc.get("libro")) == TYPE_DICTIONARY else {}

	_pagine = []
	for p in doc.get("pages", []):
		if typeof(p) == TYPE_DICTIONARY and not str((p as Dictionary).get("id", "")).is_empty():
			_pagine.append(p)
	_pagine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("ordine", 0)) < int(b.get("ordine", 0)))

	_segnalibri = []
	for s in doc.get("segnalibri", []):
		_segnalibri.append(str(s))

	if _ultima.is_empty() and not _pagine.is_empty():
		_ultima = str(_pagine[0].get("id", ""))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("libro"):
		alterna()
		get_viewport().set_input_as_handled()


# --- API pubblica ----------------------------------------------------------

func apri() -> void:
	if _aperto or _pagine.is_empty():
		return
	_aperto = true
	_corrente = _ultima if not _ultima.is_empty() else str(_pagine[0].get("id", ""))
	get_tree().paused = true
	libro_aperto.emit(_corrente)


## Apre il libro direttamente su una pagina (US-613b: un dialogo che parte
## salta alla pagina dialogo). Pagina inesistente -> apre sull'ultima.
func apri_a(page_id: String) -> void:
	if _aperto or _pagine.is_empty():
		return
	_aperto = true
	_corrente = page_id if not pagina(page_id).is_empty() else _ultima
	if _corrente.is_empty():
		_corrente = str(_pagine[0].get("id", ""))
	get_tree().paused = true
	libro_aperto.emit(_corrente)


func chiudi() -> void:
	if not _aperto:
		return
	_aperto = false
	# Una pagina "transitoria" (il dialogo) non diventa l'ultima consultata:
	# riaprire il libro a mano deve tornare dov'eri.
	if not bool(pagina(_corrente).get("transitoria", false)):
		_ultima = _corrente
	get_tree().paused = false
	libro_chiuso.emit()


func alterna() -> void:
	if _aperto:
		chiudi()
	else:
		apri()


## Cambia pagina mentre il libro e' aperto. Pagina inesistente -> no-op.
func vai_a(page_id: String) -> void:
	if not _aperto or pagina(page_id).is_empty() or page_id == _corrente:
		return
	var vecchia: String = _corrente
	_corrente = page_id
	_ultima = page_id
	pagina_cambiata.emit(page_id, vecchia)


## Pagina successiva / precedente nell'ordine di sfogliatura. Ai bordi si
## ferma (un libro non cicla). No-op a libro chiuso.
func avanti() -> void:
	_scorri(1)


func indietro() -> void:
	_scorri(-1)


func _scorri(passo: int) -> void:
	if not _aperto:
		return
	var i: int = _indice(_corrente) + passo
	if i < 0 or i >= _pagine.size():
		return
	vai_a(str(_pagine[i].get("id", "")))


func _indice(page_id: String) -> int:
	for i in _pagine.size():
		if str(_pagine[i].get("id", "")) == page_id:
			return i
	return 0


## Riporta il libro allo stato iniziale: chiuso, prossima apertura sulla prima
## pagina. Usato al ritorno al menu / nuova partita (e per isolare i test).
func azzera() -> void:
	chiudi()
	_corrente = ""
	_ultima = str(_pagine[0].get("id", "")) if not _pagine.is_empty() else ""


func e_aperto() -> bool:
	return _aperto


func pagina_corrente() -> String:
	return _corrente


## Le voci di 'pages' ordinate. Ogni voce e' il Dictionary grezzo dei dati
## piu' la chiave "sbloccata": bool (comodita' per la UI).
func pagine() -> Array:
	var out: Array = []
	for p in _pagine:
		var v: Dictionary = (p as Dictionary).duplicate()
		v["sbloccata"] = _sbloccata(p)
		out.append(v)
	return out


func pagina(page_id: String) -> Dictionary:
	for p in _pagine:
		if str((p as Dictionary).get("id", "")) == page_id:
			return p
	return {}


## false = la pagina esiste ma e' bianca (fase di sblocco non raggiunta).
func pagina_sbloccata(page_id: String) -> bool:
	var p: Dictionary = pagina(page_id)
	return not p.is_empty() and _sbloccata(p)


func segnalibri() -> Array:
	return _segnalibri.duplicate()


func config(key: String, fallback: Variant = null) -> Variant:
	return _config.get(key, fallback)


func libro_config() -> Dictionary:
	return _config.duplicate()


# --- Interno --------------------------------------------------------------

func _sbloccata(p: Dictionary) -> bool:
	var sb: Variant = p.get("sbloccata_da")
	if typeof(sb) != TYPE_DICTIONARY or not (sb as Dictionary).has("fase"):
		return true
	return _fase_gioco() >= int((sb as Dictionary).get("fase", 0))


func _fase_gioco() -> int:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return FASE_FALLBACK
	var g: Dictionary = gd.call("get_balance", "gioco")
	var f: Variant = g.get("fase")
	return int(f) if (typeof(f) == TYPE_FLOAT or typeof(f) == TYPE_INT) else FASE_FALLBACK
