extends Node
## Rituale di avanzamento (US-217). Dalla Sequenza 4 in su l'avanzamento non
## e' una pozione: e' un rituale con luogo, momento, sacrifici e sigilli, che
## si puo' interrompere.
##
## Il formato di advancement_ritual e' gia' nei dati (data/pathways/):
##   location_tags, momento, fase_lunare, sacrifices[], sigils[]
##
## Fino al mondo di fase 6 il luogo e il tempo si simulano (imposta_luogo /
## imposta_tempo). I sacrifici non ancora modellati (strutture, oggetti) si
## dichiarano disponibili con fornisci_sacrificio; 'ancora_del_giocatore'
## passa da AnchorSystem.
##
## NIENTE class_name: coerente col resto del progetto.

signal rituale_avviato(sequenza: int)
signal rituale_completato(sequenza: int)
signal rituale_interrotto(motivo: String)

const SACRIFICIO_ANCORA := "ancora_del_giocatore"

var _luogo_tags: Array = []
var _momento: String = ""
var _fase_lunare: String = ""
var _sigilli: Array = []
var _sacrifici_forniti: Array = []

var _rituale: Dictionary = {}
var _sequenza: int = -1
var _left: float = 0.0
var _durata: float = 45.0


# --- Stato del mondo (simulato finche' non c'e' la fase 6) ---------------

func imposta_luogo(tags: Array) -> void:
	_luogo_tags = tags.duplicate()


func imposta_tempo(momento: String, fase_lunare: String) -> void:
	_momento = momento
	_fase_lunare = fase_lunare


func aggiungi_sigillo(id: String) -> void:
	if not _sigilli.has(id):
		_sigilli.append(id)


func fornisci_sacrificio(id: String) -> void:
	if not _sacrifici_forniti.has(id):
		_sacrifici_forniti.append(id)


func sigilli() -> Array:
	return _sigilli.duplicate()


# --- Prerequisiti e avvio -------------------------------------------------

## { ok: bool, mancanti: PackedStringArray }
func prerequisiti(rituale: Dictionary) -> Dictionary:
	var mancanti := PackedStringArray()

	for t in rituale.get("location_tags", []):
		if not _luogo_tags.has(t):
			mancanti.append("luogo:%s" % t)

	var mom: Variant = rituale.get("momento")
	if mom != null and str(mom) != _momento:
		mancanti.append("momento:%s" % mom)
	var fase: Variant = rituale.get("fase_lunare")
	if fase != null and str(fase) != _fase_lunare:
		mancanti.append("fase_lunare:%s" % fase)

	for s in rituale.get("sigils", []):
		if not _sigilli.has(s):
			mancanti.append("sigillo:%s" % s)

	for sac in rituale.get("sacrifices", []):
		if not _sacrificio_disponibile(str(sac)):
			mancanti.append("sacrificio:%s" % sac)

	return {"ok": mancanti.is_empty(), "mancanti": mancanti}


## Avvia la fase di build. Richiede prerequisiti E acting_progress 1.0
## (come l'avanzamento per pozione, US-209/212).
func avvia(rituale: Dictionary) -> Dictionary:
	if _rituale.size() > 0:
		return {"ok": false, "reason": "rituale_gia_in_corso"}
	var pre: Dictionary = prerequisiti(rituale)
	if not pre["ok"]:
		return {"ok": false, "reason": "prerequisiti_mancanti", "mancanti": pre["mancanti"]}

	var acting: Node = get_node_or_null("/root/Acting")
	if acting == null or not acting.call("e_completo"):
		return {"ok": false, "reason": "recitazione_incompleta"}

	var prog: Node = get_node_or_null("/root/Progression")
	# US-711: salto di fascia con tribolazione aperta -> il rituale non parte.
	var trib: Node = get_node_or_null("/root/TribulationSystem")
	if prog != null and trib != null and bool(trib.call("avanzamento_bloccato", int(prog.call("sequence")))):
		return {"ok": false, "reason": "tribolazione_in_corso"}

	_sequenza = int(prog.call("sequence")) if prog != null else -1
	_rituale = rituale.duplicate(true)
	_durata = _durata_build()
	_left = _durata
	rituale_avviato.emit(_sequenza)
	return {"ok": true, "reason": "ok"}


