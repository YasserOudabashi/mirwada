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
const PATH_BALANCE := "res://data/balance.json"
const PATH_PRIMITIVES := "res://data/schema/primitives.json"
const PATH_ANIMATIONS := "res://data/animations.json"
const PATH_AUDIO := "res://data/audio.json"
const PATH_FORMS := "res://data/forms.json"
const PATH_TRACKED_EVENTS := "res://data/schema/tracked_events.json"
const PATH_CHARACTERISTICS := "res://data/characteristics.json"
const PATH_FORMULAS := "res://data/potions/formulas.json"
const PATH_ANCHORS := "res://data/anchors.json"

## Categorie di animazione in animations.json (le stesse di
## generate_placeholders.py). Le altre chiavi di primo livello
## (convenzioni, budget_frame, _comment) non sono animazioni.
const ANIM_CATEGORIES: PackedStringArray = ["personaggio", "nemico_base", "pet"]

var _pathways: Dictionary = {}
var _sequences: Dictionary = {}
var _abilities: Dictionary = {}
var _synergies: Dictionary = {}
var _tags: Dictionary = {}
var _balance: Dictionary = {}
var _primitives: Dictionary = {}
var _animations: Dictionary = {}
var _audio: Dictionary = {}
var _forms: Dictionary = {}
var _tracked_events: Dictionary = {}
var _characteristics: Dictionary = {}
var _formulas: Dictionary = {}
var _anchors: Dictionary = {}

var _errors: PackedStringArray = []
var _files_loaded: int = 0


func _ready() -> void:
	load_all()


## F5 ricarica i dati a caldo. Solo in debug: in una build di release il
## tasto non fa nulla e i file non sono nemmeno piu' su disco separati.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F5:
		reload()
		get_viewport().set_input_as_handled()


## Ricarica da disco senza riavviare. I Dictionary gia' consegnati ai sistemi
## restano gli stessi oggetti, con dentro i valori nuovi: nessun riferimento
## si rompe. Vedi _upsert().
func reload() -> void:
	var before: int = _files_loaded
	load_all()
	print("[GameData] RELOAD: %d file ricaricati (prima erano %d), %d errori." % [
		_files_loaded, before, _errors.size()
	])


## Ricarica tutto da disco. Chiamabile a caldo: vedi US-003.
func load_all() -> void:
	_errors = PackedStringArray()
	_files_loaded = 0

	_load_pathways()
	_load_abilities()
	_load_synergies()
	# L'ultimo argomento e' il tipo atteso per la chiave: un file in cui quella
	# chiave ha la forma sbagliata viene scartato con un errore, non caricato.
	_load_single(PATH_TAGS, "tags", _tags, TYPE_ARRAY)
	_load_single(PATH_BALANCE, "hp_curve", _balance, TYPE_DICTIONARY)
	_load_single(PATH_PRIMITIVES, "primitives", _primitives, TYPE_DICTIONARY)
	_load_single(PATH_ANIMATIONS, "convenzioni", _animations, TYPE_DICTIONARY)
	_load_single(PATH_AUDIO, "buses", _audio, TYPE_DICTIONARY)
	_load_single(PATH_FORMS, "forms", _forms, TYPE_DICTIONARY)
	_load_single(PATH_TRACKED_EVENTS, "events", _tracked_events, TYPE_DICTIONARY)
	_load_single(PATH_CHARACTERISTICS, "characteristics", _characteristics, TYPE_ARRAY)
	_load_single(PATH_FORMULAS, "formulas", _formulas, TYPE_DICTIONARY)
	_load_single(PATH_ANCHORS, "anchors", _anchors, TYPE_ARRAY)

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
	var registry: Dictionary = _dict_or_empty(_primitives.get("primitives"))
	return _dict_or_empty(registry.get(tipo))


## data/tags.json espone "tags" come ARRAY piatto di 82 stringhe, non come
## oggetto: e' un vocabolario chiuso, non una mappa di definizioni.
func has_tag(tag: String) -> bool:
	return _array_or_empty(_tags.get("tags")).has(tag)


## Curve globali di bilanciamento. Tenute nei dati perche' sono i numeri
## destinati a cambiare di piu' durante il playtest.
func get_balance(section: String) -> Dictionary:
	return _dict_or_empty(_balance.get(section))


