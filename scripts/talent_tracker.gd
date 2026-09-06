extends Node
## Contatori dei comportamenti-talento (US-331): cio' che i 12 eventi di
## tracked_events.json NON catturano. Versione ridotta di EventTracker — nessun
## filtro (il vocabolario chiuso data/schema/tracked_talents.json li dichiara
## vuoti per tutte le voci correnti).
##
## Gli EMETTITORI sono agganciati ai sistemi esistenti con 1-3 righe:
##   - ingredienti_coltivati : BaseSystem.raccogli()
##   - abilita_prestate_usate: AbilityEngine.execute_stored() / grant_temporary()
##   - distanza_percorsa     : player.gd _physics_process
##   - rituali_interrotti    : RitualSystem.interrompi()
## giocato_di_notte / sequenze_senza_pozione / nemici_risparmiati non hanno
## ancora un punto di aggancio naturale (ciclo notte = fase 6, meccanica del
## risparmiare = piu' avanti): registra() e' pubblico, si agganciano allora.
##
## NIENTE class_name: coerente col resto del progetto.

signal comportamento_registrato(nome: String, totale: float)

var _conteggi: Dictionary = {}


func _vocabolario() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("tracked_talents") if gd != null else {}


## Registra 'quantita' su un comportamento-talento. nome fuori vocabolario ->
## push_error e nessun conteggio.
func registra(nome: String, quantita: float = 1.0) -> void:
	if not _vocabolario().has(nome):
		push_error("[TalentTracker] comportamento '%s' fuori dal vocabolario chiuso di data/schema/tracked_talents.json" % nome)
		return
	_conteggi[nome] = float(_conteggi.get(nome, 0.0)) + quantita
	comportamento_registrato.emit(nome, _conteggi[nome])


func count(nome: String) -> float:
	return float(_conteggi.get(nome, 0.0))


func azzera() -> void:
	_conteggi.clear()


func pulisci() -> void:
	_conteggi.clear()


# --- Salvataggio ---------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return _conteggi.duplicate(true)


## Rilettura NON FIDATA: solo chiavi nel vocabolario, valori numerici >= 0.
func da_salvataggio(raw: Variant) -> void:
	_conteggi = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var vocab: Dictionary = _vocabolario()
	for k in raw:
		if vocab.has(k) and typeof(raw[k]) in [TYPE_FLOAT, TYPE_INT]:
			_conteggi[str(k)] = maxf(0.0, float(raw[k]))
