extends Node
## Concoction: combina una Caratteristica Beyonder con gli ingredienti per
## creare la pozione della Sequenza successiva, poi la si beve per avanzare.
##
## - concoct(formula_id, characteristic_id, ingredienti[]) -> crea la pozione
##   (completa o PARZIALE se mancano ingredienti, sopra la soglia della
##   formula), consumando la Caratteristica.
## - bevi(forza) -> se l'Acting e' completo, avanza; altrimenti la pozione e'
##   "digerita male" (fondamenta giu', follia su, nessun avanzamento) — a meno
##   che forza sia true (US-212: avanza comunque, malus pesante).
##
## NIENTE class_name: coerente col resto del progetto.

signal pozione_creata(sequenza_da: int, parziale: bool)
signal pozione_bevuta(avanzato: bool, forzato: bool)

var _pozione: Dictionary = {}


# --- Concoction --------------------------------------------------------

func concoct(formula_id: String, characteristic_id: String, ingredienti: Array) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	var formula: Dictionary = gd.call("get_formula", formula_id) if gd != null else {}
	if formula.is_empty():
		return {"ok": false, "reason": "formula_inesistente"}

	var seq_car: int = int(formula.get("characteristic_sequence", -1))
	var car: Dictionary = gd.call("get_characteristic", characteristic_id)
	if car.is_empty() or int(car.get("sequence", -99)) != seq_car:
		return {"ok": false, "reason": "caratteristica_incoerente"}

	var store: Node = get_node_or_null("/root/CharacteristicStore")
	if store == null or not store.call("possiede", characteristic_id):
		return {"ok": false, "reason": "caratteristica_mancante"}

	# Quanti ingredienti RICHIESTI sono fra quelli passati (distinti).
	var richiesti: Array = formula.get("ingredients", [])
	var presenti: Array = []
	for i in ingredienti:
		if richiesti.has(i) and not presenti.has(i):
			presenti.append(i)
	var soglia: int = int(formula.get("soglia_parziale", richiesti.size()))
	if presenti.size() < soglia:
		return {"ok": false, "reason": "ingredienti_insufficienti"}

	var parziale: bool = presenti.size() < richiesti.size()
	store.call("consuma", characteristic_id)

	_pozione = {
		"formula_id": formula_id,
		"da_sequenza": seq_car,   # si beve a questa Sequenza, porta a seq_car - 1
		"parziale": parziale,
		"penalita": formula.get("penalita_parziale", {}) if parziale else {},
	}
	pozione_creata.emit(seq_car, parziale)
	return {"ok": true, "reason": "ok", "pozione": _pozione.duplicate(true)}


func pozione_pronta() -> Dictionary:
	return _pozione.duplicate(true)


func scarta_pozione() -> void:
	_pozione = {}


# --- Bere -------------------------------------------------------------

## forza: se true e l'Acting non e' completo, avanza COMUNQUE con un malus
## pesante alle fondamenta (US-212). Se false, con Acting incompleto la
## pozione e' sprecata ("digerita male").
func bevi(forza: bool = false) -> Dictionary:
	if _pozione.is_empty():
		return {"ok": false, "reason": "nessuna_pozione"}

	var prog: Node = get_node_or_null("/root/Progression")
	if prog == null:
		return {"ok": false, "reason": "no_progression"}
	if int(_pozione.get("da_sequenza", -1)) != int(prog.call("sequence")):
		return {"ok": false, "reason": "pozione_per_un'altra_sequenza"}

	var acting: Node = get_node_or_null("/root/Acting")
	var completo: bool = acting != null and acting.call("e_completo")

	var found: Node = get_node_or_null("/root/Foundation")
	var madness: Node = get_node_or_null("/root/Madness")
	var seq_data: Dictionary = prog.call("sequence_data")
	var madness_on_force: float = float(seq_data.get("madness_on_force", 0.0))
	var mult: float = found.call("moltiplicatore_follia") if found != null else 1.0

	var esito: Dictionary = {"ok": true, "avanzato": false, "forzato": false, "follia": 0.0}

	if completo:
		prog.call("avanza")
		if found != null:
			found.call("applica", found.call("costante", "bonus_recitazione_completa"), "recitazione_completa")
		if _pozione.get("parziale", false) and madness != null:
			var pen: float = float((_pozione.get("penalita", {}) as Dictionary).get("follia_extra", 0.0)) * mult
			madness.call("add", pen, "pozione_parziale")
			esito["follia"] = pen
		esito["avanzato"] = true
	elif forza:
		prog.call("avanza")
		if found != null:
			found.call("applica", found.call("costante", "malus_avanzamento_forzato"), "avanzamento_forzato")
		if madness != null:
			var f: float = madness_on_force * mult
			madness.call("add", f, "avanzamento_forzato")
			esito["follia"] = f
		esito["avanzato"] = true
		esito["forzato"] = true
	else:
		# Digerita male: niente avanzamento, penalita' contenuta.
		if found != null:
			found.call("applica", found.call("costante", "malus_digestione_difficile"), "pozione_digerita_male")
		if madness != null:
			var d: float = madness_on_force * mult
			madness.call("add", d, "pozione_digerita_male")
			esito["follia"] = d

	_pozione = {}
	pozione_bevuta.emit(esito["avanzato"], esito["forzato"])
	return esito