## Interruzione: danno subito, movimento fuori area, ecc. Il rituale fallisce
## con taglio audio secco e penalita' (follia + fondamenta).
func interrompi(motivo: String) -> void:
	if _rituale.is_empty():
		return
	_rituale = {}
	_left = 0.0
	var tt: Node = get_node_or_null("/root/TalentTracker")
	if tt != null:
		tt.call("registra", "rituali_interrotti", 1.0)  # emettitore US-331
	var b: Dictionary = _balance()
	var m: Node = get_node_or_null("/root/Madness")
	if m != null:
		m.call("add", float(b.get("penalita_follia_interruzione", 15.0)), "rituale_interrotto", false)
	var f: Node = get_node_or_null("/root/Foundation")
	if f != null:
		f.call("applica", float(b.get("malus_fondamenta_interruzione", -8.0)), "rituale_interrotto")
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("silenzio_secco"):
		am.call("silenzio_secco", 1.2)
	rituale_interrotto.emit(motivo)


func in_corso() -> bool:
	return not _rituale.is_empty()


func tempo_rimasto() -> float:
	return _left


func progresso() -> float:
	return clampf(1.0 - _left / maxf(0.01, _durata), 0.0, 1.0)


# --- Avanzamento ----------------------------------------------------------

func _process(delta: float) -> void:
	if _rituale.is_empty():
		return
	_left -= delta
	if _left <= 0.0:
		_completa()


func _completa() -> void:
	var rituale: Dictionary = _rituale
	_rituale = {}

	# consuma i sacrifici modellati (l'Ancora)
	for sac in rituale.get("sacrifices", []):
		if str(sac) == SACRIFICIO_ANCORA:
			var anc: Node = get_node_or_null("/root/AnchorSystem")
			if anc != null:
				var attive: Array = anc.call("active")
				if not attive.is_empty():
					anc.call("destroy", attive[0])

	var prog: Node = get_node_or_null("/root/Progression")
	if prog != null:
		prog.call("avanza")
	var f: Node = get_node_or_null("/root/Foundation")
	if f != null:
		f.call("applica", f.call("costante", "bonus_recitazione_completa"), "rituale_completato")
	# US-804: nessun dato di rituale porta oggi un "tipo" (tutti sono
	# advancement_ritual, data/pathways/*.json), quindi nessun filtro
	# tipo_rituale da popolare -- il filtro resta nel vocabolario per
	# quando servira'.
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null:
		et.call("emit_event", "ritual_completed", {})
	rituale_completato.emit(_sequenza)


# --- Interno ----------------------------------------------------------

func _sacrificio_disponibile(sac: String) -> bool:
	if sac == SACRIFICIO_ANCORA:
		var anc: Node = get_node_or_null("/root/AnchorSystem")
		return anc != null and not (anc.call("active") as Array).is_empty()
	return _sacrifici_forniti.has(sac)


func _durata_build() -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	var mus: Dictionary = gd.call("get_audio", "music") if gd != null else {}
	var rit: Dictionary = mus.get("rituale", {}) if typeof(mus.get("rituale")) == TYPE_DICTIONARY else {}
	var v: Variant = rit.get("durata_build_secondi", 45.0)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 45.0


func _balance() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_balance", "rituale") if gd != null else {}


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"sigilli": _sigilli.duplicate(), "sacrifici_forniti": _sacrifici_forniti.duplicate()}


func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	_sigilli = _lista_di_stringhe(d.get("sigilli"))
	_sacrifici_forniti = _lista_di_stringhe(d.get("sacrifici_forniti"))


func _lista_di_stringhe(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) == TYPE_ARRAY:
		for x in v:
			if typeof(x) == TYPE_STRING:
				out.append(x)
	return out
