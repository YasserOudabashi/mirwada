extends Node
## Il pet del giocatore (US-321). Un solo pet alla volta: la specie e' dato
## (data/pets/), lo stato (quale specie, bond, hp, sequenza) e' qui.
##
## NIENTE class_name: coerente col resto del progetto.

signal pet_domato(pet_id: String)
signal pet_liberato(pet_id: String)
signal pet_avanzato(nuova_sequenza: int)
## soglia_attraversata: -1 se il cambio non ha superato nessuna soglia di
## data/pets/<specie>.comportamenti.
signal bond_cambiato(valore: float, soglia_attraversata: int)

## {} se nessun pet. Altrimenti { pet_id, bond, hp, sequenza, summon_id }.
var _pet: Dictionary = {}
var _rng: RandomNumberGenerator = null


func _ready() -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null and et.has_signal("evento_emesso"):
		et.evento_emesso.connect(_su_evento)


## Definizione della specie del pet attivo unita al suo stato corrente, o {}
## se nessun pet. Il chiamante non deve conoscere data/pets/ per leggerlo.
func pet_attivo() -> Dictionary:
	if _pet.is_empty():
		return {}
	return _pet.duplicate(true)


## Setter grezzo: sostituisce il pet attuale (se c'era) con uno nuovo alla
## specie data, bond 0, hp/sequenza dai dati. false se la specie non esiste.
## L'invariante "un solo pet, doma() richiede prima libera()" e' applicata
## da PetSystem.doma() (US-322), non qui: questo e' il magazzino, non la
## regola di gioco.
func imposta_pet(pet_id: String) -> bool:
	var specie: Dictionary = _specie(pet_id)
	if specie.is_empty():
		return false
	var seq: int = int(specie.get("sequenza_iniziale", 9))
	_pet = {
		"pet_id": pet_id, "bond": 0.0,
		"hp": _hp_max_per_sequenza(specie, seq),
		"sequenza": seq,
	}
	return true


## hp_max per Sequenza dalla curva della specie (US-324); se la Sequenza non
## e' in curva_hp_max (o la specie non ne ha una), l'hp_max base.
func _hp_max_per_sequenza(specie: Dictionary, sequenza: int) -> float:
	var curva: Dictionary = specie.get("curva_hp_max", {})
	var chiave: String = str(sequenza)
	if curva.has(chiave):
		return float(curva[chiave])
	return float(specie.get("hp_max", 0.0))


func bond() -> float:
	return float(_pet.get("bond", 0.0))


## -1 se nessun pet attivo.
func sequenza_pet() -> int:
	if _pet.is_empty():
		return -1
	return int(_pet.get("sequenza", -1))


func pulisci() -> void:
	_pet = {}


# --- Taming (US-322) ---------------------------------------------------

