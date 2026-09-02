extends Node
## Fonte unica dei dati di gioco.
##
## Carica i JSON di data/ e li espone come indici piatti per id. Ogni sistema
## legge da qui: nessuno deve aprire un file per conto proprio.
##
## Il reload (US-003) NON sostituisce i dizionari, li aggiorna sul posto: un
## sistema che si e' tenuto il riferimento a un'abilita' vede i valori nuovi
## invece di restare con quelli vecchi.

## Emesso a fine caricamento. errors > 0 significa che qualche file e' stato
## saltato: i dati caricati restano usabili, quelli rotti no.
signal data_reloaded(files_loaded: int, errors: int)

const DIR_PATHWAYS := "res://data/pathways"
const DIR_ABILITIES := "res://data/abilities"
const DIR_SYNERGIES := "res://data/synergies"
const PATH_TAGS := "res://data/tags.json"
const PATH_PRIMITIVES := "res://data/schema/primitives.json"

var _pathways: Dictionary = {}
var _sequences: Dictionary = {}
var _abilities: Dictionary = {}
var _synergies: Dictionary = {}
var _tags: Dictionary = {}
var _primitives: Dictionary = {}

var _errors: PackedStringArray = []
var _files_loaded: int = 0


func _ready() -> void:
	load_all()


## Ricarica tutto da disco. Chiamabile a caldo: vedi US-003.
func load_all() -> void:
	_errors = PackedStringArray()
	_files_loaded = 0

	_load_pathways()
	_load_abilities()
	_load_synergies()
	_load_single(PATH_TAGS, "tags", _tags)
	_load_single(PATH_PRIMITIVES, "primitives", _primitives)

	if _errors.is_empty():
		print("[GameData] %d file, %d pathway, %d sequenze, %d abilita'." % [
			_files_loaded, _pathways.size(), _sequences.size(), _abilities.size()
		])
	else:
		push_error("[GameData] %d file caricati, %d ERRORI:" % [_files_loaded, _errors.size()])
		for e in _errors:
			push_error("  " + e)

	data_reloaded.emit(_files_loaded, _errors.size())


# --- API pubblica ------------------------------------------------------------

## Restituisce {} se l'id non esiste: il chiamante controlla con is_empty().
func get_pathway(id: String) -> Dictionary:
	return _pathways.get(id, {})


func get_sequence(id: String) -> Dictionary:
	return _sequences.get(id, {})


func get_ability(id: String) -> Dictionary:
	return _abilities.get(id, {})


func get_synergy(id: String) -> Dictionary:
	return _synergies.get(id, {})


## Definizione di una primitiva dal registro chiuso di data/schema/.
## Vuoto = primitiva inesistente: e' un errore di dati, non un caso da gestire.
func get_primitive(tipo: String) -> Dictionary:
	var registry: Dictionary = _primitives.get("primitives", {})
	return registry.get(tipo, {})


## data/tags.json espone "tags" come ARRAY piatto di 82 stringhe, non come
## oggetto: e' un vocabolario chiuso, non una mappa di definizioni.
func has_tag(tag: String) -> bool:
	var vocab: Array = _tags.get("tags", [])
	return vocab.has(tag)


func tag_count() -> int:
	return (_tags.get("tags", []) as Array).size()


func pathway_ids() -> Array:
	return _pathways.keys()


func sequence_count() -> int:
	return _sequences.size()


func ability_count() -> int:
	return _abilities.size()


func last_errors() -> PackedStringArray:
	return _errors


func files_loaded() -> int:
	return _files_loaded


# --- Caricamento -------------------------------------------------------------

func _load_pathways() -> void:
	for path in _json_files_in(DIR_PATHWAYS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var pid: String = str(doc.get("id", ""))
		if pid.is_empty():
			_fail(path, "manca il campo 'id'")
			continue
		_upsert(_pathways, pid, doc)

		var seqs: Array = doc.get("sequences", [])
		for entry in seqs:
			var seq: Dictionary = entry
			var sid: String = str(seq.get("id", ""))
			if sid.is_empty():
				_fail(path, "una sequenza non ha 'id'")
				continue
			_upsert(_sequences, sid, seq)


func _load_abilities() -> void:
	for path in _json_files_in(DIR_ABILITIES):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var list: Array = doc.get("abilities", [])
		for entry in list:
			var ability: Dictionary = entry
			var aid: String = str(ability.get("id", ""))
			if aid.is_empty():
				_fail(path, "un'abilita' non ha 'id'")
				continue
			_upsert(_abilities, aid, ability)


func _load_synergies() -> void:
	for path in _json_files_in(DIR_SYNERGIES):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var list: Array = doc.get("synergies", [])
		for entry in list:
			var syn: Dictionary = entry
			var sid: String = str(syn.get("id", ""))
			if sid.is_empty():
				_fail(path, "una sinergia non ha 'id'")
				continue
			_upsert(_synergies, sid, syn)


func _load_single(path: String, key: String, target: Dictionary) -> void:
	var doc: Dictionary = _read_json(path)
	if doc.is_empty():
		return
	if not doc.has(key):
		_fail(path, "manca la chiave '%s'" % key)
		return
	# Sul posto, per non invalidare chi tiene gia' il riferimento.
	target.clear()
	target.merge(doc, true)


## Sostituisce il contenuto di index[id] SENZA cambiare l'oggetto Dictionary,
## cosi' chi ha gia' quel riferimento vede i dati nuovi. E' il cuore di US-003.
func _upsert(index: Dictionary, id: String, fresh: Dictionary) -> void:
	if index.has(id):
		var existing: Dictionary = index[id]
		existing.clear()
		existing.merge(fresh, true)
	else:
		index[id] = fresh


func _json_files_in(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir_path):
		_errors.append("cartella mancante: %s" % dir_path)
		return out
	var names: PackedStringArray = DirAccess.get_files_at(dir_path)
	for n in names:
		if n.ends_with(".json"):
			out.append(dir_path.path_join(n))
	out.sort()  # ordine stabile: gli errori sono riproducibili
	return out


## Vuoto = fallito. L'errore e' gia' registrato, mai silenzioso.
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_errors.append("file mancante: %s" % path)
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_errors.append("%s: impossibile aprire (errore %d)" % [path, FileAccess.get_open_error()])
		return {}

	var text: String = f.get_as_text()
	f.close()

	var parser := JSON.new()
	var err: int = parser.parse(text)
	if err != OK:
		_errors.append("%s: JSON malformato alla riga %d — %s" % [
			path, parser.get_error_line(), parser.get_error_message()
		])
		return {}

	if typeof(parser.data) != TYPE_DICTIONARY:
		_errors.append("%s: la radice non e' un oggetto JSON" % path)
		return {}

	_files_loaded += 1
	return parser.data


func _fail(path: String, msg: String) -> void:
	_errors.append("%s: %s" % [path, msg])
