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
## Fase 9 (US-902): Pathway Non-Standard (Boon). Puo' non esistere ancora
## (nessun file finche' una story non ne scrive uno, es. Eternal Aeon) -
## a differenza di DIR_PATHWAYS, una cartella assente qui NON e' un errore.
const DIR_PATHWAYS_NON_STANDARD := "res://data/pathways_non_standard"
const DIR_ABILITIES := "res://data/abilities"
const DIR_SYNERGIES := "res://data/synergies"
const DIR_FUSIONS := "res://data/fusions"
const DIR_TRIBULATIONS := "res://data/tribulations"
const DIR_ITEMS := "res://data/items"
const DIR_STRUCTURES := "res://data/structures"
const DIR_PETS := "res://data/pets"
const PATH_ROOM_TYPES := "res://data/schema/room_types.json"
const PATH_ROOMS := "res://data/base/rooms.json"
const PATH_TRACKED_TALENTS := "res://data/schema/tracked_talents.json"
const DIR_TALENTS := "res://data/talents"
const DIR_DIALOGUES := "res://data/dialogues"
const DIR_QUESTS := "res://data/quests"
const DIR_LAYOUTS := "res://data/world/layouts"
const PATH_TAGS := "res://data/tags.json"
const PATH_BALANCE := "res://data/balance.json"
const PATH_PRIMITIVES := "res://data/schema/primitives.json"
const PATH_ANIMATIONS := "res://data/animations.json"
const PATH_AUDIO := "res://data/audio.json"
const PATH_FORMS := "res://data/forms.json"
const PATH_TRACKED_EVENTS := "res://data/schema/tracked_events.json"
const PATH_CHARACTERISTICS := "res://data/characteristics.json"
const PATH_FORMULAS := "res://data/potions/formulas.json"
const PATH_RECIPES := "res://data/potions/recipes.json"
const PATH_POTION_QUALITY := "res://data/schema/potion_quality.json"
const PATH_EXPERIMENT_OUTCOMES := "res://data/potions/experiment_outcomes.json"
const PATH_ANCHORS := "res://data/anchors.json"
const PATH_STATUS := "res://data/status_effects.json"
## Cataloghi di stringhe DEI DATI (US-220). Sistema separato dal tr() di Godot
## (assets/i18n/strings.csv), che copre solo la UI chrome. Vedi CLAUDE.md.
const PATH_I18N_IT := "res://data/i18n/it.json"
const PATH_I18N_EN := "res://data/i18n/en.json"
const PATH_UI_BOOK := "res://data/ui/book.json"
const PATH_PAGE_TYPES := "res://data/schema/page_types.json"
const PATH_VFX := "res://data/vfx.json"
const PATH_ITEM_CATEGORIES := "res://data/schema/item_categories.json"
const PATH_EQUIP_SLOTS := "res://data/schema/equip_slots.json"
const PATH_SIGILS := "res://data/sigils/core.json"
const PATH_SIGIL_EFFECT_TYPES := "res://data/schema/sigil_effect_types.json"
const PATH_BLUEPRINTS := "res://data/forge/blueprints.json"
const PATH_REGIONS := "res://data/world/regions.json"
const PATH_ROSTER := "res://data/npc/roster.json"
const PATH_FACTIONS := "res://data/factions.json"
const PATH_ANTAGONISTI := "res://data/lore/antagonisti.json"
const PATH_ENDINGS := "res://data/endings.json"

## Categorie di animazione in animations.json (le stesse di
## generate_placeholders.py). Le altre chiavi di primo livello
## (convenzioni, budget_frame, _comment) non sono animazioni.
const ANIM_CATEGORIES: PackedStringArray = ["personaggio", "nemico_base", "pet"]

