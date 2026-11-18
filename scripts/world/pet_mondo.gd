extends Node2D
## 2026-11-18 (decisione dell'utente: il pet si doma nel mondo). Figlio del mondo (scripts/world/mondo.gd):
## - ogni specie di data/pets con "selvatico" vive nel suo luogo; vicino, "interagisci" con il suo nutrimento nello
##   zaino ne consuma uno e prova a domarla (PetSystem.doma, la domabilita' dei dati). Se va male scappa e torna al
##   prossimo momento del giorno; se va bene diventa il compagno;
## - il compagno (PetSystem.pet_attivo) segue Enel, con la sua figura (fogli pet_<specie>_<anim>.png).
## Niente nomi di specie nel codice: tutto da data/pets.
##
## NIENTE class_name: coerente col progetto.

const DISTANZA_SEGUE := 26.0
const VELOCITA := 90.0

var _selvatici: Dictionary = {}       # specie -> Area2D
var _spaventati: Array = []           # specie scappate in questo momento del giorno
var _vicino: String = ""
var _compagno: Node2D = null


func _ready() -> void:
	y_sort_enabled = true
	var ps: Node = get_node_or_null("/root/PetSystem")
	if ps != null:
		for s in ["pet_impostato", "pet_liberato", "pet_morto"]:
			ps.connect(s, func(_id: String) -> void: aggiorna())
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):
		ts.momento_cambiato.connect(func(_m: String) -> void:
			_spaventati.clear()
			aggiorna())
	aggiorna.call_deferred()


func _mondo() -> Node:
	return get_parent()


func _pet_attivo() -> String:
	var ps: Node = get_node_or_null("/root/PetSystem")
	return str((ps.call("pet_attivo") as Dictionary).get("pet_id", "")) if ps != null else ""


## Rifa' i selvatici (tutte le specie tranne il compagno e quelle appena scappate) e il compagno.
func aggiorna() -> void:
	for a in _selvatici.values():
		(a as Node).queue_free()
	_selvatici.clear()
	_vicino = ""
	var gd: Node = get_node_or_null("/root/GameData")
	var m: Node = _mondo()
	if gd == null or m == null or (m.get("dati") as Dictionary).is_empty():
		return
	var attivo: String = _pet_attivo()
	for pid in gd.call("pet_ids"):
		var s: Dictionary = gd.call("get_pet", str(pid))
		var id: String = str(s.get("id", ""))
		var sel: Dictionary = s.get("selvatico", {})
		if sel.is_empty() or id == attivo or id in _spaventati:
			continue
		var l: Variant = ((m.get("dati") as Dictionary).get("luoghi", {}) as Dictionary).get(str(sel.get("luogo", "")))
		if not (l is Array):
			continue
		var sc: Array = sel.get("scostamento", [0, 0])
		var c: Vector2i = m.call("cella_libera", Vector2i(int(l[0]) + int(sc[0]), int(l[1]) + int(sc[1])))
		var tile: float = float(m.get("tile"))
		_selvatici[id] = _selvatico(id, Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile), gd)
	_aggiorna_compagno(attivo)


func _figura(id: String) -> AnimatedSprite2D:
	var anim: AnimatedSprite2D = preload("res://scripts/animation_machine.gd").new()
	anim.name = "AnimationMachine"
	anim.call("configura", "pet", id)
	anim.call("riproduci", "idle", "down")
	return anim


func _selvatico(id: String, pos: Vector2, gd: Node) -> Area2D:
	var a := Area2D.new()
	a.name = "Selvatico_%s" % id
	a.position = pos
	var f := CollisionShape2D.new()
	var cerchio := CircleShape2D.new()
	cerchio.radius = 28.0
	f.shape = cerchio
	a.add_child(f)
	a.add_child(_figura(id))
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_color_override("font_outline_color", Color("#181425"))
	prompt.size = Vector2(160, 14)
	prompt.position = Vector2(-80, 10)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.text = tr("HUD_PROMPT_DOMA").format({"tasto": _mondo().call("_tasto_interagisci")})
	prompt.hide()
	a.add_child(prompt)
	a.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_vicino = id
			prompt.show())
	a.body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player") and _vicino == id:
			_vicino = ""
			prompt.hide())
	add_child(a)
	return a


