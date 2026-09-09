extends VBoxContainer
## Pagina "diagramma dei Pathway" (US-224). 10 colonne (i Pathway attivi) x 10
## righe (Sequenze 9->0). Generato dai dati di GameData, mai disegnato a mano.
##
## FOG OF WAR sulla conoscenza (design-master cap. 5): una cella e' leggibile
## solo se il giocatore la conosce —
##   * la propria colonna, dalle Sequenze 9 fino a quella corrente (le ha
##     vissute),
##   * oppure un flag in KnowledgeStore ("pathway:<id>" o "sequenza:<id>:<n>").
## Il resto e' offuscato, con UNA eccezione: il nome (solo il nome, mai le
## abilita') della Sequenza immediatamente successiva alla propria, sul
## proprio Pathway soltanto ("prossima" - un presagio, non conoscenza
## acquisita: non entra in KnowledgeStore, quindi non si eredita a fine
## partita, US-719).
##
## La Sequenza corrente e' evidenziata e le sue abilita' sono elencate sotto.
## Nessun nome di Pathway/Sequenza hardcoded: solo id e chiavi i18n.

const C_NOTO := Color(0.74, 0.67, 0.5)
const C_IGNOTO := Color(0.22, 0.2, 0.17)
const C_CORRENTE := Color(0.4, 0.76, 0.82)
const C_PROSSIMA := Color(0.5, 0.42, 0.3)

var _stati: Dictionary = {}   # "pid:n" -> "noto" | "ignoto" | "corrente" | "prossima"
var _abilita: Array = []
## Fog of war sui nomi di Sequenza (CLAUDE.md, richiesta utente 2026-09-09).
## Il giocatore puo' conoscere al massimo il nome della Sequenza immediatamente
## successiva alla propria, sul proprio Pathway soltanto: mai le sue abilita'
## o altri dettagli, mai Sequenze piu' lontane. Calcolato al volo da
## Progression, MAI scritto in KnowledgeStore: US-719 (eredita' al personaggio
## successivo, fase 7) eredita solo i flag imparati li', non questa anteprima.
var _prossima_nome: String = ""
## US-708: i Pathway vicini verso cui si puo' fondere. Ogni voce:
## { id, scritto (percorso di fusione non-stub), puo (PathwayChange.puo_cambiare) }.
var _vicini: Array = []
## US-810: esito dell'ultima prepara_pozione()/bevi_pozione() (dal Dictionary
## di ritorno di PotionSystem), mostrato nella sezione avanzamento finche' non
## arriva un'altra azione. NON azzerato in aggiorna(): e' l'ultimo risultato,
## non uno stato ricalcolato dai dati.
var _pozione_stato: Dictionary = {}
## US-810: stato della sezione avanzamento per gli accessor di test (mirror
## di _vicini), ricalcolato ad ogni aggiorna().
var _avanzamento: Dictionary = {}


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_stati.clear()
	_abilita.clear()
	_vicini.clear()
	_avanzamento.clear()
	_prossima_nome = ""

	var gd: Node = _n("/root/GameData")
	var prog: Node = _n("/root/Progression")
	var kn: Node = _n("/root/KnowledgeStore")
	if gd == null:
		return

	var pathway_ids: Array = gd.call("pathway_ids")
	pathway_ids.sort()
	var mio: String = str(prog.call("pathway")) if prog != null else ""
	var mia_seq: int = int(prog.call("sequence")) if prog != null else 9

	var griglia := GridContainer.new()
	griglia.columns = pathway_ids.size() + 1
	griglia.add_theme_constant_override("h_separation", 2)
	griglia.add_theme_constant_override("v_separation", 2)
	add_child(griglia)

	griglia.add_child(_cella_testo(""))
	for pid in pathway_ids:
		var pw: Dictionary = gd.call("get_pathway", pid)
		griglia.add_child(_cella_testo(str(gd.call("tr_data", pw.get("name_i18n", pid))), true))

	for n in range(9, -1, -1):
		griglia.add_child(_cella_testo("S%d" % n))
		for pid in pathway_ids:
			var stato: String = _stato(pid, n, mio, mia_seq, kn)
			_stati["%s:%d" % [pid, n]] = stato
			griglia.add_child(_cella_cella(stato))

	# --- dettaglio della Sequenza corrente ---
	if prog != null and not mio.is_empty():
		var pw: Dictionary = gd.call("get_pathway", mio)
		var nome_pw: String = str(gd.call("tr_data", pw.get("name_i18n", mio)))
		var sd: Dictionary = prog.call("sequence_data")
		add_child(_riga("%s  ·  %s S%d  ·  %s" % [
			nome_pw, tr("BOOK_DIAGRAMMA_SEI_QUI"), mia_seq, str(prog.call("tier"))]))
		for aid in sd.get("abilities", []):
			var ab: Dictionary = gd.call("get_ability", aid)
			var nome: String = str(gd.call("tr_data", ab.get("name_i18n", aid)))
			_abilita.append(nome)
			add_child(_riga("· " + nome))

		if mia_seq > 0:
			var prossima: Dictionary = gd.call("get_sequence", "%s_%d" % [mio, mia_seq - 1])
			if not prossima.is_empty():
				_prossima_nome = str(gd.call("tr_data", prossima.get("name_i18n", "")))
				add_child(_riga("%s %s" % [tr("BOOK_DIAGRAMMA_PROSSIMA"), _prossima_nome]))

		_sezione_fusione(gd, prog, mio, pw)
		_sezione_avanzamento(gd, prog, mio, pw, sd)


