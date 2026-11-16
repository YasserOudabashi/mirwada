extends Node
## Rituale di avanzamento (US-217). Dalla Sequenza 4 in su l'avanzamento non
## e' una pozione: e' un rituale con luogo, momento, sacrifici e sigilli, che
## si puo' interrompere.
##
## Il formato di advancement_ritual e' gia' nei dati (data/pathways/):
##   location_tags, momento, fase_lunare, sacrifices[], sigils[]
##
## Il luogo e il tempo vengono dal mondo (WorldState, TimeSystem: US-1305b); imposta_luogo /
## imposta_tempo restano per i test. I sacrifici non ancora modellati (strutture, oggetti) si
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

## Il luogo e il tempo veri (US-1305b): la zona di WorldState e il momento e la fase di TimeSystem. Quelli messi a
## mano con imposta_luogo / imposta_tempo (test, simulazioni) si aggiungono o vincono.
func _luoghi_ora() -> Array:
	var tags: Array = _luogo_tags.duplicate()
	var ws: Node = get_node_or_null("/root/WorldState")
	var zona: String = str(ws.call("zona_corrente")) if ws != null else ""
	if not zona.is_empty() and not tags.has(zona):
		tags.append(zona)
	# US-1305c: una zona vale anche come altri luoghi (regions.json "zone_anche": il tempio abbandonato e' anche
	# un luogo in decadenza).
	var gd: Node = get_node_or_null("/root/GameData")
	if ws != null and gd != null:
		var anche: Dictionary = gd.call("get_region", str(ws.call("regione_corrente"))).get("zone_anche", {})
		for t in tags.duplicate():
			for altro in anche.get(t, []):
				if not tags.has(altro):
					tags.append(altro)
	return tags


func _momento_ora() -> String:
	var ts: Node = get_node_or_null("/root/TimeSystem")
	return _momento if not _momento.is_empty() or ts == null else str(ts.call("momento"))


func _fase_ora() -> String:
	var ts: Node = get_node_or_null("/root/TimeSystem")
	return _fase_lunare if not _fase_lunare.is_empty() or ts == null else str(ts.call("fase_lunare"))


## Che cosa chiede il rituale, voce per voce, e se c'e': [{tipo, id, ok}] con tipo luogo | momento | fase_lunare |
## sigillo | sacrificio. Dei luoghi ne basta uno (decisione dell'utente, 2026-11-16): la voce "luogo" e' una sola,
## con "ids" = tutti quelli che vanno bene. La pagina del diagramma la mostra cosi' com'e'.
func richieste(rituale: Dictionary) -> Array:
	var out: Array = []
	var luoghi: Array = rituale.get("location_tags", [])
	if not luoghi.is_empty():
		var qui: Array = _luoghi_ora()
		var trovato: String = ""
		for t in luoghi:
			if qui.has(t):
				trovato = str(t)
		out.append({"tipo": "luogo", "id": trovato if not trovato.is_empty() else str(luoghi[0]),
			"ids": luoghi.duplicate(), "ok": not trovato.is_empty()})
	var mom: Variant = rituale.get("momento")
	if mom != null:
		out.append({"tipo": "momento", "id": str(mom), "ok": str(mom) == _momento_ora()})
	var fase: Variant = rituale.get("fase_lunare")
	if fase != null:
		out.append({"tipo": "fase_lunare", "id": str(fase), "ok": str(fase) == _fase_ora()})
	var inv: Node = get_node_or_null("/root/Inventory")
	for s in rituale.get("sigils", []):          # US-1305d: un sigillo e' un oggetto dello zaino (non si consuma)
		out.append({"tipo": "sigillo", "id": str(s),
			"ok": _sigilli.has(s) or (inv != null and int(inv.call("conta", str(s))) >= 1)})
	for sac in rituale.get("sacrifices", []):
		var c: Dictionary = costo(str(sac))
		out.append({"tipo": "sacrificio", "id": str(sac), "ok": _sacrificio_disponibile(str(sac)),
			"costo": str(c.get("tipo", "")), "pagabile": pagabile(str(sac)),
			"da_offrire": str(c.get("tipo", "")) not in ["ancora", "flag"]})
	return out


## { ok: bool, mancanti: PackedStringArray }
func prerequisiti(rituale: Dictionary) -> Dictionary:
	var mancanti := PackedStringArray()
	for r in richieste(rituale):
		if not bool(r["ok"]):
			mancanti.append("%s:%s" % [r["tipo"], r["id"]])
	return {"ok": mancanti.is_empty(), "mancanti": mancanti}


## Il rituale della Sequenza corrente ({} se non ne ha: fino alla 5 si avanza con la sola pozione).
func rituale_corrente() -> Dictionary:
	var prog: Node = get_node_or_null("/root/Progression")
	var r: Variant = prog.call("sequence_data").get("advancement_ritual") if prog != null else null
	return r if r is Dictionary else {}


