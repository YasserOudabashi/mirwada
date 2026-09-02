extends Node
## Statistiche di un'entita' (giocatore, nemico, pet).
##
## Due livelli: un valore BASE per statistica, e un insieme di MODIFICATORI
## registrati per id. Il valore effettivo e' base + somma dei modificatori.
## L'id serve a rimuovere esattamente il proprio contributo quando un buff
## scade, senza sapere nulla degli altri buff attivi.
##
## I valori di partenza vengono da data/balance.json, non dal codice:
## regola n.1 del progetto, i numeri di bilanciamento sono dati.
##
## NIENTE class_name su questo script, di proposito: i test lo caricano con
## preload, e risolvere una classe globale da uno script caricato a runtime
## dal runner manda Godot 4.3 in stallo senza alcun messaggio.

signal hp_changed(hp: float, hp_max: float)
signal died

## Le statistiche modificabili. hp e spiritualita' correnti NON sono qui:
## sono risorse che si consumano, non caratteristiche.
const STAT_KEYS: PackedStringArray = [
	"hp_max", "spiritualita_max", "velocita", "difesa", "evasione",
]

## Sequenza di partenza: 9 e' la piu' bassa, dove comincia ogni personaggio.
const SEQUENZA_INIZIALE := 9

var _base: Dictionary = {}
## id del modificatore -> { nome_stat: delta }
var _modifiers: Dictionary = {}
var _hp: float = 0.0
var _spiritualita: float = 0.0
var _dead: bool = false


func _ready() -> void:
	if _base.is_empty():
		configure_from_balance(SEQUENZA_INIZIALE)


## Valori base dalle curve di data/balance.json per una data Sequenza.
## I fallback esistono solo perche' un componente non deve esplodere se i
## dati non sono ancora caricati; non sono i numeri di gioco.
func configure_from_balance(sequenza: int) -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var hp_max: float = 100.0
	var sp_max: float = 50.0
	if gd != null:
		hp_max = gd.call("curve_value", "hp_curve", sequenza, hp_max)
		sp_max = gd.call("curve_value", "spiritualita_curve", sequenza, sp_max)

	_base = {
		"hp_max": hp_max,
		"spiritualita_max": sp_max,
		"velocita": 90.0,
		"difesa": 0.0,
		"evasione": 0.0,
	}
	_hp = hp_max
	_spiritualita = sp_max
	_dead = false


# --- Lettura -----------------------------------------------------------------

## Base + somma dei modificatori attivi. E' il solo valore che i sistemi
## devono usare: nessuno legge _base direttamente.
func get_stat(name: String) -> float:
	var total: float = float(_base.get(name, 0.0))
	for id in _modifiers:
		var mod: Dictionary = _modifiers[id]
		total += float(mod.get(name, 0.0))
	return total


func get_base(name: String) -> float:
	return float(_base.get(name, 0.0))


func set_base(name: String, value: float) -> void:
	_base[name] = value
	if name == "hp_max":
		_clamp_hp()


var hp: float:
	get:
		return _hp
	set(value):
		var maximum: float = get_stat("hp_max")
		var clamped: float = clampf(value, 0.0, maximum)
		if is_equal_approx(clamped, _hp):
			return
		_hp = clamped
		hp_changed.emit(_hp, maximum)
		if _hp <= 0.0 and not _dead:
			_dead = true
			died.emit()


var spiritualita: float:
	get:
		return _spiritualita
	set(value):
		_spiritualita = clampf(value, 0.0, get_stat("spiritualita_max"))


func is_dead() -> bool:
	return _dead


## true se la spesa e' andata a buon fine. false = spiritualita' insufficiente
## e NIENTE viene scalato: le abilita' contano su questo per non attivarsi
## a meta'.
func spend_spiritualita(amount: float) -> bool:
	if amount > _spiritualita:
		return false
	spiritualita = _spiritualita - amount
	return true


# --- Modificatori ------------------------------------------------------------

## Registra o sostituisce un modificatore. Ripetere lo stesso id NON somma:
## sostituisce, cosi' riapplicare un buff gia' attivo non lo impila.
func apply_modifier(id: String, deltas: Dictionary) -> void:
	_modifiers[id] = deltas.duplicate(true)
	_clamp_hp()


## true se c'era qualcosa da rimuovere.
func remove_modifier(id: String) -> bool:
	if not _modifiers.has(id):
		return false
	_modifiers.erase(id)
	_clamp_hp()
	return true


func has_modifier(id: String) -> bool:
	return _modifiers.has(id)


func modifier_ids() -> Array:
	return _modifiers.keys()


func clear_modifiers() -> void:
	_modifiers.clear()
	_clamp_hp()


## Se hp_max cala sotto gli hp correnti, gli hp scendono con lui. Senza
## questo, un buff scaduto lascerebbe un'entita' con piu' hp del massimo.
func _clamp_hp() -> void:
	var maximum: float = get_stat("hp_max")
	if _hp > maximum:
		hp = maximum
