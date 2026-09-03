extends Node
## Conoscenza del giocatore (design-master cap. 5): flag booleani namespaced,
## guadagnati da dialoghi, libri, sinergie "lore". Sono la moneta del fog of
## war del diagramma dei Pathway (US-224) e, in fase 6, del gating
## dell'Archivio Sepolto.
##
## Il sistema pieno (fonti, dialoghi) e' fase 6. Qui: il magazzino dei flag,
## serializzato. Convenzione dei flag del diagramma:
##   "pathway:<pathway_id>"          -> conosci la colonna di quel Pathway
##   "sequenza:<pathway_id>:<n>"     -> conosci quella Sequenza
##
## NIENTE class_name: coerente col resto del progetto.

signal appreso(flag: String)

var _flags: Dictionary = {}   # usato come set: flag -> true


func impara(flag: String) -> void:
	if flag.is_empty() or _flags.has(flag):
		return
	_flags[flag] = true
	appreso.emit(flag)


func conosce(flag: String) -> bool:
	return _flags.has(flag)


func tutti() -> Array:
	return _flags.keys()


func dimentica_tutto() -> void:
	_flags.clear()


# --- Salvataggio ---------------------------------------------------------

func per_salvataggio() -> Array:
	return _flags.keys()


## NON FIDATO: solo stringhe non vuote.
func da_salvataggio(raw: Variant) -> void:
	_flags = {}
	if typeof(raw) != TYPE_ARRAY:
		return
	for v in raw:
		if typeof(v) == TYPE_STRING and not (v as String).is_empty():
			_flags[v] = true