var _pathways: Dictionary = {}
var _sequences: Dictionary = {}
var _abilities: Dictionary = {}
var _synergies: Dictionary = {}
## Percorsi di fusione (data/fusions/, fase 7). _fusions: doc per id
## "<pathA>_<pathB>". _fusion_abilities: le abilita' fuse dei percorsi NON stub,
## indicizzate per il loro id "fus_...", cosi' get_ability() le risolve come
## un'abilita' qualsiasi senza che finiscano in ability_ids()/ability_count().
var _fusions: Dictionary = {}
var _fusion_abilities: Dictionary = {}
## Tribolazioni ai salti di fascia (data/tribulations/, fase 7). Doc per id.
var _tribulations: Dictionary = {}
var _tags: Dictionary = {}
var _balance: Dictionary = {}
var _primitives: Dictionary = {}
var _animations: Dictionary = {}
var _audio: Dictionary = {}
var _forms: Dictionary = {}
var _tracked_events: Dictionary = {}
var _characteristics: Dictionary = {}
var _formulas: Dictionary = {}
var _recipes: Dictionary = {}
var _potion_quality: Dictionary = {}
var _experiment_outcomes: Dictionary = {}
var _anchors: Dictionary = {}
var _statuses: Dictionary = {}
var _i18n_it: Dictionary = {}
var _i18n_en: Dictionary = {}
var _ui_book: Dictionary = {}
var _page_types: Dictionary = {}
var _vfx: Dictionary = {}
var _items: Dictionary = {}
var _structures: Dictionary = {}
var _pets: Dictionary = {}
var _room_types: Dictionary = {}
var _rooms: Dictionary = {}
var _tracked_talents: Dictionary = {}
var _talents: Dictionary = {}
var _item_categories: Dictionary = {}
var _equip_slots: Dictionary = {}
var _sigils: Dictionary = {}
var _sigil_effect_types: Dictionary = {}
var _blueprints: Dictionary = {}
var _regions: Dictionary = {}
var _roster: Dictionary = {}
var _dialogues: Dictionary = {}
var _factions: Dictionary = {}
var _quests: Dictionary = {}
var _layouts: Dictionary = {}
var _antagonisti: Dictionary = {}
var _endings: Dictionary = {}

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
	_load_fusions()
	_load_tribulations()
	_load_items()
	_load_structures()
	_load_pets()
	_load_talents()
	_load_dialogues()
	_load_quests()
	_load_layouts()
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
	_load_single(PATH_RECIPES, "recipes", _recipes, TYPE_DICTIONARY)
	_load_single(PATH_POTION_QUALITY, "qualita", _potion_quality, TYPE_ARRAY)
	_load_single(PATH_EXPERIMENT_OUTCOMES, "outcomes", _experiment_outcomes, TYPE_DICTIONARY)
	_load_single(PATH_ANCHORS, "anchors", _anchors, TYPE_ARRAY)
	_load_single(PATH_STATUS, "statuses", _statuses, TYPE_DICTIONARY)
	_load_flat(PATH_I18N_IT, _i18n_it)
	_load_flat(PATH_I18N_EN, _i18n_en)
	_load_single(PATH_UI_BOOK, "pages", _ui_book, TYPE_ARRAY)
	_load_single(PATH_PAGE_TYPES, "page_types", _page_types, TYPE_ARRAY)
	_load_single(PATH_VFX, "pathway_palette_visiva", _vfx, TYPE_DICTIONARY)
	_load_single(PATH_ITEM_CATEGORIES, "item_categories", _item_categories, TYPE_ARRAY)
	_load_single(PATH_EQUIP_SLOTS, "slots", _equip_slots, TYPE_ARRAY)
	_load_single(PATH_ROOM_TYPES, "tipi", _room_types, TYPE_ARRAY)
	_load_single(PATH_ROOMS, "rooms", _rooms, TYPE_DICTIONARY)
	_load_single(PATH_TRACKED_TALENTS, "talents", _tracked_talents, TYPE_DICTIONARY)
	_load_single(PATH_SIGILS, "sigils", _sigils, TYPE_DICTIONARY)
	_load_single(PATH_SIGIL_EFFECT_TYPES, "effetti", _sigil_effect_types, TYPE_ARRAY)
	_load_single(PATH_BLUEPRINTS, "blueprints", _blueprints, TYPE_DICTIONARY)
	_load_single(PATH_REGIONS, "regions", _regions, TYPE_ARRAY)
	_load_single(PATH_ROSTER, "npcs", _roster, TYPE_ARRAY)
	_load_single(PATH_FACTIONS, "factions", _factions, TYPE_ARRAY)
	_load_single(PATH_ANTAGONISTI, "antagonisti", _antagonisti, TYPE_ARRAY)
	_load_single(PATH_ENDINGS, "endings", _endings, TYPE_ARRAY)

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
	# Ramo separato per le abilita' fuse (fase 7): un id "fus_*" non e' legato a
	# una Sequenza, ma esegue come ogni altra abilita'.
	if _abilities.has(id):
		return _abilities[id]
	return _fusion_abilities.get(id, {})


## Il percorso di fusione con quell'id ("<pathA>_<pathB>"). {} se non esiste.
func get_fusion(id: String) -> Dictionary:
	return _fusions.get(id, {})