# --- sezione "fondere il Pathway" (US-708) ---------------------------
## Mostra il gruppo del Pathway corrente, i vicini fondibili e, per ognuno, se
## il percorso di fusione e' scritto o "ancora da rivelare" (stub -> fog of
## war, come le celle ignote del diagramma). Se PathwayChange.puo_cambiare e'
## true un'azione conferma il cambio; altrimenti si mostra il motivo.
func _sezione_fusione(gd: Node, _prog: Node, mio: String, pw: Dictionary) -> void:
	var pc: Node = _n("/root/PathwayChange")
	var fe: Node = _n("/root/FusionEngine")
	if pc == null:
		return
	var gruppo: String = str(pw.get("group", ""))
	add_child(_riga("%s  %s %s" % [
		tr("BOOK_DIAGRAMMA_FUSIONE_TITOLO"), tr("BOOK_DIAGRAMMA_FUSIONE_GRUPPO"), gruppo]))

	var ids: Array = gd.call("pathway_ids")
	ids.sort()
	for pid in ids:
		if pid == mio:
			continue
		var altro: Dictionary = gd.call("get_pathway", pid)
		if str(altro.get("group", "")) != gruppo:
			continue
		var scritto: bool = fe != null and not (fe.call("percorso", mio, pid) as Dictionary).is_empty()
		var puo: bool = bool(pc.call("puo_cambiare", pid))
		_vicini.append({"id": pid, "scritto": scritto, "puo": puo})

		var h := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(200, 0)
		l.text = "%s — %s" % [
			str(gd.call("tr_data", altro.get("name_i18n", pid))),
			tr("BOOK_DIAGRAMMA_FUSIONE_SCRITTO") if scritto else tr("BOOK_DIAGRAMMA_FUSIONE_STUB")]
		if not scritto:
			l.modulate = C_IGNOTO.lightened(0.5)  # fog of war, come le celle ignote
		h.add_child(l)
		if puo:
			var b := Button.new()
			b.text = tr("BOOK_DIAGRAMMA_FUSIONE_CONFERMA")
			b.pressed.connect(fondi.bind(pid))
			h.add_child(b)
		else:
			var m := Label.new()
			m.modulate = Color(1, 1, 1, 0.55)
			m.text = tr("BOOK_DIAGRAMMA_FUSIONE_TROPPO_PRESTO")
			h.add_child(m)
		add_child(h)

	if _vicini.is_empty():
		add_child(_riga(tr("BOOK_DIAGRAMMA_FUSIONE_NIENTE")))


## Conferma il cambio verso `nuovo_pathway`. Rigenera la pagina dopo.
## Interrogabile dai test.
func fondi(nuovo_pathway: String) -> Dictionary:
	var pc: Node = _n("/root/PathwayChange")
	if pc == null:
		return {"ok": false, "reason": "no_pathway_change"}
	var res: Dictionary = pc.call("cambia", nuovo_pathway)
	aggiorna()
	return res


func vicini_fondibili() -> Array:
	return _vicini.duplicate(true)


