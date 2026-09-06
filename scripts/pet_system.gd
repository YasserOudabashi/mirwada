extends Node
## Il pet del giocatore (US-321): un solo pet per volta. Questo autoload tiene
## lo stato del pet ATTIVO (specie + bond/hp/sequenza correnti). Le specie
## sono dati (data/pets/, via GameData).
##
## Il pet E' un'Ancora: US-322 (doma) lo registra in AnchorSystem, US-325 (la
## sua morte) lo distrugge. US-323: il bond 0..100 sale ascoltando
## EventTracker mentre hai un pet e a soglia (per specie) sblocca comportamenti.
##
## NIENTE class_name: coerente col resto del progetto.

signal pet_impostato(pet_id: String)
signal pet_liberato(pet_id: String)
signal taming_fallito(pet_id: String)
## comportamento_sbloccato = "" se nessuna soglia attraversata da questo colpo.
signal bond_cambiato(valore: int, comportamento_sbloccato: String)
signal pet_avanzato(sequenza: int)

## {} = nessun pet. Altrimenti { pet_id, bond, hp, sequenza }.
var _pet: Dictionary = {}
## RNG del taming (US-322). null -> randomize alla prima doma. Seedabile.
var _rng: RandomNumberGenerator = null


func _ready() -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null and et.has_signal("evento_emesso"):
		et.evento_emesso.connect(_su_evento)


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _ancore() -> Node:
	return get_node_or_null("/root/AnchorSystem")


func _inv() -> Node:
	return get_node_or_null("/root/Inventory")


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


# --- Bond (US-323) -----------------------------------------------------

## I comportamenti della specie gia' sbloccati al bond corrente (id).
## Ordinati per soglia crescente.
func comportamenti_sbloccati() -> Array:
	if _pet.is_empty():
		return []
	var b: int = bond()
	var out: Array = []
	for c in _comportamenti_specie():
		if b >= int(c.get("bond", 0)):
			out.append(str(c.get("id", "")))
	return out


## Fissa il bond a un valore assoluto (0..100). Debug / US-324. Passa dalla
## stessa logica di soglia di un incremento da eventi.
func imposta_bond(valore: int) -> void:
	if _pet.is_empty():
		return
	_applica_bond(clampi(valore, 0, 100))


func pulisci() -> void:
	_pet = {}


## enemy_defeated / area_cleared mentre hai un pet -> il bond sale (pesi in
## balance.json.pet_bond). Gli altri eventi non contano per il legame.
## enemy_defeated: il gate "mentre il pet e' evocato" e' per ora "hai un pet"
## (la scena del pet arriva piu' avanti). time_in_state "esplorazione" del PRD
## non c'e': non e' nel vocabolario chiuso dei 12 eventi e aggiungerlo sarebbe
## codice da discutere. enemy_defeated + area_cleared bastano (combattimento
## condiviso).
func _su_evento(nome: String, _dati: Dictionary) -> void:
	if _pet.is_empty():
		return
	var pesi: Dictionary = _gd().call("get_balance", "pet_bond") if _gd() != null else {}
	match nome:
		"enemy_defeated":
			_applica_bond(bond() + int(pesi.get("per_nemico_sconfitto", 0)))
		"area_cleared":
			_applica_bond(bond() + int(pesi.get("per_area_completata", 0)))


func _applica_bond(nuovo: int) -> void:
	var vecchio: int = bond()
	nuovo = clampi(nuovo, 0, 100)
	if nuovo == vecchio:
		return
	_pet["bond"] = nuovo
	# soglie attraversate salendo: vecchio < soglia <= nuovo
	var sbloccato: String = ""
	if nuovo > vecchio:
		for c in _comportamenti_specie():
			var s: int = int(c.get("bond", 0))
			if vecchio < s and s <= nuovo:
				sbloccato = str(c.get("id", ""))
	bond_cambiato.emit(nuovo, sbloccato)


## --- Coltivazione (US-324) ---

## Fa salire il pet di una Sequenza (9 -> 0). Serve:
##   - bond >= avanzamento.soglia_bond (dai dati della specie)
##   - una unita' di avanzamento.nutrimento nell'inventario (consumata)
##   - la nuova Sequenza NON deve superare quella del giocatore (il pet non
##     supera il padrone) ne' scendere sotto 0
## hp del pet aggiornato da avanzamento.hp_per_sequenza (curva nei dati).
## Restituisce true se il pet e' avanzato.
func avanza_pet() -> bool:
	if _pet.is_empty():
		return false
	var specie: Dictionary = _gd().call("get_pet", str(_pet.get("pet_id", ""))) if _gd() != null else {}
	var av: Dictionary = specie.get("avanzamento", {})
	if av.is_empty():
		return false
	if bond() < int(av.get("soglia_bond", 101)):
		return false
	var nuova: int = sequenza_pet() - 1
	if nuova < 0:
		return false
	var prog: Node = get_node_or_null("/root/Progression")
	var seq_giocatore: int = int(prog.call("sequence")) if prog != null else 9
	if nuova < seq_giocatore:
		push_warning("[PetSystem] il pet non puo' superare la Sequenza del giocatore (%d)." % seq_giocatore)
		return false
	var cibo: String = str(av.get("nutrimento", ""))
	if _inv() == null or int(_inv().call("conta", cibo)) < 1:
		return false
	_inv().call("rimuovi", cibo, 1)

	_pet["sequenza"] = nuova
	var curva: Dictionary = av.get("hp_per_sequenza", {})
	if curva.has(str(nuova)):
		_pet["hp"] = float(curva[str(nuova)])
	pet_avanzato.emit(nuova)
	return true


func _comportamenti_specie() -> Array:
	if _pet.is_empty() or _gd() == null:
		return []
	var specie: Dictionary = _gd().call("get_pet", str(_pet.get("pet_id", "")))
	var lista: Array = (specie.get("comportamenti", []) as Array).duplicate()
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("bond", 0)) < int(b.get("bond", 0)))
	return lista


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
