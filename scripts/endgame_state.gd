extends Node
## Stato dell'endgame (fase 7): cambio di Pathway, abilita' fuse concesse,
## tribolazioni superate, contratto di eredita', finale raggiunto.
##
## Un solo campo del save ("endgame", schema_version 22). Come per "mondo" di
## fase 6, i motori nuovi (PathwayChange, FusionEngine, TribulationSystem,
## EndingSystem) ci scrivono attraverso questo store: il save non li conosce.
##
## Tutto NON FIDATO in lettura: id ignoti scartati, numeri clampati, tipi
## sbagliati -> default. NIENTE class_name, coerente col progetto.

signal cambiato()

## id del Pathway lasciato al cambio (""), per la UI e per le fusioni.
var pathway_precedente: String = ""
## id delle abilita' fuse concesse ("fus_<percorso>_...").
var fusioni: Array = []
## i "da" dei salti di fascia gia' superati (interi 7/5/3/1).
var tribolazioni_superate: Array = []
## contratto di eredita' al personaggio successivo. Vedi FR-14:
##   { conoscenza: [flag], ancora: { id, forza } | {}, reputazione: { fid: val },
##     oggetto: item_id | "" }
var eredita: Dictionary = {}
## id del finale raggiunto ("apoteosi" | "consumazione" | "rinuncia" | "").
var finale: String = ""


func pulisci() -> void:
	pathway_precedente = ""
	fusioni = []
	tribolazioni_superate = []
	eredita = {}
	finale = ""
	cambiato.emit()


func registra_cambio(vecchio_pathway: String) -> void:
	pathway_precedente = str(vecchio_pathway)
	cambiato.emit()


func aggiungi_fusione(ability_id: String) -> void:
	var s: String = str(ability_id)
	if not s.is_empty() and not fusioni.has(s):
		fusioni.append(s)
		cambiato.emit()


func segna_tribolazione(da: int) -> void:
	if not tribolazioni_superate.has(da):
		tribolazioni_superate.append(da)
		cambiato.emit()


func tribolazione_superata(da: int) -> bool:
	return tribolazioni_superate.has(da)


func imposta_eredita(contratto: Dictionary) -> void:
	eredita = contratto.duplicate(true)
	cambiato.emit()


func imposta_finale(id: String) -> void:
	finale = str(id)
	cambiato.emit()


# --- Salvataggio -----------------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {
		"pathway_precedente": pathway_precedente,
		"fusioni": fusioni.duplicate(),
		"tribolazioni_superate": tribolazioni_superate.duplicate(),
		"eredita": eredita.duplicate(true),
		"finale": finale,
	}


## NON FIDATO: ogni campo validato, tipo sbagliato -> default.
func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw

	if typeof(d.get("pathway_precedente")) == TYPE_STRING:
		pathway_precedente = d["pathway_precedente"]

	if typeof(d.get("fusioni")) == TYPE_ARRAY:
		for v in d["fusioni"]:
			if typeof(v) == TYPE_STRING and not (v as String).is_empty():
				fusioni.append(v)

	if typeof(d.get("tribolazioni_superate")) == TYPE_ARRAY:
		for v in d["tribolazioni_superate"]:
			if typeof(v) in [TYPE_INT, TYPE_FLOAT] and int(v) in [7, 5, 3, 1]:
				var n: int = int(v)
				if not tribolazioni_superate.has(n):
					tribolazioni_superate.append(n)

	if typeof(d.get("eredita")) == TYPE_DICTIONARY:
		eredita = _leggi_eredita(d["eredita"])

	if typeof(d.get("finale")) == TYPE_STRING:
		finale = d["finale"]

	cambiato.emit()


## US-719: wrapper pubblico di _leggi_eredita, per chi deve sanitizzare un
## contratto di eredita' letto da un ALTRO save (GameState.nuova_partita,
## che legge lo slot precedente prima di sovrascriverlo) senza passare da
## da_salvataggio() (che sostituirebbe anche pathway_precedente/fusioni/ecc.
## di QUESTO EndgameState, che per il nuovo personaggio deve restare vuoto).
func eredita_sanitizzata(raw: Variant) -> Dictionary:
	return _leggi_eredita(raw)


## Il contratto di eredita' e' il pezzo piu' delicato: lo legge un save che
## l'utente puo' avere modificato per iniziare la partita successiva "ricco".
func _leggi_eredita(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = raw
	var out: Dictionary = {}

	if typeof(d.get("conoscenza")) == TYPE_ARRAY:
		var flags: Array = []
		for v in d["conoscenza"]:
			if typeof(v) == TYPE_STRING and not (v as String).is_empty():
				flags.append(v)
		out["conoscenza"] = flags

	if typeof(d.get("ancora")) == TYPE_DICTIONARY:
		var a: Dictionary = d["ancora"]
		if typeof(a.get("id")) == TYPE_STRING and not (a["id"] as String).is_empty():
			var forza: float = 0.0
			if typeof(a.get("forza")) in [TYPE_INT, TYPE_FLOAT]:
				forza = maxf(0.0, float(a["forza"]))
			out["ancora"] = {"id": a["id"], "forza": forza}

	if typeof(d.get("reputazione")) == TYPE_DICTIONARY:
		var rep: Dictionary = {}
		for k in d["reputazione"]:
			if typeof(k) == TYPE_STRING and typeof(d["reputazione"][k]) in [TYPE_INT, TYPE_FLOAT]:
				rep[k] = float(d["reputazione"][k])
		out["reputazione"] = rep

	if typeof(d.get("oggetto")) == TYPE_STRING and not (d["oggetto"] as String).is_empty():
		out["oggetto"] = d["oggetto"]

	return out
