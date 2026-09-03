extends Node
## Salvataggio versionato.
##
## Regole non negoziabili (design-master.md cap. 3.1), i dati di un save sono
## il vettore d'attacco piu' facile perche' l'utente li puo' modificare:
##   - SOLO JSON.parse_string in lettura. MAI bytes_to_var(allow_objects) o
##     ResourceLoader su un file di save: sono esecuzione di codice.
##   - ogni campo letto e' NON FIDATO: typeof() + default sano, campo assente
##     o di tipo sbagliato = gestito, non un crash.
##   - scrittura ATOMICA: file temporaneo + rename. Un crash a meta' non deve
##     lasciare l'unico save corrotto.
##   - versione piu' vecchia -> catena di migrazioni esplicite.
##     versione piu' nuova -> rifiuto gentile, il file non si tocca.
##   - un save corrotto -> errore gestito e slot segnalato, MAI cancellazione
##     silenziosa.
##
## NIENTE class_name: coerente col progetto.

signal salvato(slot: int)
signal caricato(slot: int, dati: Dictionary)
signal errore_save(slot: int, motivo: String)

const VERSIONE_CORRENTE := 6
const DIR_SAVES := "user://saves"

const R_OK := "ok"
const ERR_ASSENTE := "slot_vuoto"
const ERR_JSON := "json_malformato"
const ERR_RADICE := "radice_non_oggetto"
const ERR_FUTURA := "versione_piu_recente_del_gioco"
const ERR_SCRITTURA := "scrittura_fallita"

## Stato di uno slot per la UI del libro (US-015 -> design-ui-libro.md).
enum Slot { VUOTO, VALIDO, CORROTTO }


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_SAVES)


# --- API -------------------------------------------------------------------

## dati: snapshot di gioco gia' assemblato dal chiamante —
##   { nome_personaggio: String, tempo_gioco: float, posizione: [x, y],
##     statistiche: Dictionary, evocazioni: Array }
## Restituisce { ok: bool, reason: String }.
func salva(slot: int, dati: Dictionary) -> Dictionary:
	var doc: Dictionary = {
		"schema_version": VERSIONE_CORRENTE,
		"salvato_il": int(Time.get_unix_time_from_system()),
		"nome_personaggio": str(dati.get("nome_personaggio", "")),
		"tempo_gioco": float(dati.get("tempo_gioco", 0.0)),
		"posizione": _vettore_a_lista(dati.get("posizione", Vector2.ZERO)),
		"statistiche": (dati.get("statistiche", {}) as Dictionary).duplicate(true),
		# summon con durata -1 sopravvivono al salvataggio (design-pathways.md).
		"evocazioni": (dati.get("evocazioni", []) as Array).duplicate(true),
		# Pathway e Sequenza del giocatore (US-201). { pathway_id, sequence }.
		"progressione": (dati.get("progressione", {}) as Dictionary).duplicate(true),
		# Modifiche permanenti al terreno (US-203C). { terrain_mods: [...] }.
		"mondo": (dati.get("mondo", {}) as Dictionary).duplicate(true),
		# Log degli eventi tracciati per l'Acting (US-210). { log: [...] }.
		"eventi": (dati.get("eventi", {}) as Dictionary).duplicate(true),
		# Barra di recitazione della Sequenza corrente (US-211).
		"acting": (dati.get("acting", {}) as Dictionary).duplicate(true),
	}

	DirAccess.make_dir_recursive_absolute(DIR_SAVES)
	var finale: String = _percorso(slot)
	var tmp: String = finale + ".tmp"

	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fallisci(slot, ERR_SCRITTURA)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()

	# rename atomico: il file finale o e' quello vecchio o e' quello nuovo,
	# mai una via di mezzo.
	var err: int = DirAccess.rename_absolute(tmp, finale)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return _fallisci(slot, ERR_SCRITTURA)

	salvato.emit(slot)
	return {"ok": true, "reason": R_OK}


## Restituisce { ok, reason, dati: Dictionary, migrato: bool }.
## Un file corrotto NON viene toccato.
func carica(slot: int) -> Dictionary:
	var percorso: String = _percorso(slot)
	if not FileAccess.file_exists(percorso):
		return {"ok": false, "reason": ERR_ASSENTE, "dati": {}, "migrato": false}

	var testo: String = FileAccess.get_file_as_string(percorso)
	var parsed: Variant = JSON.parse_string(testo)
	if parsed == null:
		return _fallisci_load(slot, ERR_JSON)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fallisci_load(slot, ERR_RADICE)

	var raw: Dictionary = parsed
	var sv: Variant = raw.get("schema_version", 0)
	var versione: int = 0
	if typeof(sv) == TYPE_FLOAT or typeof(sv) == TYPE_INT:
		versione = int(sv)
	if versione > VERSIONE_CORRENTE:
		return _fallisci_load(slot, ERR_FUTURA)

	var migrato: bool = versione < VERSIONE_CORRENTE
	if migrato:
		raw = _migra(raw, versione)

	var dati: Dictionary = _leggi_snapshot(raw)
	caricato.emit(slot, dati)
	return {"ok": true, "reason": R_OK, "dati": dati, "migrato": migrato}


func stato_slot(slot: int) -> int:
	var percorso: String = _percorso(slot)
	if not FileAccess.file_exists(percorso):
		return Slot.VUOTO
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	return Slot.VALIDO if typeof(parsed) == TYPE_DICTIONARY else Slot.CORROTTO


func esiste(slot: int) -> bool:
	return FileAccess.file_exists(_percorso(slot))


