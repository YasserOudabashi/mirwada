extends CharacterBody2D
## Giocatore: movimento a 8 direzioni + attacco leggero in mischia.
##
## Le animazioni e il loro timing vengono da data/animations.json tramite
## AnimationMachine: questo script decide solo QUALE stato
## ("walk"/"idle"/"attack_light") e in quale delle 4 direzioni. Le diagonali
## riusano la direzione orizzontale, come da convenzioni.direzioni.
##
## L'attacco: l'input avvia l'animazione "attack_light"; la hitbox si apre e
## si chiude sugli eventi hitbox_on/hitbox_off che la macchina di animazione
## emette dai frame del JSON. Non si puo' ri-attaccare finche' l'animazione
## non e' finita (quindi nemmeno durante il recupero). Danno e arco vengono
## da data/balance.json; sfx, hitstop e shake da AudioManager
## (data/audio.json.combat_feedback), mai hardcoded qui.
##
## NIENTE class_name: coerente col resto del progetto.

const ACCELERAZIONE := 1400.0
const ATTRITO := 1600.0
const SOGLIA_MOTO := 5.0
const CATEGORIA_ANIM := "personaggio"
const STATO_ATTACCO := "attack_light"

const FACING := {
	"down": Vector2.DOWN, "up": Vector2.UP,
	"left": Vector2.LEFT, "right": Vector2.RIGHT,
}

const Hurtbox := preload("res://scripts/hurtbox.gd")

@onready var _stats: Node = $StatsComponent
@onready var _anim: AnimatedSprite2D = $AnimationMachine
@onready var _hitbox: Area2D = $Hitbox
@onready var _hurtbox: Area2D = $Hurtbox

var _dir_sguardo: String = "down"
var _attaccando: bool = false
var _combat: Dictionary = {}

var _dashing: bool = false
var _dash_vel: Vector2 = Vector2.ZERO
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dist_accum: float = 0.0  # emettitore distanza_percorsa (US-331)

var _parando: bool = false

@onready var _audio: Node = get_node_or_null("/root/AudioManager")


func _ready() -> void:
	_anim.call("configura", CATEGORIA_ANIM)
	_anim.evento_frame.connect(_su_evento_anim)
	_anim.animazione_finita.connect(_su_anim_finita)
	_anim.finestra_cambiata.connect(_su_finestra_anim)
	_hitbox.ha_colpito.connect(_su_colpo_inflitto)
	_hurtbox.parata_riuscita.connect(_su_parata_riuscita)
	_hurtbox.colpito.connect(_su_danno_subito)

	# Bonus di Sequenza del Pathway corrente (US-201): il giocatore entra in
	# scena dopo gli autoload, quindi li richiede lui una volta pronto.
	var prog: Node = get_node_or_null("/root/Progression")
	if prog != null:
		prog.call("riapplica_al_giocatore")
	var equip: Node = get_node_or_null("/root/Equipment")
	if equip != null:
		equip.call("riapplica_al_giocatore")

	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		_combat = gd.call("get_balance", "combattimento")
	var arco: Dictionary = _combat.get("attacco_leggero", {})
	_hitbox.call("configura",
		float(arco.get("angolo", 100.0)), float(arco.get("raggio", 22.0)))

	_anim.call("riproduci", "idle", _dir_sguardo)


func _physics_process(delta: float) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	if _dashing:
		_dash_left -= delta
		velocity = _dash_vel
		move_and_slide()
		if _dash_left <= 0.0:
			_fine_dash()
		return

	if Input.is_action_just_pressed("parata") and not _attaccando:
		_inizia_parata()
	elif Input.is_action_just_released("parata"):
		_fine_parata()

	if Input.is_action_just_pressed("schivata") and not _attaccando and not _parando and _dash_cd <= 0.0:
		start_dash({})
		return

	if Input.is_action_just_pressed("attacco") and not _attaccando and not _parando:
		_inizia_attacco()

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var vel_max: float = _stats.get_stat("velocita")

	if input != Vector2.ZERO:
		# get_vector normalizza gia' la diagonale: nessuna spinta extra in obliquo.
		velocity = velocity.move_toward(input * vel_max, ACCELERAZIONE * delta)
		if not _attaccando:
			_aggiorna_sguardo(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ATTRITO * delta)

	move_and_slide()
	_aggiorna_animazione()

	# emettitore distanza_percorsa (US-331): si accumula e si versa a blocchi
	# di 64px per non chiamare TalentTracker 60 volte al secondo.
	_dist_accum += velocity.length() * delta
	if _dist_accum >= 64.0:
		var tt: Node = get_node_or_null("/root/TalentTracker")
		if tt != null:
			tt.call("registra", "distanza_percorsa", _dist_accum)
		_dist_accum = 0.0


## Direzione guardata come vettore. La cerca ability_engine per orientare
## proiettili e archi (get_facing).
func get_facing() -> Vector2:
	return FACING.get(_dir_sguardo, Vector2.DOWN)


func sta_attaccando() -> bool:
	return _attaccando


func sta_schivando() -> bool:
	return _dashing


func schivata_pronta() -> bool:
	return _dash_cd <= 0.0


