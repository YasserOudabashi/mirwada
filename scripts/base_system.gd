extends Node
## La base del giocatore (US-326): 4 stanze, ognuna a un livello (0 = non
## costruita). I livelli, i costi e i bonus sono dati (data/base/rooms.json);
## il vocabolario chiuso di tipi e chiavi di bonus e' in
## data/schema/room_types.json.
##
## I sistemi (PotionSystem, Forge, ...) leggono bonus(tipo) per CHIAVE: nessun
## if sul nome di una stanza (US-327).
##
## Il GIARDINO (US-328) ha i suoi appezzamenti (numero = livello del giardino):
## pianti un ingrediente coltivabile, cresce col TEMPO DI GIOCO (_process, che
## non gira col libro aperto), lo raccogli in piu' copie.
##
## NIENTE class_name: coerente col resto del progetto.

signal stanza_costruita(tipo: String)
signal stanza_potenziata(tipo: String, livello: int)
signal appezzamento_pronto(indice: int)
signal raccolto(item_id: String, quantita: int)

## { tipo: livello }. Assente o 0 = non costruita.
var _base: Dictionary = {}
## Appezzamenti del giardino: Array di { item_id: String, crescita: float }
## (crescita = secondi di tempo di gioco rimasti; <= 0 = pronto).
var _appezzamenti: Array = []


func _ready() -> void:
	# Il giardino cresce col tempo di GIOCO: _process in pausa (libro aperto)
	# non gira -> la crescita si ferma, come chiede US-328.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	for a in _appezzamenti:
		if float(a["crescita"]) > 0.0:
			a["crescita"] = float(a["crescita"]) - delta
			if float(a["crescita"]) <= 0.0:
				a["crescita"] = 0.0
				appezzamento_pronto.emit(_appezzamenti.find(a))


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
	_appezzamenti.clear()


# --- Giardino (US-328) --------------------------------------------

## Quanti appezzamenti ha il giardino = bonus 'appezzamenti' del suo livello.
func numero_appezzamenti() -> int:
	return int(bonus("giardino").get("appezzamenti", 0))


## Stato di ogni appezzamento: Array di
##   { item_id, crescita (s rimasti), pronto: bool }
## Lungo numero_appezzamenti(): le posizioni oltre gli appezzamenti piantati
## sono libere ({ item_id: "", crescita: 0, pronto: false }).
func appezzamenti() -> Array:
	var n: int = numero_appezzamenti()
	var out: Array = []
	for i in n:
		if i < _appezzamenti.size():
			var a: Dictionary = _appezzamenti[i]
			out.append({
				"item_id": str(a.get("item_id", "")),
				"crescita": float(a.get("crescita", 0.0)),
				"pronto": float(a.get("crescita", 0.0)) <= 0.0 and not str(a.get("item_id", "")).is_empty(),
			})
		else:
			out.append({"item_id": "", "crescita": 0.0, "pronto": false})
	return out


func appezzamento_libero() -> int:
	var stato: Array = appezzamenti()
	for i in stato.size():
		if str((stato[i] as Dictionary)["item_id"]).is_empty():
			return i
	return -1


## Pianta un ingrediente coltivabile in un appezzamento libero. Consuma 1
## unita' dell'item come seme. -> indice dell'appezzamento, -1 se: giardino non
## costruito / nessun appezzamento libero / item non coltivabile / non nello
## zaino.
func pianta(item_id: String) -> int:
	if numero_appezzamenti() <= 0:
		return -1
	if appezzamento_libero() < 0:
		return -1
	var it: Dictionary = _gd().call("get_item", item_id) if _gd() != null else {}
	if str(it.get("categoria", "")) != "ingrediente" or not bool(it.get("coltivabile", false)):
		push_warning("[BaseSystem] '%s' non e' un ingrediente coltivabile." % item_id)
		return -1
	var inv: Node = _inv()
	if inv == null or int(inv.call("conta", item_id)) < 1:
		return -1
	inv.call("rimuovi", item_id, 1)
	var t: float = _tempo_crescita()
	# riempi il primo buco (un appezzamento raccolto lascia item_id vuoto)
	for i in _appezzamenti.size():
		if str(_appezzamenti[i].get("item_id", "")).is_empty():
			_appezzamenti[i] = {"item_id": item_id, "crescita": t}
			return i
	_appezzamenti.append({"item_id": item_id, "crescita": t})
	return _appezzamenti.size() - 1


## Raccoglie un appezzamento PRONTO: N item nello zaino (resa_base +
## bonus 'resa_raccolto'), l'appezzamento torna libero. -> N raccolti (0 se
## non pronto / indice fuori range).
func raccogli(indice: int) -> int:
	if indice < 0 or indice >= _appezzamenti.size():
		return 0
	var a: Dictionary = _appezzamenti[indice]
	var item_id: String = str(a.get("item_id", ""))
	if item_id.is_empty() or float(a.get("crescita", 1.0)) > 0.0:
		return 0
	var b: Dictionary = _gd().call("get_balance", "giardino") if _gd() != null else {}
	var ts: Node = get_node_or_null("/root/TalentSystem")
	var bonus_talento: int = int(ts.call("bonus_int", "resa_bonus_talento")) if ts != null else 0
	var n: int = maxi(1, int(b.get("resa_base", 1)) + int(bonus("giardino").get("resa_raccolto", 0)) + bonus_talento)
	if _inv() != null:
		_inv().call("aggiungi", item_id, n)
	_appezzamenti[indice] = {"item_id": "", "crescita": 0.0}
	var tt: Node = get_node_or_null("/root/TalentTracker")
	if tt != null:
		tt.call("registra", "ingredienti_coltivati", n)  # emettitore US-331
	raccolto.emit(item_id, n)
	return n


# --- Salvataggio ---------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {
		"stanze": _base.duplicate(true),
		"appezzamenti": _appezzamenti.duplicate(true),
	}


## Rilettura NON FIDATA. Accetta sia il formato nuovo ({stanze, appezzamenti})
## sia quello vecchio piatto ({tipo: livello}) di un save v18 pre-giardino.
func da_salvataggio(raw: Variant) -> void:
	_base = {}
	_appezzamenti = []
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	var stanze: Variant = d.get("stanze", d if not d.has("appezzamenti") else {})
	if typeof(stanze) == TYPE_DICTIONARY:
		for tipo in stanze:
			if typeof(stanze[tipo]) not in [TYPE_FLOAT, TYPE_INT]:
				continue
			var livelli: Array = _livelli(str(tipo))
			if livelli.is_empty():
				continue
			var lv: int = clampi(int(stanze[tipo]), 0, livelli.size())
			if lv > 0:
				_base[str(tipo)] = lv
	for entry in _array_or_empty(d.get("appezzamenti")):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var iid: String = str((entry as Dictionary).get("item_id", ""))
		if iid.is_empty():
			continue
		var it: Dictionary = _gd().call("get_item", iid) if _gd() != null else {}
		if str(it.get("categoria", "")) != "ingrediente" or not bool(it.get("coltivabile", false)):
			continue
		_appezzamenti.append({
			"item_id": iid,
			"crescita": maxf(0.0, float((entry as Dictionary).get("crescita", 0.0))),
		})


# --- Interno ------------------------------------------------------

func _livelli(tipo: String) -> Array:
	if _gd() == null:
		return []
	return (_gd().call("room_levels", tipo) as Array)


func _tempo_crescita() -> float:
	var b: Dictionary = _gd().call("get_balance", "giardino") if _gd() != null else {}
	return maxf(0.1, float(b.get("tempo_crescita_s", 30.0)))


static func _array_or_empty(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


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
