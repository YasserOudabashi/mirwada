extends Node
## US-1304: il duello di un NPC come scena. Un NPC del roster con "duello" nei dati (oggi Aldo) si batte quando il
## suo dialogo ha scritto `flag_inizio`: l'NPC lascia il posto a un nemico con la sua Sequenza (NpcSystem), come ogni
## altro nemico dai dati. Nessuna regola di combattimento nuova. Finito lo scontro l'NPC torna e parte il dialogo
## della vittoria o della sconfitta, che scrive i suoi flag. Figlio del mondo (scripts/world/mondo.gd).

var _in_corso: Dictionary = {}          # npc_id -> il nemico


func _ready() -> void:
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de != null:
		de.dialogo_finito.connect(func(_d: String) -> void: controlla())
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):     # il mondo rifa' gli NPC: chi si sta battendo resta via
		ts.momento_cambiato.connect(func(_m: String) -> void: _nascondi_chi_combatte.call_deferred())


func in_corso(npc_id: String) -> bool:
	return _in_corso.has(npc_id)


## Fa partire i duelli accettati (il flag_inizio dei dati e' scritto e l'NPC e' qui).
func controlla() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var ks: Node = get_node_or_null("/root/KnowledgeStore")
	if gd == null or ks == null:
		return
	for n in gd.call("get_npcs"):
		var d: Dictionary = (n as Dictionary).get("duello", {})
		if not d.is_empty() and bool(ks.call("conosce", str(d.get("flag_inizio", "")))):
			inizia(str((n as Dictionary).get("id", "")))


func inizia(npc_id: String) -> bool:
	var mondo: Node = get_parent()
	var npc: Node2D = mondo.get_node_or_null("Npc_%s" % npc_id)
	var d: Dictionary = get_node("/root/GameData").call("get_npc", npc_id).get("duello", {})
	if npc == null or d.is_empty() or _in_corso.has(npc_id):
		return false
	var ks: Node = get_node("/root/KnowledgeStore")
	for f in ["flag_inizio", "flag_offerta"]:               # l'offerta e' spesa: torna al prossimo salto di tier
		ks.call("imposta", str(d.get(f, "")), false)
	var ns: Node = get_node_or_null("/root/NpcSystem")
	var sequenza: int = int(ns.call("sequenza_npc", npc_id)) if ns != null else 9
	var e: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	e.set("override", (d.get("override", {}) as Dictionary).duplicate(true))
	e.position = npc.position
	e.set_meta("duello", npc_id)
	mondo.add_child(e)
	e.set("sequenza", sequenza)
	e.get_node("StatsComponent").call("configure_from_balance", sequenza)
	e.connect("morto", func(_chi: Node) -> void: _finisci(npc_id, true))
	_in_corso[npc_id] = e
	_nascondi_chi_combatte()
	var p: Node = get_tree().get_first_node_in_group("player")
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	if stats != null and not stats.died.is_connected(_su_giocatore_caduto):
		stats.died.connect(_su_giocatore_caduto)
	return true


func _su_giocatore_caduto() -> void:
	for npc_id in _in_corso.keys():
		_finisci(str(npc_id), false)


func _finisci(npc_id: String, vinto: bool) -> void:
	if not _in_corso.has(npc_id):
		return
	var e: Node = _in_corso[npc_id]
	_in_corso.erase(npc_id)
	if not vinto and is_instance_valid(e):
		e.queue_free()
	var npc: Node = get_parent().get_node_or_null("Npc_%s" % npc_id)
	if npc != null:
		get_parent().call("_mostra", npc, true)
	var d: Dictionary = get_node("/root/GameData").call("get_npc", npc_id).get("duello", {})
	# il tempo di vedere cadere chi ha perso (e, se e' il giocatore, di rialzarsi), poi si parla
	get_tree().create_timer(float(d.get("pausa_s", 1.5))).timeout.connect(parla_dopo.bind(npc_id, vinto))


## Il dialogo della fine del duello (dialogo_vinto / dialogo_perso dei dati).
func parla_dopo(npc_id: String, vinto: bool) -> void:
	var d: Dictionary = get_node("/root/GameData").call("get_npc", npc_id).get("duello", {})
	var dialogo: String = str(d.get("dialogo_vinto" if vinto else "dialogo_perso", ""))
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de != null and not dialogo.is_empty() and not bool(de.call("in_corso")):
		de.call("avvia", dialogo, npc_id)


func _nascondi_chi_combatte() -> void:
	for npc_id in _in_corso:
		var npc: Node = get_parent().get_node_or_null("Npc_%s" % npc_id)
		if npc != null:
			get_parent().call("_mostra", npc, false)