## Entry point della schivata: lo usano sia l'input "schivata" sia la
## primitiva "dash" di ability_engine (che cerca start_dash sul caster).
func start_dash(spec: Dictionary) -> void:
	if _dashing:
		return
	var b: Dictionary = _combat.get("schivata", {})
	var distanza: float = float(spec.get("distanza", b.get("distanza", 96.0)))
	var durata: float = maxf(float(spec.get("durata", b.get("durata", 0.18))), 0.01)
	_dash_cd = float(spec.get("cooldown", b.get("cooldown", 0.6)))

	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = get_facing()
	dir = dir.normalized()
	_aggiorna_sguardo(dir)

	_dashing = true
	_dash_left = durata
	_dash_vel = dir * (distanza / durata)
	_anim.call("riproduci", "dash", _dir_sguardo)
	if _audio != null:
		_audio.call("feedback", "dash")


func _fine_dash() -> void:
	_dashing = false
	velocity = _dash_vel * 0.2  # un filo di scivolata all'uscita
	_hurtbox.call("set_invulnerabile", false)
	_anim.modulate = Color.WHITE


func _inizia_attacco() -> void:
	_attaccando = true
	var facing: Vector2 = get_facing()
	_hitbox.position = Vector2(0, -4) + facing * 4.0
	_hitbox.rotation = facing.angle()
	_anim.call("riproduci", STATO_ATTACCO, _dir_sguardo)


func _su_evento_anim(nome: String) -> void:
	match nome:
		"hitbox_on":
			var arco: Dictionary = _combat.get("attacco_leggero", {})
			_hitbox.call("attiva",
				float(arco.get("danno", 12.0)), float(arco.get("stagger", 6.0)), self,
				str(arco.get("tag_danno", "")))
		"hitbox_off":
			_hitbox.call("disattiva")


func _su_anim_finita(stato: String) -> void:
	if stato == STATO_ATTACCO:
		_attaccando = false
		_hitbox.call("disattiva")


## Finestre guidate dai frame di animations.json. "iframe": invulnerabilita'
## del dash (US-009); l'indicatore visivo e' la tinta ciano dello sprite.
func _su_finestra_anim(nome: String, attiva: bool) -> void:
	if nome == "iframe":
		_hurtbox.call("set_invulnerabile", attiva)
		_anim.modulate = Color(0.55, 0.9, 1.0, 0.75) if attiva else Color.WHITE
	elif nome == "parata_perfetta" and _parando:
		_hurtbox.call("set_parata",
			Hurtbox.Parata.PERFETTA if attiva else Hurtbox.Parata.BLOCCO)


func _inizia_parata() -> void:
	if _attaccando or _dashing or _parando:
		return
	_parando = true
	_hurtbox.call("set_parata", Hurtbox.Parata.BLOCCO)
	_anim.call("riproduci", "parry", _dir_sguardo)


func _fine_parata() -> void:
	_parando = false
	_hurtbox.call("set_parata", Hurtbox.Parata.NESSUNA)


## Parata riuscita: sfx/hitstop/shake distinti (parry_perfect suona diverso
## da parry_normal, audio.json), e su parata perfetta si erode la postura
## dell'attaccante.
func _su_parata_riuscita(perfetta: bool, attaccante: Node) -> void:
	if _audio != null:
		_audio.call("feedback", "parry_perfect" if perfetta else "parry_normal")
	if perfetta:
		_traccia("perfect_parry", {})
		var vfx: Node = get_node_or_null("/root/Vfx")
		if vfx != null:
			vfx.call("evento_combat", "parry_perfect")
	if not perfetta or attaccante == null:
		return
	var b: Dictionary = _combat.get("parata", {})
	var danno_postura: float = float(b.get("danno_postura_parata_perfetta", 40.0))
	var post: Node = _cerca_postura(attaccante)
	if post != null:
		post.call("erodi", danno_postura)


func _cerca_postura(nodo: Node) -> Node:
	if nodo.has_method("erodi"):
		return nodo
	for c in nodo.get_children():
		if c.has_method("erodi"):
			return c
	return null


## sfx + hitstop + shake del colpo inferto: tutto in AudioManager, dai dati
## (audio.json.combat_feedback). Niente hitstop hardcoded qui.
func _su_colpo_inflitto(_bersaglio: Node, danno: float, tag_danno: String = "") -> void:
	if _audio != null:
		_audio.call("feedback", "hit_light")
	if danno > 0.0:
		_traccia("damage_dealt", {"quantita": danno, "tag_danno": tag_danno})


func _su_danno_subito(danno: float, _stagger: float, _da: Node, tag_danno: String = "") -> void:
	if danno > 0.0 and _audio != null:
		_audio.call("feedback", "damage_taken")
	if danno > 0.0:
		_traccia("damage_taken", {"quantita": danno, "tag_danno": tag_danno})


## Inoltra un evento all'EventTracker (US-210B). Agganciato, non riscritto:
## i sistemi di combattimento restano ignari dell'Acting Method.
func _traccia(evento: String, dati: Dictionary) -> void:
	var et: Node = Engine.get_main_loop().root.get_node_or_null("EventTracker")
	if et != null:
		et.call("emit_event", evento, dati)


## La direzione dominante decide lo sprite. In obliquo vince l'orizzontale:
## e' la scelta di data/animations.json (nessuno sprite diagonale).
func _aggiorna_sguardo(input: Vector2) -> void:
	if absf(input.x) >= absf(input.y):
		_dir_sguardo = "right" if input.x > 0.0 else "left"
	else:
		_dir_sguardo = "down" if input.y > 0.0 else "up"


func _aggiorna_animazione() -> void:
	if _attaccando or _dashing or _parando:
		return
	var stato: String = "walk" if velocity.length() > SOGLIA_MOTO else "idle"
	_anim.call("riproduci", stato, _dir_sguardo)
