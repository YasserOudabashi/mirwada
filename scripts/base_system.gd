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
signal appezzamento_piantato(indice: int, item_id: String)
signal appezzamento_raccolto(indice: int, item_id: String, quantita: int)

var _livelli: Dictionary = {}   # tipo -> int, assente = 0
## Appezzamenti del giardino (US-328): Array[{ item_id, pronto_a }]. pronto_a
## e' un istante di GameState.tempo_gioco (tempo di GIOCO, non wall-clock):
## si legge on-demand, nessun _process qui. tempo_gioco si ferma da solo col
## mondo in pausa (libro aperto: Book/BookOverlay sono gli unici
## PROCESS_MODE_ALWAYS del progetto), quindi la crescita si ferma con lui
## senza che BaseSystem debba saperne nulla.
var _appezzamenti: Array = []


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
	_appezzamenti.clear()


# --- Giardino (US-328) -------------------------------------------------

## Pianta item_id nel primo appezzamento libero (ce ne sono quanti il
## livello del giardino). -1 se il giardino non e' costruita, l'item non e'
## un ingrediente coltivabile, il giocatore non lo possiede, o non c'e'
## posto.
func pianta(item_id: String) -> int:
	var liv: int = livello("giardino")
	if liv <= 0 or _appezzamenti.size() >= liv:
		return -1
	var def: Dictionary = _def_item(item_id)
	if str(def.get("categoria", "")) != "ingrediente" or not bool(def.get("coltivabile", false)):
		return -1
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv == null or not bool(inv.call("possiede", item_id, 1)):
		return -1
	inv.call("rimuovi", item_id, 1)
	var tempo_crescita: float = float(_gd().call("get_balance", "giardino").get("tempo_crescita", 60.0)) \
		if _gd() != null else 60.0
	_appezzamenti.append({"item_id": item_id, "pronto_a": _tempo_gioco() + tempo_crescita})
	var idx: int = _appezzamenti.size() - 1
	appezzamento_piantato.emit(idx, item_id)
	return idx


## [{ item_id, pronto: bool, tempo_rimasto: float }] per ogni appezzamento
## occupato, in ordine.
func appezzamenti() -> Array:
	var out: Array = []
	var ora: float = _tempo_gioco()
	for a in _appezzamenti:
		var d: Dictionary = a
		var pronto_a: float = float(d.get("pronto_a", 0.0))
		out.append({
			"item_id": d.get("item_id", ""),
			"pronto": ora >= pronto_a,
			"tempo_rimasto": maxf(0.0, pronto_a - ora),
		})
	return out


func e_pronto(indice: int) -> bool:
	if indice < 0 or indice >= _appezzamenti.size():
		return false
	return _tempo_gioco() >= float((_appezzamenti[indice] as Dictionary).get("pronto_a", 0.0))


## Raccoglie un appezzamento pronto: N item nell'inventario (N = bonus
## giardino.resa del livello attuale, minimo 1), libera l'appezzamento.
## false se non pronto o l'indice non esiste.
func raccogli(indice: int) -> bool:
	if not e_pronto(indice):
		return false
	var d: Dictionary = _appezzamenti[indice]
	var item_id: String = str(d.get("item_id", ""))
	var resa: int = maxi(1, int(bonus("giardino").get("resa", 1)))
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv != null:
		inv.call("aggiungi", item_id, resa)
	_appezzamenti.remove_at(indice)
	var tt: Node = get_node_or_null("/root/TalentTracker")
	if tt != null:
		tt.call("emit_event", "ingredienti_coltivati", {})
	appezzamento_raccolto.emit(indice, item_id, resa)
	return true


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"livelli": _livelli.duplicate(true), "giardino": _appezzamenti.duplicate(true)}


## NON FIDATO: scarta tipi fuori vocabolario, livelli oltre il massimo dati,
## e appezzamenti con un item_id che non risolve piu' a un ingrediente
## coltivabile (i dati potrebbero essere cambiati fra un save e l'altro).
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	var tipi: Array = _gd().call("room_types") if _gd() != null else []
	for tipo in (d.get("livelli", {}) as Dictionary):
		if not tipi.has(str(tipo)):
			continue
		var v: Variant = (d.get("livelli", {}) as Dictionary)[tipo]
		if typeof(v) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var max_liv: int = _room_levels(str(tipo)).size()
		var liv: int = clampi(int(v), 0, max_liv)
		if liv > 0:
			_livelli[str(tipo)] = liv
	for voce in (d.get("giardino", []) as Array):
		if typeof(voce) != TYPE_DICTIONARY:
			continue
		var v2: Dictionary = voce
		var item_id: String = str(v2.get("item_id", ""))
		var def: Dictionary = _def_item(item_id)
		if str(def.get("categoria", "")) != "ingrediente" or not bool(def.get("coltivabile", false)):
			continue
		var pronto_a: Variant = v2.get("pronto_a")
		if typeof(pronto_a) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		_appezzamenti.append({"item_id": item_id, "pronto_a": float(pronto_a)})


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


func _tempo_gioco() -> float:
	var gs: Node = get_node_or_null("/root/GameState")
	return float(gs.get("tempo_gioco")) if gs != null else 0.0


func _def_item(item_id: String) -> Dictionary:
	var gd: Node = _gd()
	return gd.call("get_item", item_id) if gd != null else {}
