extends VBoxContainer
## Pagina "diagramma dei Pathway" (US-224). 10 colonne (i Pathway attivi) x 10
## righe (Sequenze 9->0). Generato dai dati di GameData, mai disegnato a mano.
##
## FOG OF WAR sulla conoscenza (design-master cap. 5): una cella e' leggibile
## solo se il giocatore la conosce —
##   * la propria colonna, dalle Sequenze 9 fino a quella corrente (le ha
##     vissute),
##   * oppure un flag in KnowledgeStore ("pathway:<id>" o "sequenza:<id>:<n>").
## Il resto e' offuscato.
##
## La Sequenza corrente e' evidenziata e le sue abilita' sono elencate sotto.
## Nessun nome di Pathway/Sequenza hardcoded: solo id e chiavi i18n.

const C_NOTO := Color(0.74, 0.67, 0.5)
const C_IGNOTO := Color(0.22, 0.2, 0.17)
const C_CORRENTE := Color(0.4, 0.76, 0.82)

var _stati: Dictionary = {}   # "pid:n" -> "noto" | "ignoto" | "corrente"
var _abilita: Array = []
## US-708: i Pathway vicini verso cui si puo' fondere. Ogni voce:
## { id, scritto (percorso di fusione non-stub), puo (PathwayChange.puo_cambiare) }.
var _vicini: Array = []


func aggiorna() -> void:
	for c in get_children():
		c.queue_free()
	_stati.clear()
	_abilita.clear()
	_vicini.clear()

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

		_sezione_fusione(gd, prog, mio, pw)


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


# --- Interrogabile dai test / UI --------------------------------------

func cella_stato(pathway_id: String, n: int) -> String:
	return str(_stati.get("%s:%d" % [pathway_id, n], "ignoto"))


func abilita_elencate() -> Array:
	return _abilita.duplicate()


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
	return "ignoto"


func _cella_cella(stato: String) -> Control:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(44, 13)
	r.color = C_CORRENTE if stato == "corrente" else (C_NOTO if stato == "noto" else C_IGNOTO)
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