func fusion_ids() -> Array:
	return _fusions.keys()


## --- Tribolazioni (data/tribulations/, fase 7 US-710) ---
func get_tribulation(id: String) -> Dictionary:
	return _tribulations.get(id, {})


func tribulation_ids() -> Array:
	return _tribulations.keys()


## La tribolazione del salto che PARTE dalla Sequenza `da` (7/5/3/1). {} se
## nessuna. Il validator garantisce che ce ne sia una sola per salto.
func tribulation_per_salto(da: int) -> Dictionary:
	for t in _tribulations.values():
		if int((t as Dictionary).get("salto", {}).get("da", -1)) == da:
			return t
	return {}


func ability_ids() -> Array:
	return _abilities.keys()


## --- Strutture costruibili (data/structures/, US-319) ---
## Il tipo. Le istanze piazzate stanno in StructureRegistry.
func get_structure(id: String) -> Dictionary:
	return _structures.get(id, {})


func structure_ids() -> Array:
	return _structures.keys()


## --- Specie di pet (data/pets/, US-321) ---
## Lo stato del pet attivo del giocatore sta in PetSystem.
func get_pet(id: String) -> Dictionary:
	return _pets.get(id, {})


func pet_ids() -> Array:
	return _pets.keys()


## --- Base building (data/base/, data/schema/room_types.json, US-326) ---
## Il tipo di stanza dai dati (name/name_i18n/livelli). {} se ignoto.
func get_room_type(tipo: String) -> Dictionary:
	return _dict_or_empty(_dict_or_empty(_rooms.get("rooms")).get(tipo))


## I livelli di una stanza (indice 0 = livello 1). [] se tipo ignoto.
func room_levels(tipo: String) -> Array:
	return _array_or_empty(get_room_type(tipo).get("livelli"))


## Vocabolario chiuso dei 4 tipi di stanza.
func room_type_ids() -> Array:
	return _array_or_empty(_room_types.get("tipi"))


## Le chiavi di bonus ammesse per un tipo di stanza (vocabolario chiuso).
func room_bonus_ammessi(tipo: String) -> Array:
	return _array_or_empty(_dict_or_empty(_room_types.get("bonus_ammessi")).get(tipo))


## --- Talenti (data/talents/, data/schema/tracked_talents.json, US-330) ---
func get_talent(id: String) -> Dictionary:
	return _talents.get(id, {})


## I comportamenti-talento: vocabolario chiuso che i 12 eventi non catturano.
func tracked_talents() -> Dictionary:
	return _dict_or_empty(_tracked_talents.get("talents"))


func talents_per_tipo(tipo: String) -> Array:
	var out: Array = []
	for id in _talents:
		if str((_talents[id] as Dictionary).get("tipo", "")) == tipo:
			out.append(id)
	out.sort()
	return out


func talent_ids() -> Array:
	return _talents.keys()


func get_synergy(id: String) -> Dictionary:
	return _synergies.get(id, {})


func synergy_ids() -> Array:
	return _synergies.keys()


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


## Vocabolario chiuso degli ingredienti (delle pozioni di AVANZAMENTO, fase 2).
func ingredient_ids() -> Array:
	return _array_or_empty(_formulas.get("ingredients"))


## --- Ricette delle pozioni consumabili (data/potions/recipes.json, US-308) ---
## Percorso separato dalle formule di avanzamento. {} se l'id non esiste.
func get_recipe(id: String) -> Dictionary:
	return _dict_or_empty(_dict_or_empty(_recipes.get("recipes")).get(id))


func recipe_ids() -> Array:
	return _dict_or_empty(_recipes.get("recipes")).keys()


func recipes_per_tier(tier: String) -> Array:
	var out: Array = []
	for id in _dict_or_empty(_recipes.get("recipes")):
		if str((_recipes["recipes"][id] as Dictionary).get("tier", "")) == tier:
			out.append(id)
	out.sort()  # ordine stabile: la biblioteca (US-327) sblocca le prime N
	return out


## Vocabolario chiuso della qualita' delle pozioni (crescente).
func potion_quality() -> Array:
	return _array_or_empty(_potion_quality.get("qualita"))


## Esiti chiusi di un esperimento fallito (data/potions/experiment_outcomes.json).
func experiment_outcomes() -> Dictionary:
	return _dict_or_empty(_experiment_outcomes.get("outcomes"))


## --- Ancore (data/anchors.json) ---
func get_anchors() -> Array:
	return _array_or_empty(_anchors.get("anchors"))