## US-1305b: compie il rituale della Sequenza corrente, come lo fa il giocatore dal libro. La pozione si beve dentro
## il rituale (decisione dell'utente): deve essere pronta, e si beve quando il rituale finisce.
func compi() -> Dictionary:
	var rituale: Dictionary = rituale_corrente()
	if rituale.is_empty():
		return {"ok": false, "reason": "nessun_rituale"}
	var ps: Node = get_node_or_null("/root/PotionSystem")
	if ps != null and (ps.call("pozione_pronta") as Dictionary).is_empty():
		return {"ok": false, "reason": "manca_la_pozione"}
	return avvia(rituale)


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

	for sac in rituale.get("sacrifices", []):       # US-1305d: ogni sacrificio si paga col suo costo
		_paga(str(sac))

	# US-1305b: se c'e' la pozione pronta la si beve adesso, dentro il rituale (e' lei che fa avanzare e da' il
	# bonus della recitazione); senza PotionSystem o senza pozione (rituali simulati) si avanza come prima.
	var ps: Node = get_node_or_null("/root/PotionSystem")
	if ps != null and not (ps.call("pozione_pronta") as Dictionary).is_empty():
		ps.call("bevi_nel_rituale")
	else:
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

## US-1305d: un sacrificio c'e' quando si puo' pagare e, se e' una scelta del giocatore, quando l'ha offerto
## (offri, dal libro). L'Ancora e le cose gia' fatte (flag) non si offrono: ci sono o non ci sono.
func _sacrificio_disponibile(sac: String) -> bool:
	var tipo: String = str(costo(sac).get("tipo", ""))
	if tipo in ["ancora", "flag"]:
		return pagabile(sac)
	return _sacrifici_forniti.has(sac) and pagabile(sac)


## Come si paga un sacrificio (balance.json rituale.sacrifici); {} = non descritto, lo dichiara chi chiama.
func costo(sac: String) -> Dictionary:
	if sac == SACRIFICIO_ANCORA:
		return {"tipo": "ancora"}
	var c: Variant = (_balance().get("sacrifici", {}) as Dictionary).get(sac)
	return c if c is Dictionary else {}


## Il giocatore ha di che pagarlo adesso?
func pagabile(sac: String) -> bool:
	var c: Dictionary = costo(sac)
	match str(c.get("tipo", "")):
		"ancora":
			var anc: Node = get_node_or_null("/root/AnchorSystem")
			return anc != null and not (anc.call("active") as Array).is_empty()
		"flag":
			var ks: Node = get_node_or_null("/root/KnowledgeStore")
			return ks != null and bool(ks.call("conosce", str(c.get("id", ""))))
		"oggetto":
			var inv: Node = get_node_or_null("/root/Inventory")
			return inv != null and int(inv.call("conta", str(c.get("item_id", "")))) >= 1
		"equip":
			var eq: Node = get_node_or_null("/root/Equipment")
			return eq != null and not (eq.call("equipaggiato", str(c.get("slot", ""))) as Dictionary).is_empty()
		"struttura":
			var sr: Node = get_node_or_null("/root/StructureRegistry")
			return sr != null and int(sr.call("conta")) >= 1
	return true                                   # salute, follia, fondamenta, non descritto: si puo' sempre


## Il giocatore offre un sacrificio (la scelta scritta che conferma nel libro). false se non puo' pagarlo.
func offri(sac: String) -> bool:
	if not pagabile(sac):
		return false
	fornisci_sacrificio(sac)
	return true


## Paga un sacrificio alla fine del rituale.
func _paga(sac: String) -> void:
	var c: Dictionary = costo(sac)
	match str(c.get("tipo", "")):
		"ancora":
			var anc: Node = get_node_or_null("/root/AnchorSystem")
			if anc != null and not (anc.call("active") as Array).is_empty():
				anc.call("destroy", (anc.call("active") as Array)[0])
		"oggetto":
			var inv: Node = get_node_or_null("/root/Inventory")
			if inv != null:
				var iid: String = str(c.get("item_id", ""))
				inv.call("rimuovi", iid, int(inv.call("conta", iid)) if bool(c.get("tutti", false)) else 1)
		"equip":
			var eq: Node = get_node_or_null("/root/Equipment")
			if eq != null:
				eq.call("distruggi_slot", str(c.get("slot", "")))
		"struttura":
			var sr: Node = get_node_or_null("/root/StructureRegistry")
			if sr != null and int(sr.call("conta")) >= 1:
				sr.call("distruggi", str((sr.call("attive") as Array)[0]["id"]), true)
		"salute":
			var p: Node = get_tree().get_first_node_in_group("player")
			var st: Node = p.get_node_or_null("StatsComponent") if p != null else null
			if st != null:
				st.set("hp", maxf(1.0, float(st.get("hp")) * (1.0 - float(c.get("frazione", 0.0)))))
		"follia":
			var m: Node = get_node_or_null("/root/Madness")
			if m != null:
				m.call("add", float(c.get("quantita", 0.0)), "sacrificio", false)
		"fondamenta":
			var f: Node = get_node_or_null("/root/Foundation")
			if f != null:
				f.call("applica", float(c.get("delta", 0.0)), "sacrificio")
	_sacrifici_forniti.erase(sac)                  # dato una volta: il prossimo rituale lo richiede di nuovo


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