## Cancellazione SEMPRE esplicita, mai automatica.
func cancella(slot: int) -> bool:
	var percorso: String = _percorso(slot)
	if not FileAccess.file_exists(percorso):
		return false
	return DirAccess.remove_absolute(percorso) == OK


# --- Migrazioni ----------------------------------------------------------
# Una funzione per salto di versione. La catena si applica in ordine.

func _migra(doc: Dictionary, da_versione: int) -> Dictionary:
	var v: int = da_versione
	while v < VERSIONE_CORRENTE:
		match v:
			1:
				doc = _migra_1_a_2(doc)
			2:
				doc = _migra_2_a_3(doc)
			3:
				doc = _migra_3_a_4(doc)
			4:
				doc = _migra_4_a_5(doc)
			5:
				doc = _migra_5_a_6(doc)
			_:
				push_warning("[SaveSystem] nessuna migrazione da v%d: salto." % v)
		v += 1
	doc["schema_version"] = VERSIONE_CORRENTE
	return doc


## v1 -> v2: il campo evocazioni non esisteva. Default lista vuota.
func _migra_1_a_2(doc: Dictionary) -> Dictionary:
	if not doc.has("evocazioni"):
		doc["evocazioni"] = []
	return doc


## v2 -> v3: la progressione (Pathway + Sequenza) non esisteva (US-201). Un
## save di fase 1 riparte da Sequenza 9; il Pathway resta vuoto e Progression
## lo risolve sul default dei dati (data/balance.json), cosi' la migrazione
## non deve conoscere nessun nome di Pathway.
func _migra_2_a_3(doc: Dictionary) -> Dictionary:
	if not doc.has("progressione"):
		doc["progressione"] = {"pathway_id": "", "sequence": 9}
	return doc


## v3 -> v4: lo stato del mondo (modifiche permanenti al terreno) non esisteva
## (US-203C). Nessuna modifica pregressa: lista vuota.
func _migra_3_a_4(doc: Dictionary) -> Dictionary:
	if not doc.has("mondo"):
		doc["mondo"] = {"terrain_mods": []}
	return doc


## v4 -> v5: il log degli eventi tracciati (Acting Method) non esisteva
## (US-210). Nessuna storia pregressa: log vuoto.
func _migra_4_a_5(doc: Dictionary) -> Dictionary:
	if not doc.has("eventi"):
		doc["eventi"] = {"log": []}
	return doc


## v5 -> v6: la barra di recitazione (Acting) non esisteva (US-211).
func _migra_5_a_6(doc: Dictionary) -> Dictionary:
	if not doc.has("acting"):
		doc["acting"] = {"decadimento": 0.0, "baseline": {}, "latched": {}}
	return doc


# --- Lettura non fidata -------------------------------------------------

func _leggi_snapshot(raw: Dictionary) -> Dictionary:
	return {
		"schema_version": _campo(raw, "schema_version", TYPE_FLOAT, float(VERSIONE_CORRENTE)),
		"salvato_il": _campo(raw, "salvato_il", TYPE_FLOAT, 0.0),
		"nome_personaggio": _campo(raw, "nome_personaggio", TYPE_STRING, ""),
		"tempo_gioco": _campo(raw, "tempo_gioco", TYPE_FLOAT, 0.0),
		"posizione": _posizione(raw.get("posizione")),
		"statistiche": _campo(raw, "statistiche", TYPE_DICTIONARY, {}),
		"evocazioni": _campo(raw, "evocazioni", TYPE_ARRAY, []),
		"progressione": _campo(raw, "progressione", TYPE_DICTIONARY, {}),
		"mondo": _campo(raw, "mondo", TYPE_DICTIONARY, {}),
		"eventi": _campo(raw, "eventi", TYPE_DICTIONARY, {}),
		"acting": _campo(raw, "acting", TYPE_DICTIONARY, {}),
	}


## typeof() con default. I numeri JSON arrivano come float: TYPE_FLOAT
## accetta anche gli interi.
func _campo(dict: Dictionary, chiave: String, tipo: int, default: Variant) -> Variant:
	if not dict.has(chiave):
		return default
	var valore: Variant = dict[chiave]
	var t: int = typeof(valore)
	if t == tipo:
		return valore
	if tipo == TYPE_FLOAT and t == TYPE_INT:
		return float(valore)
	push_warning("[SaveSystem] campo '%s' di tipo %d invece di %d: uso il default." % [chiave, t, tipo])
	return default


func _posizione(valore: Variant) -> Vector2:
	if typeof(valore) != TYPE_ARRAY:
		return Vector2.ZERO
	var arr: Array = valore
	if arr.size() != 2:
		return Vector2.ZERO
	if not (typeof(arr[0]) in [TYPE_FLOAT, TYPE_INT] and typeof(arr[1]) in [TYPE_FLOAT, TYPE_INT]):
		return Vector2.ZERO
	return Vector2(float(arr[0]), float(arr[1]))


# --- Interno -----------------------------------------------------------

func _percorso(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR_SAVES, slot]


func _vettore_a_lista(v: Variant) -> Array:
	if v is Vector2:
		return [v.x, v.y]
	if v is Array and (v as Array).size() == 2:
		return [float(v[0]), float(v[1])]
	return [0.0, 0.0]


func _fallisci(slot: int, motivo: String) -> Dictionary:
	push_error("[SaveSystem] slot %d: %s" % [slot, motivo])
	errore_save.emit(slot, motivo)
	return {"ok": false, "reason": motivo}


func _fallisci_load(slot: int, motivo: String) -> Dictionary:
	push_error("[SaveSystem] carica slot %d: %s (il file NON e' stato toccato)" % [slot, motivo])
	errore_save.emit(slot, motivo)
	return {"ok": false, "reason": motivo, "dati": {}, "migrato": false}
