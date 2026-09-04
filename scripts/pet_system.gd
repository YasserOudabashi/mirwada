extends Node
## Il pet del giocatore (US-321). Un solo pet alla volta: la specie e' dato
## (data/pets/), lo stato (quale specie, bond, hp, sequenza) e' qui.
##
## NIENTE class_name: coerente col resto del progetto.

## {} se nessun pet. Altrimenti { pet_id, bond, hp, sequenza }.
var _pet: Dictionary = {}


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


func _specie(pet_id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_pet_species", pet_id) if gd != null else {}
