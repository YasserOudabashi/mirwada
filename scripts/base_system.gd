extends Node
## Le stanze della base (US-326). Ogni tipo ha livelli 1..N nei dati
## (data/base/rooms.json): livello 0 = non costruita. bonus(tipo) e' il
## bonus COMPLETO del livello attuale, non un accumulo dei precedenti -
## chi legge bonus() (PotionSystem, Forge, ..., US-327) non deve sapere
## nient'altro della stanza che la sua chiave.
##
## NIENTE class_name: coerente col resto del progetto.

signal stanza_costruita(tipo: String, livello: int)
signal stanza_potenziata(tipo: String, livello: int)

var _livelli: Dictionary = {}   # tipo -> int, assente = 0


func costruisci(tipo: String) -> bool:
	if livello(tipo) > 0:
		return false
	return _sali_di_livello(tipo)


func potenzia(tipo: String) -> bool:
	if livello(tipo) <= 0:
		return false
	return _sali_di_livello(tipo)


func livello(tipo: String) -> int:
	return int(_livelli.get(tipo, 0))


## Bonus del livello attuale, {} se non costruita.
func bonus(tipo: String) -> Dictionary:
	var l: int = livello(tipo)
	var livelli: Array = _room_levels(tipo)
	if l <= 0 or l - 1 >= livelli.size():
		return {}
	return (livelli[l - 1] as Dictionary).get("bonus", {}).duplicate(true)


## Costo del prossimo livello (il primo se non ancora costruita). {} se
## gia' al massimo o il tipo non esiste.
func prossimo_costo(tipo: String) -> Dictionary:
	var l: int = livello(tipo)
	var livelli: Array = _room_levels(tipo)
	if l >= livelli.size():
		return {}
	return (livelli[l] as Dictionary).get("costo", {}).duplicate(true)


func pulisci() -> void:
	_livelli.clear()


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return _livelli.duplicate(true)


## NON FIDATO: scarta tipi fuori vocabolario e livelli oltre il massimo dati.
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var tipi: Array = _gd().call("room_types") if _gd() != null else []
	for tipo in (raw as Dictionary):
		if not tipi.has(str(tipo)):
			continue
		var v: Variant = (raw as Dictionary)[tipo]
		if typeof(v) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var max_liv: int = _room_levels(str(tipo)).size()
		var liv: int = clampi(int(v), 0, max_liv)
		if liv > 0:
			_livelli[str(tipo)] = liv


# --- Interno -----------------------------------------------------------

func _sali_di_livello(tipo: String) -> bool:
	var livelli: Array = _room_levels(tipo)
	if livello(tipo) >= livelli.size():
		return false   # gia' al massimo, o tipo ignoto (0 livelli)
	var costo: Dictionary = prossimo_costo(tipo)
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv == null:
		return false
	for item_id in costo:
		if int(inv.call("conta", item_id)) < int(costo[item_id]):
			return false
	for item_id in costo:
		inv.call("rimuovi", item_id, int(costo[item_id]))
	var nuovo: int = livello(tipo) + 1
	_livelli[tipo] = nuovo
	if nuovo == 1:
		stanza_costruita.emit(tipo, nuovo)
	else:
		stanza_potenziata.emit(tipo, nuovo)
	return true


func _room_levels(tipo: String) -> Array:
	var gd: Node = _gd()
	return gd.call("room_levels", tipo) if gd != null else []


func _gd() -> Node:
	return get_node_or_null("/root/GameData")
