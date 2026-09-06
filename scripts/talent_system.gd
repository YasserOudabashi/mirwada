extends Node
## I talenti posseduti dal giocatore (US-331). Gli 'acquisiti' si sbloccano
## quando il loro comportamento (EventTracker per i 12, TalentTracker per i 7)
## supera la soglia; gli 'innati' li concede la creazione personaggio (US-332).
##
## Effetto di un talento:
##   - stat_modifier   -> modificatore per id 'talent:<id>' sullo StatsComponent
##                        del giocatore (delta = valore, o valore*base se
##                        moltiplicativo).
##   - tag_grant       -> il tag entra in tag_concessi() (sinergie, US-334).
##   - sblocco_sistema -> bonus_int(chiave) lo somma; il sistema relativo legge.
##
## NIENTE class_name: coerente col resto del progetto.

signal talento_sbloccato(id: String)

var _posseduti: Array = []


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _process(_delta: float) -> void:
	_controlla_sblocchi()


# --- Lettura ---------------------------------------------------------

func posseduti() -> Array:
	return _posseduti.duplicate()


func possiede(id: String) -> bool:
	return _posseduti.has(id)


## I tag concessi dai talenti tag_grant posseduti (US-334).
func tag_concessi() -> Array:
	var out: Array = []
	for id in _posseduti:
		var eff: Dictionary = (_gd().call("get_talent", id) as Dictionary).get("effetto", {}) if _gd() != null else {}
		if str(eff.get("tipo", "")) == "tag_grant" and eff.has("tag"):
			out.append(str(eff["tag"]))
	return out


## Somma dei 'valore' (default 1) dei talenti sblocco_sistema posseduti la cui
## chiave corrisponde. I sistemi (PotionSystem, Forge, giardino) lo interrogano.
func bonus_int(chiave: String) -> int:
	var tot: int = 0
	for id in _posseduti:
		var eff: Dictionary = (_gd().call("get_talent", id) as Dictionary).get("effetto", {}) if _gd() != null else {}
		if str(eff.get("tipo", "")) == "sblocco_sistema" and str(eff.get("chiave", "")) == chiave:
			tot += int(eff.get("valore", 1))
	return tot


# --- Mutazione ------------------------------------------------------

## Concede un talento (sblocco automatico o scelta alla creazione, US-332).
## Idempotente. Applica l'effetto ed emette il segnale.
func concedi(id: String) -> bool:
	if _posseduti.has(id) or (_gd() != null and (_gd().call("get_talent", id) as Dictionary).is_empty()):
		return false
	_posseduti.append(id)
	_applica_effetto(id)
	talento_sbloccato.emit(id)
	return true


## Ri-applica i modificatori di stat di tutti i talenti posseduti: da chiamare
## quando compare il giocatore in scena o dopo un load.
func riapplica() -> void:
	for id in _posseduti:
		_applica_effetto(id)


func pulisci() -> void:
	var st: Node = _stats()
	if st != null:
		for id in _posseduti:
			st.call("remove_modifier", "talent:" + id)
	_posseduti.clear()


# --- Salvataggio ---------------------------------------------------

func per_salvataggio() -> Array:
	return _posseduti.duplicate()


func da_salvataggio(raw: Variant) -> void:
	pulisci()
	if typeof(raw) != TYPE_ARRAY:
		return
	for v in raw:
		if typeof(v) == TYPE_STRING and _gd() != null and not (_gd().call("get_talent", v) as Dictionary).is_empty():
			_posseduti.append(str(v))
	riapplica()


# --- Interno ------------------------------------------------------

func _controlla_sblocchi() -> void:
	if _gd() == null:
		return
	var et: Node = get_node_or_null("/root/EventTracker")
	var tt: Node = get_node_or_null("/root/TalentTracker")
	var eventi_vocab: Dictionary = _gd().call("get_tracked_events")
	for id in _gd().call("talents_per_tipo", "acquisito"):
		if _posseduti.has(id):
			continue
		var t: Dictionary = _gd().call("get_talent", id)
		var sb: Dictionary = t.get("sblocco", {})
		var ev: String = str(sb.get("evento", ""))
		var soglia: float = float(sb.get("target", 0.0))
		if soglia <= 0.0:
			continue
		var attuale: float = 0.0
		if eventi_vocab.has(ev):
			attuale = float(et.call("count", ev, sb.get("filtri", {}))) if et != null else 0.0
		elif tt != null:
			attuale = float(tt.call("count", ev))
		if attuale >= soglia:
			concedi(id)


func _stats() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p.get_node_or_null("StatsComponent") if p != null else null


func _applica_effetto(id: String) -> void:
	var eff: Dictionary = (_gd().call("get_talent", id) as Dictionary).get("effetto", {}) if _gd() != null else {}
	if str(eff.get("tipo", "")) != "stat_modifier":
		return  # tag_grant / sblocco_sistema: letti a domanda, non applicati qui
	var st: Node = _stats()
	if st == null:
		return
	var stat: String = str(eff.get("stat", ""))
	var valore: float = float(eff.get("valore", 0.0))
	var delta: float = valore * float(st.call("get_base", stat)) if bool(eff.get("moltiplicativo", false)) else valore
	st.call("apply_modifier", "talent:" + id, {stat: delta})