func _unhandled_input(event: InputEvent) -> void:
	if _vicino.is_empty() or not event.is_action_pressed("interagisci"):
		return
	var book: Node = get_node_or_null("/root/Book")
	if book != null and bool(book.call("e_aperto")):
		return
	get_viewport().set_input_as_handled()
	prova_a_domare(_vicino)


## Prova a domare la specie: serve il suo nutrimento (avanzamento.nutrimento dei dati), che si consuma. -> esito
## "riuscita" | "fallita" | "serve" | "hai_gia".
func prova_a_domare(id: String) -> String:
	var gd: Node = get_node("/root/GameData")
	var ps: Node = get_node_or_null("/root/PetSystem")
	var inv: Node = get_node_or_null("/root/Inventory")
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var specie: Dictionary = gd.call("get_pet", id)
	var esca: String = str((specie.get("avanzamento", {}) as Dictionary).get("nutrimento", ""))
	var esito: String = ""
	if ps == null or inv == null:
		return ""
	if not _pet_attivo().is_empty():
		esito = "hai_gia"
		_avviso(p, tr("HUD_DOMA_HAI_GIA"))
	elif not esca.is_empty() and int(inv.call("conta", esca)) < 1:
		esito = "serve"
		_avviso(p, tr("HUD_DOMA_SERVE") % str(gd.call("tr_data", (gd.call("get_item", esca) as Dictionary).get("name_i18n", esca))))
	else:
		if not esca.is_empty():
			inv.call("rimuovi", esca, 1)
		if bool(ps.call("doma", id)):
			esito = "riuscita"
			_avviso(p, tr("HUD_DOMA_RIUSCITA") % str(gd.call("tr_data", specie.get("name_i18n", id))))
		else:
			esito = "fallita"
			_spaventati.append(id)
			_avviso(p, tr("HUD_DOMA_FALLITA"))
			aggiorna()
	return esito


func _avviso(p: Node2D, testo: String) -> void:
	if p != null and _mondo().has_method("_mostra_avviso"):
		_mondo().call("_mostra_avviso", p, testo)


# --- il compagno ---------------------------------------------------------

func _aggiorna_compagno(attivo: String) -> void:
	if _compagno != null and (attivo.is_empty() or str(_compagno.get_meta("specie", "")) != attivo):
		_compagno.queue_free()
		_compagno = null
	if attivo.is_empty() or _compagno != null:
		return
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	_compagno = Node2D.new()
	_compagno.name = "Compagno"
	_compagno.set_meta("specie", attivo)
	_compagno.add_child(_figura(attivo))
	add_child(_compagno)
	_compagno.position = (p.position if p != null else Vector2.ZERO) + Vector2(-DISTANZA_SEGUE, 6)


func compagno() -> Node2D:
	return _compagno


func _process(delta: float) -> void:
	if _compagno == null:
		return
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null or p.get_parent() != _mondo():           # negli interni il compagno aspetta fuori
		return
	var verso: Vector2 = p.position - _compagno.position
	var anim: AnimatedSprite2D = _compagno.get_node("AnimationMachine")
	var dir: String = ("right" if verso.x > 0.0 else "left") if absf(verso.x) >= absf(verso.y) else ("down" if verso.y > 0.0 else "up")
	if verso.length() > DISTANZA_SEGUE * 6.0:               # rimasto indietro (un viaggio, una soglia): raggiunge
		_compagno.position = p.position - verso.normalized() * DISTANZA_SEGUE
	elif verso.length() > DISTANZA_SEGUE:
		_compagno.position += verso.normalized() * minf(VELOCITA * delta, verso.length() - DISTANZA_SEGUE)
		anim.call("riproduci", "walk", dir)
	else:
		anim.call("riproduci", "idle", dir)
