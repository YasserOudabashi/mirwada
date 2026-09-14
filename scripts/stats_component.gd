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
signal spiritualita_changed(spiritualita: float, spiritualita_max: float)
signal died

## Le statistiche modificabili. hp e spiritualita' correnti NON sono qui:
## sono risorse che si consumano, non caratteristiche.
const STAT_KEYS: PackedStringArray = [
	"hp_max", "spiritualita_max", "velocita", "difesa", "evasione", "precisione",
]

## Sequenza di partenza: 9 e' la piu' bassa, dove comincia ogni personaggio.
const SEQUENZA_INIZIALE := 9

## Valori di sola emergenza. Se un componente si configura senza che GameData
## sia caricato non deve esplodere, ma NON sono i numeri di gioco: quelli
## vivono in data/balance.json. Arrivare qui in partita e' un bug, per questo
## configure_from_balance emette push_warning quando li usa.
const _FALLBACK := {
	"hp_max": 100.0, "spiritualita_max": 50.0,
	"velocita": 90.0, "difesa": 0.0, "evasione": 0.0, "precisione": 0.0,
}

var _base: Dictionary = {}
## id del modificatore -> { nome_stat: delta }
var _modifiers: Dictionary = {}
## status nominato -> { tag: String, left: float }  (left < 0 = permanente)
var _statuses: Dictionary = {}
var _hp: float = 0.0
var _spiritualita: float = 0.0
var _dead: bool = false

## Scudo (primitiva "shield", US-202): una riserva che assorbe il danno prima
## degli hp. tag_bloccati vuoto = blocca ogni tipo di danno; altrimenti solo
## i tag elencati. riflette e' la quota di danno assorbito rimandata al
## mittente — registrata qui, applicata da chi conosce il mittente.
var _scudo: float = 0.0
var _scudo_riflette: float = 0.0
var _scudo_tag_bloccati: Array = []


func _ready() -> void:
	if _base.is_empty():
		configure_from_balance(SEQUENZA_INIZIALE)


## Valori base da data/balance.json: hp_max e spiritualita_max dalle curve per
## Sequenza, velocita/difesa/evasione/precisione dalla sezione stats_base (non
## dipendono dalla Sequenza). Se GameData non c'e' si parte dai _FALLBACK con
## un avviso: non e' una condizione normale, i numeri di gioco stanno nei dati.
func configure_from_balance(sequenza: int) -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var hp_max: float = _FALLBACK["hp_max"]
	var sp_max: float = _FALLBACK["spiritualita_max"]
	var velocita: float = _FALLBACK["velocita"]
	var difesa: float = _FALLBACK["difesa"]
	var evasione: float = _FALLBACK["evasione"]
	var precisione: float = _FALLBACK["precisione"]

	if gd != null:
		hp_max = gd.call("curve_value", "hp_curve", sequenza, hp_max)
		sp_max = gd.call("curve_value", "spiritualita_curve", sequenza, sp_max)
		var sb: Dictionary = gd.call("get_balance", "stats_base")
		velocita = float(sb.get("velocita", velocita))
		difesa = float(sb.get("difesa", difesa))
		evasione = float(sb.get("evasione", evasione))
		precisione = float(sb.get("precisione", precisione))
	else:
		push_warning("[StatsComponent] GameData assente: statistiche dai valori "
			+ "di emergenza, non da data/balance.json.")

	_base = {
		"hp_max": hp_max,
		"spiritualita_max": sp_max,
		"velocita": velocita,
		"difesa": difesa,
		"evasione": evasione,
		"precisione": precisione,
	}
	_hp = hp_max
	_spiritualita = sp_max
	_dead = false
	azzera_scudo()


# --- Lettura -----------------------------------------------------------------

## Base + somma dei modificatori attivi. E' il solo valore che i sistemi
## devono usare: nessuno legge _base direttamente.
## US-618: il giocatore recupera spiritualita' nel tempo; il ritmo scala con
## la densita' mistica del luogo (WorldState) — fuori citta' si recupera di
## piu'. Solo il giocatore: i nemici non rigenerano.
func _rigenera_spiritualita(delta: float) -> void:
	if _dead or delta <= 0.0:
		return
	var p: Node = get_parent()
	if p == null or not p.is_in_group("player"):
		return
	var maximum: float = get_stat("spiritualita_max")
	if _spiritualita >= maximum:
		return
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var c: Dictionary = gd.call("get_balance", "densita_mistica")
	var base: float = float(c.get("recupero_spiritualita_al_sec", 1.5))
	var ws: Node = get_node_or_null("/root/WorldState")
	var d: float = float(ws.call("densita_mistica_corrente")) if ws != null else 0.2
	var baseline: float = float(c.get("densita_baseline", 0.2))
	var molt: float = 1.0 + maxf(0.0, d - baseline) * float(c.get("molt_recupero_per_densita", 3.0))
	spiritualita = minf(_spiritualita + base * molt * delta, maximum)


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
		var maximum: float = get_stat("spiritualita_max")
		var clamped: float = clampf(value, 0.0, maximum)
		if is_equal_approx(clamped, _spiritualita):
			return
		_spiritualita = clamped
		spiritualita_changed.emit(_spiritualita, maximum)