func get_anchor(id: String) -> Dictionary:
	for a in get_anchors():
		if typeof(a) == TYPE_DICTIONARY and str((a as Dictionary).get("id", "")) == id:
			return a
	return {}


## --- Status sulle entita' (data/status_effects.json) ---
func get_status_effect(id: String) -> Dictionary:
	return _dict_or_empty(_dict_or_empty(_statuses.get("statuses")).get(id))


## --- Stringhe dei dati (data/i18n/, US-220) ---
## Risolve una chiave *_i18n presa da un file di dati. Ordine: catalogo della
## lingua richiesta -> catalogo italiano -> la chiave stessa (mai stringa
## vuota, mai crash). locale "" = lingua corrente di TranslationServer.
## NON usare per la UI chrome (HUD): quella passa da tr()/strings.csv.
func tr_data(key: String, locale: String = "") -> String:
	if key.is_empty():
		return ""
	var lang: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	if lang.begins_with("en") and _i18n_en.has(key):
		return str(_i18n_en[key])
	if _i18n_it.has(key):
		return str(_i18n_it[key])
	return key


## true se la chiave ha una traduzione italiana vera (non uno stub "TODO ...").
func has_translation(key: String) -> bool:
	return _i18n_it.has(key) and not str(_i18n_it[key]).begins_with("TODO ")


func i18n_keys() -> Array:
	return _i18n_it.keys()


## --- Libro / UI (data/ui/book.json, US-221) ---
## Documento completo: { libro:{}, pages:[], segnalibri:[] }. Il BookController
## (autoload Book) e' l'unico lettore.
func get_ui_book() -> Dictionary:
	return _ui_book


## Vocabolario chiuso degli 8 tipi di pagina (data/schema/page_types.json).
func page_types() -> Array:
	return _array_or_empty(_page_types.get("page_types"))


## --- Oggetti (data/items/, US-301) ---
## Ogni cosa che il giocatore raccoglie e' un item con una categoria. {} se
## l'id non esiste.
func get_item(id: String) -> Dictionary:
	return _items.get(id, {})


func item_categories() -> Array:
	return _array_or_empty(_item_categories.get("item_categories"))


func items_per_categoria(categoria: String) -> Array:
	var out: Array = []
	for id in _items:
		if str((_items[id] as Dictionary).get("categoria", "")) == categoria:
			out.append(_items[id])
	return out


func item_ids() -> Array:
	return _items.keys()


## Vocabolari degli slot di equipaggiamento (data/schema/equip_slots.json).
func equip_slots() -> Array:
	return _array_or_empty(_equip_slots.get("slots"))


func equip_slot_tipi() -> Array:
	return _array_or_empty(_equip_slots.get("tipi"))


## --- Sigilli (data/sigils/, US-315) ---
## La definizione di effetto/effetto_collaterale. La voce d'inventario (che
## la referenzia via sigillo_ref) sta in data/items/.
func get_sigil(id: String) -> Dictionary:
	return _dict_or_empty(_sigils.get("sigils")).get(id, {})


func sigil_ids() -> Array:
	return _dict_or_empty(_sigils.get("sigils")).keys()


## Vocabolario chiuso dei tipi di effetto/effetto_collaterale dei sigilli.
func sigil_effect_types(collaterale: bool = false) -> Array:
	return _array_or_empty(_sigil_effect_types.get("effetti_collaterali" if collaterale else "effetti"))


## --- Blueprint di forgiatura (data/forge/blueprints.json, US-316) ---
func get_blueprint(id: String) -> Dictionary:
	return _dict_or_empty(_blueprints.get("blueprints")).get(id, {})


func blueprint_ids() -> Array:
	return _dict_or_empty(_blueprints.get("blueprints")).keys()


## --- VFX (data/vfx.json, US-226) ---
## Gemello visivo di audio.json.pathway_palette. Un renderer per primitiva +
## una palette per Pathway; nessun campo VFX sulle abilita'.
func get_vfx_palette(pathway_id: String) -> Dictionary:
	return _dict_or_empty(_dict_or_empty(_vfx.get("pathway_palette_visiva")).get(pathway_id))


## Gli id delle 10 palette, nell'ordine di data/vfx.json (US-813: la riga
## del tileset per un Pathway e' 1 + l'indice qui dentro).
func vfx_palette_ids() -> Array:
	return _dict_or_empty(_vfx.get("pathway_palette_visiva")).keys()


