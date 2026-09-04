extends Node
## Il pet del giocatore (US-321). Un solo pet alla volta: la specie e' dato
## (data/pets/), lo stato (quale specie, bond, hp, sequenza) e' qui.
##
## NIENTE class_name: coerente col resto del progetto.

signal pet_domato(pet_id: String)
signal pet_liberato(pet_id: String)

## {} se nessun pet. Altrimenti { pet_id, bond, hp, sequenza, summon_id }.
var _pet: Dictionary = {}
var _rng: RandomNumberGenerator = null


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
	_pet = {
		"pet_id": pet_id, "bond": 0.0,
		"hp": float(specie.get("hp_max", 0.0)),
		"sequenza": int(specie.get("sequenza_iniziale", 9)),
	}
	return true


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
	var hp_max: float = float(specie.get("hp_max", 0.0))
	var bond_raw: Variant = d.get("bond")
	var hp_raw: Variant = d.get("hp")
	var seq_raw: Variant = d.get("sequenza")
	_pet = {
		"pet_id": pet_id,
		"bond": clampf(float(bond_raw) if typeof(bond_raw) in [TYPE_FLOAT, TYPE_INT] else 0.0, 0.0, 100.0),
		"hp": clampf(float(hp_raw) if typeof(hp_raw) in [TYPE_FLOAT, TYPE_INT] else hp_max, 0.0, hp_max),
		"sequenza": int(seq_raw) if typeof(seq_raw) in [TYPE_FLOAT, TYPE_INT] else int(specie.get("sequenza_iniziale", 9)),
	}
	var summon_id: Variant = d.get("summon_id")
	if typeof(summon_id) == TYPE_STRING and not (summon_id as String).is_empty():
		_pet["summon_id"] = summon_id


func _specie(pet_id: String) -> Dictionary:
	var gd: Node = _gd()
	return gd.call("get_pet_species", pet_id) if gd != null else {}


func _gd() -> Node:
	return get_node_or_null("/root/GameData")