# --- sezione "avanzamento": Prepara/Bevi la pozione (US-810) -----------
## Formula della Sequenza corrente (Progression.sequence_data().potion, gia'
## in `sd`): Caratteristica richiesta, ingredienti posseduti/1, recitazione,
## bottoni Prepara (attivo con Caratteristica + ingredienti >= soglia
## parziale della formula) e Bevi (normale se avanzamento_disponibile(),
## forzato con malus di follia se solo avanzamento_forzabile(), altrimenti
## disabilitato). Stesso stile a righe di _sezione_fusione.
func _sezione_avanzamento(gd: Node, _prog: Node, mio: String, _pw: Dictionary, sd: Dictionary) -> void:
	add_child(_riga(tr("BOOK_DIAGRAMMA_AVANZAMENTO_TITOLO")))
	var potion: Dictionary = sd.get("potion", {})
	if potion.is_empty():
		add_child(_riga(tr("BOOK_DIAGRAMMA_AVANZAMENTO_NIENTE")))
		return

	var ps: Node = _n("/root/PotionSystem")
	var store: Node = _n("/root/CharacteristicStore")
	var inv: Node = _n("/root/Inventory")
	var acting: Node = _n("/root/Acting")
	var found: Node = _n("/root/Foundation")

	var car: Dictionary = gd.call("characteristic_for", mio, int(potion.get("characteristic_sequence", -1)))
	var car_posseduta: bool = store != null and not car.is_empty() \
		and bool(store.call("possiede", str(car.get("id", ""))))
	add_child(_riga("%s: %s (%s)" % [
		tr("BOOK_DIAGRAMMA_AVANZAMENTO_CARATTERISTICA"),
		str(gd.call("tr_data", car.get("name_i18n", car.get("id", "")))),
		tr("BOOK_DIAGRAMMA_AVANZAMENTO_POSSEDUTA") if car_posseduta else tr("BOOK_DIAGRAMMA_AVANZAMENTO_MANCANTE")]))

	var richiesti: Array = potion.get("ingredients", [])
	var posseduti: Array = []
	var ingredienti_stato: Array = []
	for iid in richiesti:
		var n: int = int(inv.call("conta", iid)) if inv != null else 0
		if n >= 1:
			posseduti.append(iid)
		var nome: String = str(gd.call("tr_data", (gd.call("get_item", iid) as Dictionary).get("name_i18n", iid)))
		ingredienti_stato.append({"id": iid, "nome": nome, "posseduti": n})
		add_child(_riga("· %s  x %d/1" % [nome, n]))

	var recitazione: float = float(acting.call("acting_progress")) if acting != null else 0.0
	add_child(_riga("%s: %d%%" % [tr("BOOK_DIAGRAMMA_AVANZAMENTO_RECITAZIONE"), int(round(recitazione * 100))]))

	var formula: Dictionary = gd.call("get_formula", str(potion.get("formula_id", "")))
	var soglia: int = int(formula.get("soglia_parziale", richiesti.size()))
	var parziale: bool = posseduti.size() < richiesti.size()

	var b_prepara := Button.new()
	b_prepara.text = (tr("BOOK_DIAGRAMMA_AVANZAMENTO_PREPARA_PARZIALE") % _testo_penalita(formula)) \
		if parziale else tr("BOOK_DIAGRAMMA_AVANZAMENTO_PREPARA")
	b_prepara.disabled = not (car_posseduta and posseduti.size() >= soglia)
	b_prepara.pressed.connect(prepara_pozione)
	add_child(b_prepara)

	var pronta: Dictionary = ps.call("pozione_pronta") if ps != null else {}
	if not pronta.is_empty():
		var disponibile: bool = ps != null and bool(ps.call("avanzamento_disponibile"))
		var forzabile: bool = ps != null and bool(ps.call("avanzamento_forzabile"))
		var b_bevi := Button.new()
		if disponibile:
			b_bevi.text = tr("BOOK_DIAGRAMMA_AVANZAMENTO_BEVI")
			b_bevi.pressed.connect(bevi_pozione.bind(false))
		elif forzabile:
			var mult: float = found.call("moltiplicatore_follia") if found != null else 1.0
			var n_follia: int = int(round(float(sd.get("madness_on_force", 0.0)) * mult))
			b_bevi.text = tr("BOOK_DIAGRAMMA_AVANZAMENTO_BEVI_FORZATO") % n_follia
			b_bevi.pressed.connect(bevi_pozione.bind(true))
		else:
			b_bevi.disabled = true
			b_bevi.text = tr("BOOK_DIAGRAMMA_AVANZAMENTO_BEVI")
		add_child(b_bevi)

	if not _pozione_stato.is_empty():
		add_child(_riga(_esito_testo(_pozione_stato)))

	_avanzamento = {
		"potion": potion.duplicate(true),
		"caratteristica_posseduta": car_posseduta,
		"ingredienti": ingredienti_stato,
		"recitazione": recitazione,
		"prepara_attivo": not b_prepara.disabled,
	}


## '_nota'/'_comment' (prefisso '_') sono documentazione interna dei dati,
## mai testo per il giocatore — stessa convenzione gia' usata altrove nei
## file data/ (es. items_doc._comment).
func _testo_penalita(formula: Dictionary) -> String:
	var pen: Dictionary = formula.get("penalita_parziale", {})
	var parti: Array = []
	for k in pen:
		if str(k).begins_with("_"):
			continue
		parti.append("%s %s" % [str(k), str(pen[k])])
	return ", ".join(parti) if not parti.is_empty() else "?"