func is_dead() -> bool:
	return _dead


## Riporta l'entita' in vita con l'hp indicato (hp_max se omesso o negativo).
## Resetta il flag di morte: senza questo, il setter di 'hp' (che emette
## 'died' solo su una transizione "not _dead" -> 0) non potrebbe mai
## rilevare una morte successiva alla prima.
func revivi(quantita: float = -1.0) -> void:
	var maximum: float = get_stat("hp_max")
	_dead = false
	_hp = clampf(quantita if quantita >= 0.0 else maximum, 0.0, maximum)
	hp_changed.emit(_hp, maximum)


func _process(delta: float) -> void:
	_rigenera_spiritualita(delta)
	if _statuses.is_empty():
		return
	for id in _statuses.keys():
		var e: Dictionary = _statuses[id]
		if float(e.get("left", -1.0)) < 0.0:
			continue
		e["left"] = float(e["left"]) - delta
		if float(e["left"]) <= 0.0:
			rimuovi_status(id)


# --- Status (US-218C) -----------------------------------------------------

## Applica uno status nominato (data/status_effects.json). durata < 0 usa la
## durata_default dei dati; i suoi stat_modifiers diventano un modificatore
## per id "status:<id>". Riapplicare rinfresca la durata.
func applica_status(id: String, durata: float = -1.0) -> void:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var dati: Dictionary = gd.call("get_status_effect", id) if gd != null else {}
	if dati.is_empty():
		push_error("[StatsComponent] status inesistente: '%s'" % id)
		return
	var d: float = durata
	if d < 0.0:
		d = float(dati.get("durata_default", -1.0))
	_statuses[id] = {"tag": str(dati.get("tag", "")), "left": d}
	var mods: Variant = dati.get("stat_modifiers", {})
	apply_modifier("status:%s" % id, mods if typeof(mods) == TYPE_DICTIONARY else {})


func rimuovi_status(id: String) -> bool:
	if not _statuses.has(id):
		return false
	_statuses.erase(id)
	remove_modifier("status:%s" % id)
	return true


## Toglie tutti gli status con questo tag. Restituisce quanti ne ha tolti.
func rimuovi_status_per_tag(tag: String) -> int:
	var tolti: int = 0
	for id in _statuses.keys():
		if str((_statuses[id] as Dictionary).get("tag", "")) == tag:
			rimuovi_status(id)
			tolti += 1
	return tolti


func ha_status(id: String) -> bool:
	return _statuses.has(id)


func status_attivi() -> Array:
	return _statuses.keys()


# --- Scudo (primitiva shield) ----------------------------------------------

## Somma alla riserva di scudo. Riapplicare aggiorna riflette e tag_bloccati
## con quelli dell'ultimo scudo: e' un rinforzo, non uno stack di regole.
func aggiungi_scudo(assorbimento: float, riflette: float = 0.0, tag_bloccati: Array = []) -> void:
	_scudo += maxf(assorbimento, 0.0)
	_scudo_riflette = clampf(riflette, 0.0, 1.0)
	_scudo_tag_bloccati = tag_bloccati.duplicate()


func scudo() -> float:
	return _scudo


func azzera_scudo() -> void:
	_scudo = 0.0
	_scudo_riflette = 0.0
	_scudo_tag_bloccati = []


## Consuma lo scudo per primo e restituisce il danno RESIDUO da togliere agli
## hp. Se lo scudo non copre quel tag di danno, non interviene. Chi infligge
## il danno passa da qui prima di toccare gli hp (vedi hurtbox.gd).
func assorbi_danno(danno: float, tag: String = "") -> float:
	if danno <= 0.0 or _scudo <= 0.0:
		return danno
	# tag "" = danno non tipizzato (la pipeline di hurtbox non porta ancora il
	# tag): lo scudo lo assorbe comunque. Con un tag esplicito, filtra.
	if tag != "" and not _scudo_tag_bloccati.is_empty() and not _scudo_tag_bloccati.has(tag):
		return danno
	var assorbito: float = minf(danno, _scudo)
	_scudo -= assorbito
	return danno - assorbito


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
