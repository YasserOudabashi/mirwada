extends Node2D
## US-1505: un boss e' un dato (balance.json boss.<id>). Questo nodo sta dentro un nemico (enemy.gd) e gli aggiunge:
## - la vita moltiplicata (vita_x);
## - le fasi a soglie di vita: entrando in una fase, la sua "cfg" (chiavi di nemico_base: tell, danno, recupero...)
##   si somma alla configurazione del nemico e arrivano i suoi gregari (tipi di nemici_tipi) attorno al boss;
## - l'arena: quando il boss ti affronta si chiude un cerchio (raggio nei dati) che non si puo' lasciare; si riapre
##   quando il boss muore, quando muori tu o se finisci lontano (una porta, un teletrasporto);
## - la barra del boss nell'HUD col suo nome (gruppo "hud": mostra_boss / nascondi_boss).
## Nessun boss ha codice suo: tutto quello che cambia sta nei dati.
##
## NIENTE class_name: coerente col progetto.

signal fase_cambiata(indice: int)
signal arena_cambiata(chiusa: bool)

var boss_id: String = ""
var dati: Dictionary = {}
var fase: int = -1                  # -1: l'arena non si e' ancora chiusa
var arena_chiusa: bool = false
var centro: Vector2 = Vector2.ZERO

var _nemico: Node2D = null
var _stats: Node = null
var _player: Node2D = null
var _anello: Node2D = null


## Mette il boss dentro un nemico appena creato da un layout (mondo.gd per il mondo, interior_scene.gd per i varchi).
static func monta(e: Node, spec: Dictionary) -> void:
	if not spec.has("boss"):
		return
	var b: Node2D = load("res://scripts/boss.gd").new()
	b.name = "Boss"
	b.set("boss_id", str(spec["boss"]))
	e.add_child(b)


## Un boss battuto non torna (bestiario dell'utente): WorldState lo ricorda, anche nel salvataggio.
static func vinto(spec: Dictionary) -> bool:
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("WorldState")
	return spec.has("boss") and ws != null and bool(ws.call("preso", "boss:" + str(spec["boss"])))


func _ready() -> void:
	_nemico = get_parent() as Node2D
	var gd: Node = get_node_or_null("/root/GameData")
	dati = ((gd.call("get_balance", "boss") as Dictionary).get(boss_id, {}) as Dictionary) if gd != null else {}
	_stats = _nemico.get_node_or_null("StatsComponent")
	if dati.is_empty() or _stats == null:
		push_warning("[Boss] '%s' senza dati in balance.json boss" % boss_id)
		return
	_nemico.add_to_group("boss")
	(_nemico.get("_cfg") as Dictionary)["name_i18n"] = str(dati.get("name_i18n", ""))
	var etichetta: Node = _nemico.get_node_or_null("Nome")      # il nome del boss sta nella sua barra in alto
	if etichetta != null:
		etichetta.queue_free()
	_stats.call("set_base", "hp_max", _stats.call("get_base", "hp_max") * float(dati.get("vita_x", 1.0)))
	_stats.set("hp", _stats.get_stat("hp_max"))
	_stats.hp_changed.connect(_su_vita)
	_stats.died.connect(_apri)
	_stats.died.connect(func() -> void:
		var ws: Node = get_node_or_null("/root/WorldState")
		if ws != null:
			ws.call("prendi", "boss:" + boss_id))


func _fasi() -> Array:
	return dati.get("fasi", [])


## La fase giusta per la vita che resta (0..1): l'ultima la cui soglia "da" e' sopra o uguale.
func fase_per(frazione: float) -> int:
	var f := 0
	for i in _fasi().size():
		if frazione <= float((_fasi()[i] as Dictionary).get("da", 1.0)) + 0.0001:
			f = i
	return f


func _su_vita(hp: float, hp_max: float) -> void:
	if hp <= 0.0 or fase < 0:
		return
	var nuova: int = fase_per(hp / maxf(hp_max, 1.0))
	while fase < nuova:                                   # un colpo grosso puo' saltare una fase: le fa tutte
		_entra(fase + 1)


func _entra(i: int) -> void:
	fase = i
	var f: Dictionary = _fasi()[i]
	(_nemico.get("_cfg") as Dictionary).merge((f.get("cfg", {}) as Dictionary).duplicate(true), true)
	var g: Dictionary = f.get("gregari", {})
	for k in int(g.get("quanti", 0)):
		_gregario(str(g.get("tipo", "")), k, int(g.get("quanti", 0)))
	var vfx: Node = get_node_or_null("/root/Vfx")
	if vfx != null:
		vfx.call("evento_combat", "posture_break", _nemico)
	fase_cambiata.emit(i)


## I gregari escono in cerchio attorno al boss, della sua Sequenza, e si accorgono subito del giocatore.
func _gregario(tipo: String, k: int, n: int) -> void:
	var e: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	e.set("tipo", tipo)
	e.set("override", {"attesa_iniziale_s": 0.0, "drop_probabilita": 0.0})
	var a: float = TAU * float(k) / float(maxi(n, 1))
	e.position = _nemico.position + Vector2(cos(a), sin(a)) * float(dati.get("gregari_distanza", 40.0))
	e.add_to_group("gregari")
	_nemico.get_parent().add_child(e)
	var seq: int = int(_nemico.get("sequenza"))
	e.set("sequenza", seq)
	e.get_node("StatsComponent").call("configure_from_balance", seq)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):                   # il mondo si popola prima che arrivi il giocatore
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if dati.is_empty() or not is_instance_valid(_player):
		return
	var a: Dictionary = dati.get("arena", {})
	var raggio: float = float(a.get("raggio", 160.0))
	if not arena_chiusa:
		if bool(_nemico.call("_ingaggiato")) and not bool(_stats.call("is_dead")):
			_chiudi()
		return
	var pstats: Node = _player.get_node_or_null("StatsComponent")
	var d: Vector2 = _player.global_position - centro
	if (pstats != null and bool(pstats.call("is_dead"))) or d.length() > raggio * float(a.get("fuga_x", 3.0)):
		_apri()                                           # morto, o portato lontano (porta, teletrasporto)
	elif d.length() > raggio:                             # il bordo non si passa
		_player.global_position = centro + d.normalized() * raggio


func _chiudi() -> void:
	arena_chiusa = true
	centro = _nemico.global_position
	_anello = preload("res://scripts/boss_arena.gd").new()
	_anello.set("raggio", float((dati.get("arena", {}) as Dictionary).get("raggio", 160.0)))
	_anello.set("colore", Color(str((dati.get("arena", {}) as Dictionary).get("colore", "#e43b44"))))
	_nemico.get_parent().add_child(_anello)
	_anello.global_position = centro
	if fase < 0:
		_entra(0)
	_su_vita(float(_stats.get("hp")), _stats.get_stat("hp_max"))     # i colpi presi prima di chiuderla
	get_tree().call_group("hud", "mostra_boss", str(_nemico.call("nome")), _stats)
	arena_cambiata.emit(arena_chiusa)


func _apri() -> void:
	if not arena_chiusa:
		return
	arena_chiusa = false
	if is_instance_valid(_anello):
		_anello.queue_free()
	get_tree().call_group("hud", "nascondi_boss")
	arena_cambiata.emit(arena_chiusa)