func get_primitive_vfx(tipo: String) -> Dictionary:
	return _dict_or_empty(_dict_or_empty(_vfx.get("primitive_vfx")).get(tipo))


func get_vfx(sezione: String) -> Dictionary:
	return _dict_or_empty(_vfx.get(sezione))


## --- Regioni del mondo (data/world/regions.json, US-601) ---
func get_regions() -> Array:
	return _array_or_empty(_regions.get("regions"))


## {} se l'id non esiste: il chiamante controlla con is_empty().
func get_region(id: String) -> Dictionary:
	for r in get_regions():
		if typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("id", "")) == id:
			return r
	return {}


## --- NPC (data/npc/roster.json, US-612) ---
func get_npcs() -> Array:
	return _array_or_empty(_roster.get("npcs"))


## {} se l'id non esiste: il chiamante controlla con is_empty().
func get_npc(id: String) -> Dictionary:
	for n in get_npcs():
		if typeof(n) == TYPE_DICTIONARY and str((n as Dictionary).get("id", "")) == id:
			return n
	return {}


## Il grafo di un dialogo (data/dialogues/, US-613). {} se non esiste.
func get_dialogue(id: String) -> Dictionary:
	return _dialogues.get(id, {})


## --- Fazioni (data/factions.json, US-615) ---
func get_factions() -> Array:
	return _array_or_empty(_factions.get("factions"))


func get_faction(id: String) -> Dictionary:
	for f in get_factions():
		if typeof(f) == TYPE_DICTIONARY and str((f as Dictionary).get("id", "")) == id:
			return f
	return {}


## --- Quest (data/quests/, US-616) ---
func get_quests() -> Array:
	return _quests.values()


func get_quest(id: String) -> Dictionary:
	return _quests.get(id, {})


## --- Layout disegnati a mano (data/world/layouts/, US-805) ---
## {} se la regione non ha un layout: il chiamante usa il fallback piatto.
func get_layout(region_id: String) -> Dictionary:
	return _layouts.get(region_id, {})


## --- Antagonisti (data/lore/antagonisti.json, US-620) ---
func get_antagonisti() -> Array:
	return _array_or_empty(_antagonisti.get("antagonisti"))


## L'antagonista del Pathway dato (il detentore precedente della sua Seq 0).
func get_antagonista(pathway_id: String) -> Dictionary:
	for a in get_antagonisti():
		if typeof(a) == TYPE_DICTIONARY and str((a as Dictionary).get("pathway_id", "")) == pathway_id:
			return a
	return {}


## --- Finali (data/endings.json, fase 7 US-716) ---
func get_endings() -> Array:
	return _array_or_empty(_endings.get("endings"))


func get_ending(id: String) -> Dictionary:
	for e in get_endings():
		if typeof(e) == TYPE_DICTIONARY and str((e as Dictionary).get("id", "")) == id:
			return e
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
	var percorsi: PackedStringArray = _json_files_in(DIR_PATHWAYS)
	percorsi.append_array(_json_files_in(DIR_PATHWAYS_NON_STANDARD, false))
	for path in percorsi:
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var pid: String = str(doc.get("id", ""))
		if pid.is_empty():
			_fail(path, "manca il campo 'id'")
			continue
		# US-902: pathway_ids()/_pathways restano SOLO gli standard - ogni
		# sistema che "itera su ogni Pathway attivo" (VFX, diagramma, siti
		# rituali, i18n, gli slice) assume quell'universo, e cambiarlo qui
		# e' fuori scope per questa story (arrivera' quando US-904 scrive
		# Eternal Aeon e va deciso esplicitamente dove farlo comparire). Le
		# Sequenze restano visibili a tutti: e' quel che serve a Progression/
		# BoonSystem per risolvere sequence_data() su un Pathway non_standard.
		if str(doc.get("categoria", "standard")) == "standard":
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


## US-613: un file per dialogo (data/dialogues/dlg_*.json), l'oggetto e' il
## grafo intero ({id, start, nodes}). Chiave = doc.id.
func _load_dialogues() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_DIALOGUES):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var did: String = str(doc.get("id", ""))
		if did.is_empty():
			_fail(path, "un dialogo non ha 'id'")
			continue
		_upsert(_dialogues, did, doc)
		visti[did] = true
	_prune(_dialogues, visti)


## US-616: un file per quest (data/quests/q_*.json), l'oggetto e' la quest.
func _load_quests() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_QUESTS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var qid: String = str(doc.get("id", ""))
		if qid.is_empty():
			_fail(path, "una quest non ha 'id'")
			continue
		_upsert(_quests, qid, doc)
		visti[qid] = true
	_prune(_quests, visti)