## Valore di una curva per Sequenza (9 = piu' bassa, 0 = Vero Dio).
## Le chiavi in JSON sono stringhe, non interi: da qui la conversione.
func curve_value(section: String, sequence: int, fallback: float) -> float:
	var curve: Dictionary = _dict_or_empty(_balance.get(section))
	return _num_or(curve.get(str(sequence)), fallback)


func tag_count() -> int:
	return _array_or_empty(_tags.get("tags")).size()


## --- Animazioni (data/animations.json) ---
## Il codice implementa una macchina di stati generica; questo file decide
## frame, fps, fasi del combat ed eventi. La vista tipata e' AnimationSpec
## (scripts/animation_spec.gd), costruita su questi Dictionary.

## Voce grezza per (categoria, nome), es. ("personaggio", "walk"). {} se
## non esiste.
func get_animation(categoria: String, nome: String) -> Dictionary:
	var cat: Dictionary = _dict_or_empty(_animations.get(categoria))
	return _dict_or_empty(cat.get(nome))


## Valore di convenzioni.<key> (dimensione_frame, direzioni, fps_default...).
func animation_convention(key: String) -> Variant:
	var conv: Dictionary = _dict_or_empty(_animations.get("convenzioni"))
	return conv.get(key, null)


## Categorie effettivamente presenti nel file.
func animation_categories() -> Array:
	var out: Array = []
	for c in ANIM_CATEGORIES:
		if _animations.has(c):
			out.append(c)
	return out


## Nomi delle animazioni di una categoria (esclude le chiavi di commento _*).
func animation_names(categoria: String) -> Array:
	var out: Array = []
	for k in _dict_or_empty(_animations.get(categoria)):
		if not str(k).begins_with("_"):
			out.append(k)
	return out


## --- Audio (data/audio.json) ---
## Sezione di primo livello: buses, combat_feedback, telegraph, accessibilita...
func get_audio(sezione: String) -> Dictionary:
	return _dict_or_empty(_audio.get(sezione))


## --- Forme (data/forms.json) ---
## Definizione di una forma della primitiva "transform". {} = forma_id ignoto:
## e' un errore di dati (il validator lo intercetta), non un caso da gestire.
func get_form(forma_id: String) -> Dictionary:
	var registry: Dictionary = _dict_or_empty(_forms.get("forms"))
	return _dict_or_empty(registry.get(forma_id))


## --- Eventi tracciabili (data/schema/tracked_events.json) ---
## Vocabolario CHIUSO di 12: l'EventTracker (US-210) conta solo questi.
func get_tracked_events() -> Dictionary:
	return _dict_or_empty(_tracked_events.get("events"))


func get_tracked_event(nome: String) -> Dictionary:
	return _dict_or_empty(get_tracked_events().get(nome))


## --- Caratteristiche Beyonder (data/characteristics.json) ---
func get_characteristic(id: String) -> Dictionary:
	for c in _array_or_empty(_characteristics.get("characteristics")):
		if typeof(c) == TYPE_DICTIONARY and str((c as Dictionary).get("id", "")) == id:
			return c
	return {}


## --- Formule delle pozioni (data/potions/formulas.json) ---
func get_formula(formula_id: String) -> Dictionary:
	return _dict_or_empty(_dict_or_empty(_formulas.get("formulas")).get(formula_id))


## Vocabolario chiuso degli ingredienti.
func ingredient_ids() -> Array:
	return _array_or_empty(_formulas.get("ingredients"))


## --- Ancore (data/anchors.json) ---
func get_anchors() -> Array:
	return _array_or_empty(_anchors.get("anchors"))


func get_anchor(id: String) -> Dictionary:
	for a in get_anchors():
		if typeof(a) == TYPE_DICTIONARY and str((a as Dictionary).get("id", "")) == id:
			return a
	return {}


