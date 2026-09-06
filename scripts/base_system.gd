extends Node
## La base del giocatore (US-326): 4 stanze, ognuna a un livello (0 = non
## costruita). I livelli, i costi e i bonus sono dati (data/base/rooms.json);
## il vocabolario chiuso di tipi e chiavi di bonus e' in
## data/schema/room_types.json.
##
## I sistemi (PotionSystem, Forge, ...) leggono bonus(tipo) per CHIAVE: nessun
## if sul nome di una stanza (US-327).
##
## NIENTE class_name: coerente col resto del progetto.

signal stanza_costruita(tipo: String)
signal stanza_potenziata(tipo: String, livello: int)

## { tipo: livello }. Assente o 0 = non costruita.
var _base: Dictionary = {}


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _inv() -> Node:
	return get_node_or_null("/root/Inventory")


# --- Lettura ---------------------------------------------------------

func livello(tipo: String) -> int:
	return int(_base.get(tipo, 0))


## Il bonus COMPLETO al livello attuale ({} se non costruita).
func bonus(tipo: String) -> Dictionary:
	var lv: int = livello(tipo)
	if lv <= 0:
		return {}
	var livelli: Array = _livelli(tipo)
	if lv > livelli.size():
		return {}
	return (livelli[lv - 1].get("bonus", {}) as Dictionary).duplicate(true)


## Il costo del prossimo passo ({} se gia' al massimo o tipo ignoto).
func costo_prossimo(tipo: String) -> Dictionary:
	var livelli: Array = _livelli(tipo)
	var lv: int = livello(tipo)
	if lv >= livelli.size():
		return {}
	return (livelli[lv].get("costo", {}) as Dictionary).duplicate(true)


func stanze() -> Dictionary:
	return _base.duplicate(true)


# --- Mutazione ------------------------------------------------------

## Costruisce la stanza (porta al livello 1). false se gia' costruita, tipo
## ignoto, o costo non coperto. Il costo si consuma dall'inventario.
func costruisci(tipo: String) -> bool:
	if livello(tipo) > 0:
		return false
	if _livelli(tipo).is_empty():
		push_error("[BaseSystem] tipo di stanza sconosciuto: '%s'" % tipo)
		return false
	if not _paga(costo_prossimo(tipo)):
		return false
	_base[tipo] = 1
	stanza_costruita.emit(tipo)
	return true


## Potenzia la stanza di un livello. false se non costruita, gia' al massimo,
## o costo non coperto.
func potenzia(tipo: String) -> bool:
	var lv: int = livello(tipo)
	if lv <= 0:
		return false
	var livelli: Array = _livelli(tipo)
	if lv >= livelli.size():
		return false
	if not _paga(costo_prossimo(tipo)):
		return false
	_base[tipo] = lv + 1
	stanza_potenziata.emit(tipo, lv + 1)
	return true


func pulisci() -> void:
	_base.clear()


# --- Salvataggio ---------------------------------------------------

func per_salvataggio() -> Dictionary:
	return _base.duplicate(true)


## Rilettura NON FIDATA: solo tipi noti, livelli interi entro il numero di
## livelli disponibili nei dati.
func da_salvataggio(raw: Variant) -> void:
	_base = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for tipo in raw:
		if typeof(raw[tipo]) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var livelli: Array = _livelli(str(tipo))
		if livelli.is_empty():
			continue
		var lv: int = clampi(int(raw[tipo]), 0, livelli.size())
		if lv > 0:
			_base[str(tipo)] = lv


# --- Interno ------------------------------------------------------

func _livelli(tipo: String) -> Array:
	if _gd() == null:
		return []
	return (_gd().call("room_levels", tipo) as Array)


## Consuma il costo dall'inventario. false (e non consuma nulla) se manca
## qualcosa.
func _paga(costo: Dictionary) -> bool:
	var inv: Node = _inv()
	if inv == null:
		return false
	for item_id in costo:
		if int(inv.call("conta", item_id)) < int(costo[item_id]):
			return false
	for item_id in costo:
		inv.call("rimuovi", item_id, int(costo[item_id]))
	return true