## US-805: un file per layout disegnato a mano (data/world/layouts/*.json),
## chiave = region_id. Una regione senza file qui non ha layout: get_layout
## torna {} e region_scene.gd usa il fallback piatto di sempre.
func _load_layouts() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_LAYOUTS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var rid: String = str(doc.get("region_id", ""))
		if rid.is_empty():
			_fail(path, "un layout non ha 'region_id'")
			continue
		_upsert(_layouts, rid, doc)
		visti[rid] = true
	_prune(_layouts, visti)


func _load_items() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_ITEMS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		for entry in _object_list(doc, "items", path):
			var item: Dictionary = entry
			var iid: String = str(item.get("id", ""))
			if iid.is_empty():
				_fail(path, "un item non ha 'id'")
				continue
			_upsert(_items, iid, item)
			visti[iid] = true
	_prune(_items, visti)


func _load_structures() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_STRUCTURES):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		for entry in _object_list(doc, "structures", path):
			var s: Dictionary = entry
			var sid: String = str(s.get("id", ""))
			if sid.is_empty():
				_fail(path, "una struttura non ha 'id'")
				continue
			_upsert(_structures, sid, s)
			visti[sid] = true
	_prune(_structures, visti)


func _load_pets() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_PETS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		for entry in _object_list(doc, "pets", path):
			var p: Dictionary = entry
			var pid: String = str(p.get("id", ""))
			if pid.is_empty():
				_fail(path, "un pet non ha 'id'")
				continue
			_upsert(_pets, pid, p)
			visti[pid] = true
	_prune(_pets, visti)


func _load_talents() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_TALENTS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		for entry in _object_list(doc, "talents", path):
			var t: Dictionary = entry
			var tid: String = str(t.get("id", ""))
			if tid.is_empty():
				_fail(path, "un talento non ha 'id'")
				continue
			_upsert(_talents, tid, t)
			visti[tid] = true
	_prune(_talents, visti)


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


## Percorsi di fusione (fase 7): un file per coppia di Pathway vicini, l'oggetto
## e' il percorso ({id, gruppo, pathway_a, pathway_b, abilita_fuse[], stub}).
## Le abilita_fuse dei percorsi non-stub entrano in _fusion_abilities per id.
func _load_fusions() -> void:
	var visti: Dictionary = {}
	var visti_ab: Dictionary = {}
	for path in _json_files_in(DIR_FUSIONS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var fid: String = str(doc.get("id", ""))
		if fid.is_empty():
			_fail(path, "un percorso di fusione non ha 'id'")
			continue
		_upsert(_fusions, fid, doc)
		visti[fid] = true
		if bool(doc.get("stub", false)):
			continue
		for entry in _object_list(doc, "abilita_fuse", path):
			var ab: Dictionary = entry
			var aid: String = str(ab.get("id", ""))
			if aid.is_empty():
				_fail(path, "un'abilita' fusa non ha 'id'")
				continue
			_upsert(_fusion_abilities, aid, ab)
			visti_ab[aid] = true
	_prune(_fusions, visti)
	_prune(_fusion_abilities, visti_ab)


## Tribolazioni (fase 7): un file per salto di fascia, l'oggetto e' la
## tribolazione ({id, salto, condizioni, mentre_in_corso, superamento, ...}).
func _load_tribulations() -> void:
	var visti: Dictionary = {}
	for path in _json_files_in(DIR_TRIBULATIONS):
		var doc: Dictionary = _read_json(path)
		if doc.is_empty():
			continue
		var tid: String = str(doc.get("id", ""))
		if tid.is_empty():
			_fail(path, "una tribolazione non ha 'id'")
			continue
		_upsert(_tribulations, tid, doc)
		visti[tid] = true
	_prune(_tribulations, visti)


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


## Catalogo i18n: oggetto JSON piatto {chiave: stringa}. Radice non-oggetto o
## file mancante -> catalogo vuoto (tr_data ricade sulla chiave), errore
## registrato come per ogni altro file.
func _load_flat(path: String, target: Dictionary) -> void:
	var doc: Dictionary = _read_json(path)
	target.clear()
	for k in doc:
		if typeof(doc[k]) == TYPE_STRING:
			target[k] = doc[k]


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


func _json_files_in(dir_path: String, obbligatoria: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir_path):
		if obbligatoria:
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
