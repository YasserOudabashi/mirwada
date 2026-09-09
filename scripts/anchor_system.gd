extends Node
## Ancore: i legami che tengono umano il Beyonder (US-216).
##
## Ogni Ancora attiva BUFFERIZZA parte della follia in arrivo: fino a "forza"
## punti in totale, e mai piu' di riduzione_max_ancore (0.60) del singolo
## colpo. E' un cap sulla riduzione, non un reset: la follia non si azzera.
##
## Distruggere un'Ancora (NPC che muore, sacrificio rituale di Seq 1) aggiunge
## "penalita" follia con sorgente "anchor_lost" — e QUEL colpo non e'
## bufferizzato.
##
## NIENTE class_name: coerente col resto del progetto.

signal ancora_registrata(id: String)
signal anchor_lost(id: String)

var _active: Array = []
## US-719: un'Ancora ereditata da un personaggio precedente vive a forza
## dimezzata rispetto al dato. id -> forza (solo le Ancore con un override;
## un'Ancora normale non ci compare e usa la forza dei dati).
var _forza_override: Dictionary = {}


func _ready() -> void:
	_aggiorna_nomi_sussurro()


# --- API --------------------------------------------------------------

## Registra un'Ancora. false se l'id non esiste nei dati o e' gia' attiva.
## forza_override >= 0 (US-719, eredita' al personaggio successivo): usa
## questa forza invece di quella dei dati - un'Ancora ereditata a meta' forza.
func register(anchor_id: String, forza_override: float = -1.0) -> bool:
	if _active.has(anchor_id) or _dati_ancora(anchor_id).is_empty():
		return false
	_active.append(anchor_id)
	if forza_override >= 0.0:
		_forza_override[anchor_id] = forza_override
	ancora_registrata.emit(anchor_id)
	_aggiorna_nomi_sussurro()
	return true


## Distrugge un'Ancora attiva: emette anchor_lost e aggiunge follia
## (sorgente "anchor_lost", NON bufferizzata dalle altre Ancore).
func destroy(anchor_id: String) -> bool:
	if not _active.has(anchor_id):
		return false
	_active.erase(anchor_id)
	_forza_override.erase(anchor_id)
	var pen: float = float(_dati_ancora(anchor_id).get("penalita", 0.0))
	anchor_lost.emit(anchor_id)
	var m: Node = get_node_or_null("/root/Madness")
	if m != null and pen > 0.0:
		m.call("add", pen, "anchor_lost", false)  # false = non bufferizzata
	_aggiorna_nomi_sussurro()
	return true


## Rilascio PULITO di un'Ancora attiva (US-322: liberare il pet). A differenza
## di destroy() non e' un colpo: nessuna follia, nessun anchor_lost. false se
## l'Ancora non era attiva.
func rilascia(anchor_id: String) -> bool:
	if not _active.has(anchor_id):
		return false
	_active.erase(anchor_id)
	_forza_override.erase(anchor_id)
	_aggiorna_nomi_sussurro()
	return true


func active() -> Array:
	return _active.duplicate()


## La forza in uso per quell'Ancora attiva (l'override ereditato se c'e',
## altrimenti quella dei dati). 0.0 se non e' attiva.
func forza_di(anchor_id: String) -> float:
	if not _active.has(anchor_id):
		return 0.0
	return _forza_override.get(anchor_id, float(_dati_ancora(anchor_id).get("forza", 0.0)))


## Somma delle forze delle Ancore attive: il tetto di follia bufferizzabile.
func forza_totale() -> float:
	var t: float = 0.0
	for id in _active:
		t += forza_di(id)
	return t


## Quanto di un colpo di follia "quantita" le Ancore assorbono: min tra la
## forza totale e riduzione_max_ancore * quantita.
func assorbi(quantita: float) -> float:
	if quantita <= 0.0 or _active.is_empty():
		return 0.0
	return minf(forza_totale(), _riduzione_max() * quantita)


func pulisci() -> void:
	_active.clear()
	_forza_override.clear()
	_aggiorna_nomi_sussurro()


# --- Salvataggio -----------------------------------------------------

## Un'Ancora normale e' la sua stringa id (formato invariato, com'era prima
## di US-719); una con un override di forza e' { id, forza } - i save
## precedenti (solo stringhe) restano leggibili identici.
func per_salvataggio() -> Array:
	var out: Array = []
	for id in _active:
		if _forza_override.has(id):
			out.append({"id": id, "forza": _forza_override[id]})
		else:
			out.append(id)
	return out


func da_salvataggio(raw: Variant) -> void:
	_active = []
	_forza_override = {}
	if typeof(raw) != TYPE_ARRAY:
		_aggiorna_nomi_sussurro()
		return
	for v in raw:
		if typeof(v) == TYPE_STRING and not _dati_ancora(v).is_empty():
			_active.append(v)
		elif typeof(v) == TYPE_DICTIONARY:
			var id: String = str((v as Dictionary).get("id", ""))
			var dati: Dictionary = _dati_ancora(id)
			if not dati.is_empty():
				_active.append(id)
				var forza: Variant = (v as Dictionary).get("forza")
				if typeof(forza) in [TYPE_INT, TYPE_FLOAT]:
					_forza_override[id] = clampf(float(forza), 0.0, float(dati.get("forza", 0.0)))
	_aggiorna_nomi_sussurro()


# --- Interno --------------------------------------------------------

func _dati_ancora(id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return {}
	for a in gd.call("get_anchors"):
		if typeof(a) == TYPE_DICTIONARY and str((a as Dictionary).get("id", "")) == id:
			return a
	return {}


func _riduzione_max() -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	var m: Dictionary = gd.call("get_balance", "madness") if gd != null else {}
	var v: Variant = m.get("riduzione_max_ancore", 0.60)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.60


## US-214: i sussurri di soglia 55 pronunciano i nomi delle Ancore attive.
func _aggiorna_nomi_sussurro() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	var nomi: Array = []
	for id in _active:
		var chiave: String = str(_dati_ancora(id).get("name_i18n", ""))
		if not chiave.is_empty():
			nomi.append(chiave)
	am.call("imposta_nomi_sussurro", nomi)