## La Caratteristica di quel (Pathway, Sequenza). {} se non esiste.
func characteristic_for(pathway_id: String, sequence: int) -> Dictionary:
	for c in _array_or_empty(_characteristics.get("characteristics")):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = c
		if str(d.get("pathway_id", "")) == pathway_id and int(d.get("sequence", -1)) == sequence:
			return d
	return {}


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
	var visti_p: Dictionary = {}
	var visti_s: Dictionary = {}
	for path in _json_files_in(DIR_PATHWAYS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var pid: String = str(doc.get("id", ""))
		if pid.is_empty():
			_fail(path, "manca il campo 'id'")
			continue
		_upsert(_pathways, pid, doc)
		visti_p[pid] = true

		for entry in _object_list(doc, "sequences", path):
			var seq: Dictionary = entry
			var sid: String = str(seq.get("id", ""))
			if sid.is_empty():
				_fail(path, "una sequenza non ha 'id'")
				continue
			_upsert(_sequences, sid, seq)
			visti_s[sid] = true
	_prune(_pathways, visti_p)
	_prune(_sequences, visti_s)


func _load_abilities() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_ABILITIES):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		for entry in _object_list(doc, "abilities", path):
			var ability: Dictionary = entry
			var aid: String = str(ability.get("id", ""))
			if aid.is_empty():
				_fail(path, "un'abilita' non ha 'id'")
				continue
			_upsert(_abilities, aid, ability)
			visti[aid] = true
	_prune(_abilities, visti)


func _load_synergies() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_SYNERGIES):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		for entry in _object_list(doc, "synergies", path):
			var syn: Dictionary = entry
			var sid: String = str(syn.get("id", ""))
			if sid.is_empty():
				_fail(path, "una sinergia non ha 'id'")
				continue
			_upsert(_synergies, sid, syn)
			visti[sid] = true
	_prune(_synergies, visti)


func _load_single(path: String, key: String, target: Dictionary, key_type: int) -> void:
	var doc: Dictionary = _read_json(path)
	if doc.is_empty():
		return
	if not doc.has(key):
		_fail(path, "manca la chiave '%s'" % key)
		return
	if typeof(doc[key]) != key_type:
		_fail(path, "la chiave '%s' dovrebbe essere %s, e' %s: file scartato" % [
			key, type_string(key_type), type_string(typeof(doc[key]))
		])
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


## Toglie dall'indice le voci che questo caricamento NON ha visto: un id
## cancellato o rinominato nei JSON sparisce dopo un reload invece di restare
## in memoria per sempre. Le voci ancora presenti non si toccano — _upsert ne
## ha gia' aggiornato il contenuto sul posto, quindi i riferimenti tenuti dai
## sistemi restano validi (il criterio di US-003).
func _prune(index: Dictionary, visti: Dictionary) -> void:
	for id in index.keys():
		if not visti.has(id):
			index.erase(id)


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


# --- Coercizioni difensive -------------------------------------------------
# I JSON restano in chiaro nell'export e chiunque puo' modificarli. Un file
# sintatticamente valido ma strutturalmente storto (una lista dov'era atteso
# un oggetto, un elemento non-oggetto in una lista) non deve mai arrivare a
# un'assegnazione tipata: in GDScript e' un errore che interrompe il ciclo di
# caricamento a meta'. Questi helper registrano l'anomalia — come _read_json —
# e restituiscono un default sano, cosi' il resto dei dati si carica lo stesso.

## container[key] come Array. Assente -> []. Presente ma non Array -> errore + [].
func _as_array(container: Dictionary, key: String, where: String) -> Array:
	if not container.has(key):
		return []
	var v: Variant = container[key]
	if typeof(v) != TYPE_ARRAY:
		_fail(where, "'%s' dovrebbe essere una lista, e' %s" % [key, type_string(typeof(v))])
		return []
	return v


## Solo gli elementi-oggetto di container[key]. Registra un errore per ogni
## elemento scartato perche' non e' un oggetto.
func _object_list(container: Dictionary, key: String, where: String) -> Array:
	var out: Array = []
	for entry in _as_array(container, key, where):
		if typeof(entry) != TYPE_DICTIONARY:
			_fail(where, "'%s': elemento non-oggetto scartato (%s)" % [key, entry])
			continue
		out.append(entry)
	return out


static func _dict_or_empty(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _array_or_empty(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


static func _num_or(v: Variant, fallback: float) -> float:
	return v if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) else fallback
