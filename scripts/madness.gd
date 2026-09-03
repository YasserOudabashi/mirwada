extends Node
## Follia: statistica cumulativa 0-100 con effetti a soglia.
##
## Sorgenti (fase 2): avanzamento forzato, sacrificio di un'Ancora, pozione
## parziale, permanenza nel mondo spirituale (gancio). Ogni add() registra la
## sorgente.
##
## Soglie da data/balance.json.madness:
##   15  distorsioni (canale visivo, US-215)
##   40  abilita' che si attivano da sole (probabilita' dai dati)
##   70  perdita di input intermittente
##   100 stato mostro / game over per follia
##
## Non si azzera mai del tutto: la riduzione delle Ancore (US-216) e' un CAP
## sulla riduzione, non un reset. Qui riduci() clampa a 0 e basta; il cap
## frazionario lo applica AnchorSystem.
##
## NIENTE class_name: coerente col resto del progetto.

signal madness_changed(valore: float, soglia_attraversata: int)
## Emesso quando la follia fa partire un'abilita' da sola (>= soglia 40).
signal abilita_autonoma()

const _FALLBACK_SOGLIE := {
	"distorsioni": 15.0, "abilita_autonome": 40.0,
	"perdita_input": 70.0, "mostro": 100.0,
}

var _valore: float = 0.0
var _log: Array = []          # { quantita, sorgente }
var _acc_decadimento: float = 0.0
var _acc_autonoma: float = 0.0


func _process(delta: float) -> void:
	# Decadimento naturale (oggi 0: rispettato come dato).
	var per_min: float = _num("decadimento_naturale_al_minuto", 0.0)
	if per_min > 0.0 and _valore > 0.0:
		_acc_decadimento += delta
		if _acc_decadimento >= 1.0:
			var giu: float = per_min / 60.0 * _acc_decadimento
			_acc_decadimento = 0.0
			riduci(giu, "decadimento_naturale")

	# Sopra la soglia, ogni secondo un tiro per un'abilita' autonoma.
	if _valore >= _soglia("abilita_autonome"):
		_acc_autonoma += delta
		if _acc_autonoma >= 1.0:
			_acc_autonoma = 0.0
			tenta_abilita_autonoma()


# --- Mutazione -------------------------------------------------------------

func add(quantita: float, sorgente: String) -> void:
	if quantita == 0.0:
		return
	var prima_soglia: int = soglia_corrente()
	_valore = clampf(_valore + quantita, 0.0, 100.0)
	_log.append({"quantita": quantita, "sorgente": sorgente})
	var dopo_soglia: int = soglia_corrente()
	madness_changed.emit(_valore, dopo_soglia if dopo_soglia != prima_soglia else -1)


## Riduzione semplice (clamp a 0). Il cap frazionario delle Ancore e' in
## AnchorSystem: qui si passa gia' la quantita' calcolata.
func riduci(quantita: float, sorgente: String = "riduzione") -> void:
	add(-absf(quantita), sorgente)


## Un tiro per far partire un'abilita' da sola. Pubblico per i test.
func tenta_abilita_autonoma() -> bool:
	if _valore < _soglia("abilita_autonome"):
		return false
	if randf() < _num("probabilita_attivazione_autonoma_sotto_soglia", 0.08):
		abilita_autonoma.emit()
		return true
	return false


# --- Lettura -------------------------------------------------------------

func valore() -> float:
	return _valore


## La soglia raggiunta: 0, 15, 40, 70 o 100 (il valore, non un indice).
func soglia_corrente() -> int:
	if _valore >= _soglia("mostro"):
		return int(_soglia("mostro"))
	if _valore >= _soglia("perdita_input"):
		return int(_soglia("perdita_input"))
	if _valore >= _soglia("abilita_autonome"):
		return int(_soglia("abilita_autonome"))
	if _valore >= _soglia("distorsioni"):
		return int(_soglia("distorsioni"))
	return 0


func perdita_input_attiva() -> bool:
	return _valore >= _soglia("perdita_input")


func stato_mostro() -> bool:
	return _valore >= _soglia("mostro")


func sorgenti() -> Array:
	return _log.duplicate(true)


# --- Interno ----------------------------------------------------------

func _madness_data() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_balance", "madness") if gd != null else {}


func _num(chiave: String, fallback: float) -> float:
	var v: Variant = _madness_data().get(chiave, fallback)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else fallback


func _soglia(nome: String) -> float:
	return _num("soglia_%s" % nome, _FALLBACK_SOGLIE.get(nome, 100.0))


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"valore": _valore, "log": _log.duplicate(true)}


func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var v: Variant = d.get("valore", 0.0)
	_valore = clampf(float(v), 0.0, 100.0) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.0
	var l: Variant = d.get("log", [])
	_log = []
	if typeof(l) == TYPE_ARRAY:
		for e in l:
			if typeof(e) == TYPE_DICTIONARY:
				_log.append(e)
	madness_changed.emit(_valore, -1)


func azzera() -> void:
	_valore = 0.0
	_log.clear()
	madness_changed.emit(_valore, -1)
