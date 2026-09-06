extends Node
## Il pet del giocatore (US-321): un solo pet per volta. Questo autoload tiene
## lo stato del pet ATTIVO (specie + bond/hp/sequenza correnti). Le specie
## sono dati (data/pets/, via GameData).
##
## Il pet E' un'Ancora: US-322 (doma) lo registra in AnchorSystem, US-325 (la
## sua morte) lo distrugge. Qui c'e' solo il magazzino + il round-trip del
## save; taming, bond dagli eventi e coltivazione sono US-322..324.
##
## NIENTE class_name: coerente col resto del progetto.

signal pet_impostato(pet_id: String)
signal pet_liberato(pet_id: String)
signal taming_fallito(pet_id: String)

## {} = nessun pet. Altrimenti { pet_id, bond, hp, sequenza }.
var _pet: Dictionary = {}
## RNG del taming (US-322). null -> randomize alla prima doma. Seedabile.
var _rng: RandomNumberGenerator = null


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _ancore() -> Node:
	return get_node_or_null("/root/AnchorSystem")


## {} se nessun pet. Copia: il chiamante non muta lo stato interno.
func pet_attivo() -> Dictionary:
	return _pet.duplicate(true)


## Imposta il pet attivo a partire da una specie. pet_id sconosciuto -> false
## e nessun cambiamento. bond parte da 0, hp e sequenza dai dati della specie.
func imposta_pet(pet_id: String) -> bool:
	var specie: Dictionary = _gd().call("get_pet", pet_id) if _gd() != null else {}
	if specie.is_empty():
		push_error("[PetSystem] specie sconosciuta: '%s' (vedi data/pets/)" % pet_id)
		return false
	_pet = {
		"pet_id": pet_id,
		"bond": 0,
		"hp": float(specie.get("hp_max", 1)),
		"sequenza": int(specie.get("sequenza_iniziale", 9)),
	}
	pet_impostato.emit(pet_id)
	return true


## Doma una creatura e la rende il pet attivo (US-322). Tiro seedabile contro
## domabilita + bonus (talenti/oggetti, US-33x li passeranno qui). Su successo:
## imposta_pet + l'Ancora del pet entra in AnchorSystem. Bloccato se hai gia'
## un pet: prima libera() quello. Restituisce true se la creatura e' stata
## domata.
func doma(pet_id: String, bonus: float = 0.0) -> bool:
	if not _pet.is_empty():
		push_warning("[PetSystem] hai gia' un pet: libera() prima di domarne un altro.")
		return false
	var specie: Dictionary = _gd().call("get_pet", pet_id) if _gd() != null else {}
	if specie.is_empty():
		push_error("[PetSystem] specie sconosciuta: '%s'" % pet_id)
		return false
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	var soglia: float = clampf(float(specie.get("domabilita", 0.0)) + bonus, 0.0, 1.0)
	if _rng.randf() >= soglia:
		taming_fallito.emit(pet_id)
		return false
	imposta_pet(pet_id)
	if _ancore() != null:
		_ancore().call("register", str(specie.get("ancora_id", "")))
	return true


## RNG del taming seedabile (US-322): stesso pattern di PotionSystem.
func imposta_seed(s: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = s


## Libera il pet attivo (US-322: serve prima di domarne un altro). Rilascio
## PULITO dell'Ancora: liberare non e' un colpo di follia (quello e' la morte
## del pet, US-325).
func libera() -> void:
	if _pet.is_empty():
		return
	var id: String = str(_pet.get("pet_id", ""))
	var anc: String = str((_gd().call("get_pet", id) as Dictionary).get("ancora_id", "")) if _gd() != null else ""
	_pet = {}
	if _ancore() != null and not anc.is_empty():
		_ancore().call("rilascia", anc)
	pet_liberato.emit(id)


func ha_pet() -> bool:
	return not _pet.is_empty()


func bond() -> int:
	return int(_pet.get("bond", 0))


## -1 se nessun pet.
func sequenza_pet() -> int:
	return int(_pet.get("sequenza", -1)) if not _pet.is_empty() else -1


func pulisci() -> void:
	_pet = {}


# --- Salvataggio --------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return _pet.duplicate(true)


## Rilettura NON FIDATA. pet_id assente/non stringa o specie non piu' nei dati
## -> nessun pet, errore gestito, non crash.
func da_salvataggio(raw: Variant) -> void:
	_pet = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	if d.is_empty():
		return
	var pet_id: Variant = d.get("pet_id")
	if typeof(pet_id) != TYPE_STRING or (pet_id as String).is_empty():
		return
	var specie: Dictionary = _gd().call("get_pet", pet_id) if _gd() != null else {}
	if specie.is_empty():
		push_warning("[PetSystem] specie '%s' non piu' nei dati: pet non ripristinato." % pet_id)
		return
	_pet = {
		"pet_id": str(pet_id),
		"bond": clampi(int(_num(d.get("bond"), 0)), 0, 100),
		"hp": _num(d.get("hp"), float(specie.get("hp_max", 1))),
		"sequenza": clampi(int(_num(d.get("sequenza"), specie.get("sequenza_iniziale", 9))), 0, 9),
	}


static func _num(v: Variant, fallback: float) -> float:
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else fallback