func _esito_testo(stato: Dictionary) -> String:
	if bool(stato.get("ok", false)):
		return tr("BOOK_DIAGRAMMA_AVANZAMENTO_ESITO_OK")
	var chiavi := {
		"caratteristica_incoerente": "BOOK_DIAGRAMMA_AVANZAMENTO_ESITO_CARATTERISTICA_INCOERENTE",
		"caratteristica_mancante": "BOOK_DIAGRAMMA_AVANZAMENTO_ESITO_CARATTERISTICA_MANCANTE",
		"ingredienti_insufficienti": "BOOK_DIAGRAMMA_AVANZAMENTO_ESITO_INGREDIENTI_INSUFFICIENTI",
		"formula_inesistente": "BOOK_DIAGRAMMA_AVANZAMENTO_ESITO_FORMULA_INESISTENTE",
		"nessuna_pozione": "BOOK_DIAGRAMMA_AVANZAMENTO_ESITO_NESSUNA_POZIONE",
	}
	var chiave: String = str(chiavi.get(str(stato.get("reason", "")), ""))
	return tr(chiave) if not chiave.is_empty() else str(stato.get("reason", ""))


## Prepara la pozione della Sequenza corrente: PotionSystem.concoct() legge
## solo l'Array di ingredienti passato e consuma la Caratteristica — NON
## tocca l'Inventory (:22-57) — quindi qui, dopo un esito riuscito, si
## rimuove dall'Inventory un'unita' di ciascun ingrediente effettivamente
## posseduto e passato a concoct(). Pubblica, interrogabile dai test.
func prepara_pozione() -> Dictionary:
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	var ps: Node = _n("/root/PotionSystem")
	var inv: Node = _n("/root/Inventory")
	if prog == null or gd == null or ps == null:
		_pozione_stato = {"ok": false, "reason": "no_potion_system"}
		return _pozione_stato

	var mio: String = str(prog.call("pathway"))
	var sd: Dictionary = prog.call("sequence_data")
	var potion: Dictionary = sd.get("potion", {})
	if potion.is_empty():
		_pozione_stato = {"ok": false, "reason": "nessuna_formula"}
		aggiorna()
		return _pozione_stato

	var car: Dictionary = gd.call("characteristic_for", mio, int(potion.get("characteristic_sequence", -1)))
	var richiesti: Array = potion.get("ingredients", [])
	var posseduti: Array = []
	for iid in richiesti:
		if inv != null and int(inv.call("conta", iid)) >= 1:
			posseduti.append(iid)

	var res: Dictionary = ps.call("concoct", str(potion.get("formula_id", "")), str(car.get("id", "")), posseduti)
	if bool(res.get("ok", false)) and inv != null:
		for iid in posseduti:
			inv.call("rimuovi", iid, 1)
	_pozione_stato = res
	aggiorna()
	return res


## Beve la pozione pronta (forza: avanza comunque con malus se la
## recitazione non e' completa, vedi PotionSystem.bevi). Pubblica,
## interrogabile dai test.
func bevi_pozione(forza: bool = false) -> Dictionary:
	var ps: Node = _n("/root/PotionSystem")
	if ps == null:
		_pozione_stato = {"ok": false, "reason": "no_potion_system"}
		return _pozione_stato
	var res: Dictionary = ps.call("bevi", forza)
	_pozione_stato = res
	aggiorna()
	return res


func avanzamento_stato() -> Dictionary:
	return _avanzamento.duplicate(true)


# --- Interrogabile dai test / UI --------------------------------------

func cella_stato(pathway_id: String, n: int) -> String:
	return str(_stati.get("%s:%d" % [pathway_id, n], "ignoto"))


func abilita_elencate() -> Array:
	return _abilita.duplicate()


func prossima_sequenza_nome() -> String:
	return _prossima_nome


func testo_visibile() -> String:
	return "diagramma"


# --- Interno ----------------------------------------------------------

func _stato(pid: String, n: int, mio: String, mia_seq: int, kn: Node) -> String:
	if pid == mio and n == mia_seq:
		return "corrente"
	if pid == mio and n >= mia_seq:
		return "noto"
	if kn != null and (kn.call("conosce", "pathway:%s" % pid)
			or kn.call("conosce", "sequenza:%s:%d" % [pid, n])):
		return "noto"
	if pid == mio and n == mia_seq - 1:
		return "prossima"
	return "ignoto"


func _cella_cella(stato: String) -> Control:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(44, 13)
	match stato:
		"corrente": r.color = C_CORRENTE
		"noto": r.color = C_NOTO
		"prossima": r.color = C_PROSSIMA
		_: r.color = C_IGNOTO
	return r


func _cella_testo(t: String, ruota: bool = false) -> Control:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size = Vector2(44 if ruota else 24, 13)
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 8)
	return l


func _riga(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _n(path: String) -> Node:
	return get_node_or_null(path)