func imposta_seed(s: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = s


## Tira contro la domabilita' della specie (+ bonus da talenti/oggetti,
## US-329/US-316: 0 finche' quei sistemi non esistono). Su successo:
## imposta il pet, registra la sua Ancora e un'evocazione persistente
## (SummonRegistry - US-325 la rimuove alla morte). Un solo pet per volta:
## se ce n'e' gia' uno, libera() prima.
func doma(pet_id: String) -> bool:
	if not _pet.is_empty():
		return false
	var specie: Dictionary = _specie(pet_id)
	if specie.is_empty():
		return false
	var soglia: float = clampf(float(specie.get("domabilita", 0.0)) + _bonus_domabilita(), 0.0, 1.0)
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	if _rng.randf() > soglia:
		return false
	imposta_pet(pet_id)
	var anc: Node = get_node_or_null("/root/AnchorSystem")
	if anc != null:
		anc.call("register", str(specie.get("ancora_id", "")))
	var reg: Node = get_node_or_null("/root/SummonRegistry")
	if reg != null:
		_pet["summon_id"] = reg.call("evoca", pet_id, "alleato", Vector2.ZERO, float(_pet.get("hp", 0.0)))
	pet_domato.emit(pet_id)
	return true


## Rilascio VOLONTARIO e pulito: NON e' la morte (US-325), niente follia.
## Toglie l'Ancora (AnchorSystem.unregister, non destroy), rimuove
## l'evocazione, svuota lo stato. false se non c'era un pet.
func libera() -> bool:
	if _pet.is_empty():
		return false
	var pet_id: String = str(_pet.get("pet_id", ""))
	var specie: Dictionary = _specie(pet_id)
	var anc: Node = get_node_or_null("/root/AnchorSystem")
	if anc != null:
		anc.call("unregister", str(specie.get("ancora_id", "")))
	var reg: Node = get_node_or_null("/root/SummonRegistry")
	if reg != null and _pet.has("summon_id"):
		reg.call("rimuovi", str(_pet.get("summon_id", "")))
	_pet = {}
	pet_liberato.emit(pet_id)
	return true


func _bonus_domabilita() -> float:
	var gd: Node = _gd()
	var b: Dictionary = gd.call("get_balance", "pet") if gd != null else {}
	return float(b.get("bonus_domabilita_talenti", 0.0))


# --- Bond (US-323) -----------------------------------------------------
# Cresce ascoltando EventTracker, come l'Acting Method (US-210/211): nessun
# rilevatore speciale, un solo listener sul segnale generico evento_emesso.
# I pesi sono dati (data/balance.json.pet).

## Comportamenti della specie del pet gia' sbloccati al bond attuale.
func comportamenti_sbloccati() -> Array:
	if _pet.is_empty():
		return []
	var out: Array = []
	var b: float = bond()
	for comp in _specie(str(_pet.get("pet_id", ""))).get("comportamenti", []):
		var d: Dictionary = comp
		if b >= float(d.get("soglia_bond", 999)):
			out.append(str(d.get("id", "")))
	return out


func _su_evento(nome: String, dati: Dictionary) -> void:
	if _pet.is_empty():
		return
	var pesi: Dictionary = _gd().call("get_balance", "pet") if _gd() != null else {}
	var delta: float = 0.0
	match nome:
		"enemy_defeated":
			delta = float(pesi.get("bond_per_enemy_defeated", 0.0))
		"area_cleared":
			delta = float(pesi.get("bond_per_area_cleared", 0.0))
		"time_in_state":
			# Nessun sistema emette ancora time_in_state{stato:esplorazione}
			# (arrivera' col tracking di stato del giocatore, fuori scope
			# qui): il meccanismo e' pronto, il peso resta 0 finche' non
			# emette nessuno.
			if str(dati.get("stato", "")) == "esplorazione":
				delta = float(pesi.get("bond_per_time_in_state_esplorazione", 0.0))
	if delta != 0.0:
		_aggiungi_bond(delta)


func _aggiungi_bond(delta: float) -> void:
	var prima: float = float(_pet.get("bond", 0.0))
	var dopo: float = clampf(prima + delta, 0.0, 100.0)
	_pet["bond"] = dopo
	var soglia: int = -1
	for comp in _specie(str(_pet.get("pet_id", ""))).get("comportamenti", []):
		var s: int = int((comp as Dictionary).get("soglia_bond", -1))
		if prima < s and dopo >= s:
			soglia = s
			break
	bond_cambiato.emit(dopo, soglia)


# --- Coltivazione (US-324) ----------------------------------------------

## Il pet avanza di Sequenza (9->0) se bond >= soglia_avanzamento_bond e il
## giocatore ha una risorsa 'nutre_pet' da consumare (data/items/, la scelta
## di QUALE risorsa e' un dato, non codice: la prima trovata fra quelle
## possedute). Non puo' superare la Sequenza del giocatore (numero piu'
## basso = piu' forte). hp_max/hp aggiornati dalla curva della specie
## (curva_hp_max), mai calcolati nel codice.
func avanza_pet() -> bool:
	if _pet.is_empty():
		return false
	var seq: int = int(_pet.get("sequenza", 9))
	if seq <= 0:
		return false
	var prog: Node = get_node_or_null("/root/Progression")
	var seq_giocatore: int = int(prog.call("sequence")) if prog != null else 9
	if seq - 1 < seq_giocatore:
		return false
	var pesi: Dictionary = _gd().call("get_balance", "pet") if _gd() != null else {}
	if bond() < float(pesi.get("soglia_avanzamento_bond", 999.0)):
		return false
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv == null:
		return false
	var risorsa: String = _risorsa_nutrizione(inv)
	if risorsa.is_empty():
		return false
	inv.call("rimuovi", risorsa, 1)

	var nuova_seq: int = seq - 1
	_pet["sequenza"] = nuova_seq
	_pet["hp"] = _hp_max_per_sequenza(_specie(str(_pet.get("pet_id", ""))), nuova_seq)
	pet_avanzato.emit(nuova_seq)
	return true


## Primo item categoria:consumabile con nutre_pet:true che il giocatore
## possiede davvero. "" se non ne ha nessuno.
func _risorsa_nutrizione(inv: Node) -> String:
	var gd: Node = _gd()
	if gd == null:
		return ""
	for it in gd.call("items_per_categoria", "consumabile"):
		var d: Dictionary = it
		var iid: String = str(d.get("id", ""))
		if bool(d.get("nutre_pet", false)) and bool(inv.call("possiede", iid, 1)):
			return iid
	return ""


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return _pet.duplicate(true)


## NON FIDATO: {} o pet_id che non risolve -> nessun pet.
func da_salvataggio(raw: Variant) -> void:
	_pet = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	var pet_id: String = str(d.get("pet_id", ""))
	var specie: Dictionary = _specie(pet_id)
	if pet_id.is_empty() or specie.is_empty():
		return
	var bond_raw: Variant = d.get("bond")
	var hp_raw: Variant = d.get("hp")
	var seq_raw: Variant = d.get("sequenza")
	var sequenza: int = int(seq_raw) if typeof(seq_raw) in [TYPE_FLOAT, TYPE_INT] else int(specie.get("sequenza_iniziale", 9))
	# hp_max per QUESTA Sequenza (US-324: la curva della specie, non il solo
	# hp_max base) - un pet caricato a meta' avanzamento clampa correttamente.
	var hp_max: float = _hp_max_per_sequenza(specie, sequenza)
	_pet = {
		"pet_id": pet_id,
		"bond": clampf(float(bond_raw) if typeof(bond_raw) in [TYPE_FLOAT, TYPE_INT] else 0.0, 0.0, 100.0),
		"hp": clampf(float(hp_raw) if typeof(hp_raw) in [TYPE_FLOAT, TYPE_INT] else hp_max, 0.0, hp_max),
		"sequenza": sequenza,
	}
	var summon_id: Variant = d.get("summon_id")
	if typeof(summon_id) == TYPE_STRING and not (summon_id as String).is_empty():
		_pet["summon_id"] = summon_id


func _specie(pet_id: String) -> Dictionary:
	var gd: Node = _gd()
	return gd.call("get_pet_species", pet_id) if gd != null else {}


func _gd() -> Node:
	return get_node_or_null("/root/GameData")
