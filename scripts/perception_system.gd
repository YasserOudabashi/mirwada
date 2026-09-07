extends Node
## Percezione per Sequenza (US-218): salendo di Sequenza (numero che scende)
## si SENTONO e si VEDONO cose che prima non c'erano. E' il radar
## dell'esplorazione, cumulativo e guidato da audio.json.sequence_perception.
##
## Le voci sono a 9, 7, 5, 3, 1. Per una Sequenza in mezzo si usa la voce
## piu' vicina VERSO L'ALTO in numero (a Sequenza 6 vale quella di 7: hai gia'
## superato la 7). Nessun numero di Sequenza nel codice.
##
## FR-7: ogni reveal ha un layer audio E un equivalente visivo
## (PerceptionOverlay). Nessuna informazione vive solo in un canale.
##
## NIENTE class_name: coerente col resto del progetto.

signal percezione_cambiata(layers: Array, reveal: Array)

var _tabella: Dictionary = {}
var _layers: Array = []
var _reveal: Array = []


func _ready() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_tabella = gd.call("get_audio", "sequence_perception")
	var prog: Node = get_node_or_null("/root/Progression")
	if prog != null and prog.has_signal("sequence_changed"):
		prog.sequence_changed.connect(func(_n: int, _v: int) -> void: aggiorna())
	aggiorna()


func aggiorna() -> void:
	var prog: Node = get_node_or_null("/root/Progression")
	var seq: int = int(prog.call("sequence")) if prog != null else 9
	var voce: Dictionary = _voce_per_sequenza(seq)
	_layers = (voce.get("layers", []) as Array).duplicate()
	_reveal = (voce.get("reveal", []) as Array).duplicate()
	_suona_layers()
	percezione_cambiata.emit(_layers, _reveal)


func layers_attivi() -> Array:
	return _layers.duplicate()


func reveal_attivi() -> Array:
	return _reveal.duplicate()


func reveal_attivo(nome: String) -> bool:
	return _reveal.has(nome)


## US-618: da una certa Sequenza in su (balance.densita_mistica.sequenza_
## percezione, di default 5) il giocatore "sente" la densita' mistica del
## luogo. Sotto quella Sequenza: -1.0 (non la percepisci).
func densita_percepita() -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	var prog: Node = get_node_or_null("/root/Progression")
	var soglia: int = 5
	if gd != null:
		soglia = int(gd.call("get_balance", "densita_mistica").get("sequenza_percezione", 5))
	if prog == null or int(prog.call("sequence")) > soglia:
		return -1.0
	var ws: Node = get_node_or_null("/root/WorldState")
	return float(ws.call("densita_mistica_corrente")) if ws != null else -1.0


# --- Interno ----------------------------------------------------------

## La voce con la chiave numerica piu' PICCOLA che sia >= seq (a Seq 6 -> "7").
## Se seq e' sotto la piu' bassa (1), usa la piu' bassa.
func _voce_per_sequenza(seq: int) -> Dictionary:
	var chiavi: Array = []
	for k in _tabella:
		if str(k).is_valid_int():
			chiavi.append(int(k))
	if chiavi.is_empty():
		return {}
	chiavi.sort()
	var scelta: int = chiavi[chiavi.size() - 1]
	for k in chiavi:
		if k >= seq:
			scelta = k
			break
	if seq < chiavi[0]:
		scelta = chiavi[0]
	var v: Variant = _tabella.get(str(scelta), {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _suona_layers() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("imposta_layers_ambientali"):
		am.call("imposta_layers_ambientali", _layers)
