extends CharacterBody2D
## Nemico base con telegrafia. Macchina a stati esplicita; ogni attacco ha
## una fase di ANTICIPO leggibile (il tell) la cui durata vive in
## data/animations.json (nemico_base.anticipo), non qui.
##
## Monta StatsComponent (hp) e PosturaComponent (guardia, US-010). Alla morte
## NON si distrugge: emette "morto" e lascia decidere a chi l'ha generato.
##
## NIENTE class_name: coerente col progetto.

signal morto(chi: Node)
signal stato_cambiato(nuovo: String)

enum Stato { IDLE, INSEGUIMENTO, ANTICIPO, ATTACCO, RECUPERO, STAGGER, MORTO }

const CATEGORIA_ANIM := "nemico_base"

@onready var _anim: AnimatedSprite2D = $AnimationMachine
@onready var _stats: Node = $StatsComponent
@onready var _postura: Node = $PosturaComponent
@onready var _hitbox: Area2D = $Hitbox
@onready var _hurtbox: Area2D = $Hurtbox

var _stato: int = Stato.IDLE
var _bersaglio: Node2D = null
var _cfg: Dictionary = {}
var _dir_sguardo: String = "down"
var _recupero_left: float = 0.0
## Tempo rimasto nella fase di anticipo. La durata la fissa il tell sonoro
## (audio.json.telegraph[...].anticipo_ms), non l'animazione: US-020.
var _anticipo_left: float = 0.0

## Sequenza di questo nemico (US-804): il default combacia con
## StatsComponent.SEQUENZA_INIZIALE finche' nessun layout la sovrascrive
## (override per-nemico, US-806). E' il valore che _su_morte riporta come
## sequenza_bersaglio in enemy_defeated.
var sequenza: int = 9

## US-806: sottoinsieme di data/balance.json.nemico_base impostato dal
## layout PRIMA che il nemico entri nell'albero (region_scene.gd::
## _crea_nemici). Mergiato su _cfg in _ready(): ogni chiave che lo script
## gia' legge con _cfg.get(...) diventa sovrascrivibile per-istanza senza
## altre righe. {} = comportamento di sempre (il nemico da banco di prova).
var override: Dictionary = {}

## US-804: dal momento in cui il nemico entra in INSEGUIMENTO (l'inizio
## dello scontro) fino alla morte, se il player ha lanciato un'abilita' o
## subito danno -- per il payload di enemy_defeated (senza_abilita,
## senza_subire_danno). true finche' non succede.
var _senza_abilita: bool = true
var _senza_subire_danno: bool = true


func _ready() -> void:
	add_to_group("nemici")
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		# duplicate(): get_balance() torna il Dictionary CONDIVISO di GameData,
		# non una copia (US-806) — mergiare l'override lì dentro corromperebbe
		# nemico_base per ogni altro nemico dell'intera partita.
		_cfg = (gd.call("get_balance", "nemico_base") as Dictionary).duplicate(true)
	_cfg.merge(override, true)

	_postura.call("configura",
		float(_cfg.get("postura_massimo", 60.0)), 3.0, 15.0)
	_hitbox.call("configura",
		float(_cfg.get("angolo_arco", 90.0)), float(_cfg.get("raggio_arco", 24.0)))
	_hitbox.collision_mask = 4  # colpisce le hurtbox (layer 3)

	_anim.call("configura", CATEGORIA_ANIM)
	_anim.evento_frame.connect(_su_evento_anim)
	_anim.animazione_finita.connect(_su_anim_finita)
	_hitbox.ha_colpito.connect(_su_colpo_inflitto)
	_stats.died.connect(_su_morte)
	_postura.postura_rotta.connect(_su_postura_rotta)
	_postura.vulnerabilita_finita.connect(func() -> void:
		if _stato == Stato.STAGGER:
			_vai(Stato.IDLE))

	_bersaglio = get_tree().get_first_node_in_group("player")
	_vai(Stato.IDLE)


func _physics_process(delta: float) -> void:
	if _stato == Stato.MORTO:
		return

	var dist: float = INF
	if is_instance_valid(_bersaglio):
		dist = global_position.distance_to(_bersaglio.global_position)
		_guarda_verso(_bersaglio.global_position)

	match _stato:
		Stato.IDLE:
			velocity = Vector2.ZERO
			if dist <= float(_cfg.get("raggio_aggro", 140.0)):
				_vai(Stato.INSEGUIMENTO)
		Stato.INSEGUIMENTO:
			if dist <= float(_cfg.get("raggio_attacco", 26.0)):
				_vai(Stato.ANTICIPO)
			elif dist > float(_cfg.get("raggio_aggro", 140.0)) * 1.3:
				_vai(Stato.IDLE)
			elif is_instance_valid(_bersaglio):
				var v: float = _stats.get_stat("velocita")
				velocity = global_position.direction_to(_bersaglio.global_position) * v
		Stato.ANTICIPO:
			velocity = Vector2.ZERO
			_anticipo_left -= delta
			if _anticipo_left <= 0.0:
				_vai(Stato.ATTACCO)
		Stato.ATTACCO, Stato.STAGGER:
			velocity = Vector2.ZERO
		Stato.RECUPERO:
			velocity = Vector2.ZERO
			_recupero_left -= delta
			if _recupero_left <= 0.0:
				_vai(Stato.IDLE)

	move_and_slide()
	_aggiorna_anim_locomozione()


func _vai(nuovo: int) -> void:
	if _stato == nuovo:
		return
	_stato = nuovo
	stato_cambiato.emit(Stato.keys()[nuovo])
	match nuovo:
		Stato.INSEGUIMENTO:
			_inizia_tracciamento_scontro()
		Stato.ANTICIPO:
			_anim.modulate = Color(1.0, 0.5, 0.4)  # tell visivo
			_anim.call("riproduci", "anticipo", _dir_sguardo)
			_anticipo_left = _fai_partire_tell()
		Stato.ATTACCO:
			_anim.modulate = Color.WHITE
			var facing: Vector2 = _vettore_sguardo()
			_hitbox.position = facing * 6.0
			_hitbox.rotation = facing.angle()
			_anim.call("riproduci", "attack", _dir_sguardo)
		Stato.RECUPERO:
			_hitbox.call("disattiva")
			_recupero_left = float(_cfg.get("recupero_s", 0.6))
		Stato.STAGGER:
			_anim.modulate = Color(0.7, 0.7, 1.0)
			_hitbox.call("disattiva")
			_anim.call("riproduci", "stagger", _dir_sguardo)
		Stato.IDLE:
			_anim.modulate = Color.WHITE


func _su_evento_anim(nome: String) -> void:
	match nome:
		"hitbox_on":
			_hitbox.call("attiva",
				float(_cfg.get("danno_attacco", 10.0)),
				float(_cfg.get("stagger_attacco", 8.0)), self,
				str(_cfg.get("tag_danno_attacco", "fisico")))
		"hitbox_off":
			_hitbox.call("disattiva")


## Fa partire il tell sonoro dell'attacco e restituisce la durata della fase
## di anticipo (in secondi). Quale tell usa e' un dato:
## balance.json.nemico_base.telegraph -> audio.json.telegraph[id].
func _fai_partire_tell() -> float:
	var am: Node = get_node_or_null("/root/AudioManager")
	var id: String = str(_cfg.get("telegraph", ""))
	if am == null or id.is_empty():
		return 0.5  # setup rotto (nessun AudioManager o telegraph): fallback
	var dur: float = am.call("tell", id, global_position)
	return dur if dur > 0.0 else 0.5


func _su_anim_finita(stato_anim: String) -> void:
	if _stato == Stato.MORTO:
		return
	# L'anticipo NON e' piu' guidato dall'animazione: la sua durata la fissa
	# anticipo_ms del tell (US-020). L'anim 'anticipo' e' solo cosmetica e puo'
	# finire prima o dopo la fase reale.
	if stato_anim == "attack":
		_vai(Stato.RECUPERO)


func _su_colpo_inflitto(_bersaglio: Node, _danno: float, _tag: String = "") -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("feedback", "hit_light")


func _su_postura_rotta() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("feedback", "posture_break")
	var vfx: Node = get_node_or_null("/root/Vfx")
	if vfx != null:
		vfx.call("evento_combat", "posture_break")
	if _stato != Stato.MORTO:
		_vai(Stato.STAGGER)


func _su_morte() -> void:
	_stato = Stato.MORTO
	stato_cambiato.emit("MORTO")
	velocity = Vector2.ZERO
	_hitbox.call("disattiva")
	set_deferred("collision_layer", 0)
	_hurtbox.set_deferred("monitorable", false)
	_anim.modulate = Color.WHITE
	_anim.call("riproduci", "death", _dir_sguardo)
	# US-210B/US-804: il nemico e' sempre sconfitto dal giocatore in fase 1.
	# Payload dai filtri di data/schema/tracked_events.json: booleani
	# ESPLICITI (false incluso), cosi' un filtro come senza_abilita:true
	# puo' davvero non matchare. tipo_arma resta fuori (nessuna Sequenza
	# 9 attiva lo usa oggi).
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null:
		et.call("emit_event", "enemy_defeated", {
			"senza_abilita": _senza_abilita,
			"senza_subire_danno": _senza_subire_danno,
			"sequenza_bersaglio": sequenza,
			"tag_nemico": str(_cfg.get("tag", "")),
		})
	_lascia_caratteristica()
	_lascia_oggetto()
	morto.emit(self)
	_avvia_dissolvenza_cadavere()


## US-804: azzera il tracciamento e si aggancia (una sola volta) ai segnali
## che possono farlo diventare false. Chiamato a ogni ingresso in
## INSEGUIMENTO: uno scontro nuovo riparte "senza abilita'/senza danno"
## anche se il nemico aveva gia' perso l'aggro prima.
func _inizia_tracciamento_scontro() -> void:
	_senza_abilita = true
	_senza_subire_danno = true
	if not is_instance_valid(_bersaglio):
		return
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if ae != null and not ae.ability_executed.is_connected(_su_player_abilita):
		ae.ability_executed.connect(_su_player_abilita)
	var hb: Node = _bersaglio.get_node_or_null("Hurtbox")
	if hb != null and not hb.colpito.is_connected(_su_player_colpito):
		hb.colpito.connect(_su_player_colpito)


func _su_player_abilita(_ability_id: String, caster: Node, _result: Dictionary) -> void:
	if caster == _bersaglio:
		_senza_abilita = false


## Hurtbox.colpito(danno, stagger, da, tag_danno): la parata perfetta
## emette con danno 0 (hurtbox.gd) e non conta come "subire danno".
func _su_player_colpito(danno: float, _stagger: float, _da: Node, _tag: String) -> void:
	if danno > 0.0:
		_senza_subire_danno = false


## US-214B: pulizia di default del cadavere. Il segnale 'morto' resta per chi
## vuole gestirlo; se nessuno lo fa, il nemico morto sfuma e si libera invece
## di restare a schermo identico a uno vivo. permanenza_s 0 = resta per sempre.
func _avvia_dissolvenza_cadavere() -> void:
	var c: Dictionary = _cfg.get("cadavere", {})
	var permanenza: float = float(c.get("permanenza_s", 0.0))
	var dissolvenza: float = float(c.get("dissolvenza_s", 1.0))
	if permanenza <= 0.0:
		return
	var t := get_tree().create_timer(permanenza)
	t.timeout.connect(func() -> void:
		if not is_instance_valid(self) or _stato != Stato.MORTO:
			return
		var tw := create_tween()
		tw.tween_property(_anim, "modulate:a", 0.0, maxf(dissolvenza, 0.05))
		tw.tween_callback(queue_free))


## US-207: alla morte, con la probabilita' dei dati, lascia a terra la
## Caratteristica Beyonder del suo (Pathway, Sequenza).
func _lascia_caratteristica() -> void:
	var spec: Dictionary = _cfg.get("caratteristica", {})
	if spec.is_empty():
		return
	if randf() > float(spec.get("probabilita", 0.0)):
		return
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var car: Dictionary = gd.call("characteristic_for",
		str(spec.get("pathway_id", "")), int(spec.get("sequence", -1)))
	if car.is_empty():
		return
	var pickup := preload("res://scripts/characteristic_pickup.gd").new()
	get_parent().add_child(pickup)
	pickup.call("setup", str(car.get("id", "")), global_position)


## US-809a: alla morte, con probabilita' drop_probabilita, lascia a terra
## UN item scelto fra quelli di override.oggetti_a_morte (dal layout.drop
## della regione, via world_scene.gd::_crea_nemici). Vuoto o assente (il
## nemico da banco di prova, ogni regione senza layout) -> no-op.
func _lascia_oggetto() -> void:
	var oggetti: Array = _cfg.get("oggetti_a_morte", [])
	if oggetti.is_empty():
		return
	if randf() > float(_cfg.get("drop_probabilita", 0.0)):
		return
	var item_id: String = _scegli_drop_pesato(oggetti)
	var pickup := preload("res://scripts/item_pickup.gd").new()
	get_parent().add_child(pickup)
	pickup.call("setup", item_id, global_position)


## US-1104 (fase 11): la scelta pesa per rarita' (data/schema/item_rarity.json
## 'peso_drop') invece di uniforme - un oggetto raro/leggendario esce molto
## meno spesso di uno comune dalla stessa tabella. Somma cumulativa
## classica; senza GameData (non dovrebbe capitare fuori dai test piu'
## isolati) resta uniforme, comportamento identico a prima di questa story.
func _scegli_drop_pesato(oggetti: Array) -> String:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return str(oggetti[randi() % oggetti.size()])
	var pesi: Array = []
	var totale: float = 0.0
	for iid in oggetti:
		var rarita: String = str(gd.call("rarita_di", str(iid)))
		var peso: float = float((gd.call("get_item_rarity", rarita) as Dictionary).get("peso_drop", 1.0))
		pesi.append(peso)
		totale += peso
	if totale <= 0.0:
		return str(oggetti[randi() % oggetti.size()])
	var scelta: float = randf() * totale
	var accumulo: float = 0.0
	for i in oggetti.size():
		accumulo += float(pesi[i])
		if scelta <= accumulo:
			return str(oggetti[i])
	return str(oggetti[oggetti.size() - 1])


func stato() -> String:
	return Stato.keys()[_stato]


## US-806: per l'aggregato di area_cleared in region_scene.gd (letto solo
## alla morte, via 'morto').
func senza_abilita() -> bool:
	return _senza_abilita


func _guarda_verso(punto: Vector2) -> void:
	var d: Vector2 = global_position.direction_to(punto)
	if absf(d.x) >= absf(d.y):
		_dir_sguardo = "right" if d.x > 0.0 else "left"
	else:
		_dir_sguardo = "down" if d.y > 0.0 else "up"


func _vettore_sguardo() -> Vector2:
	match _dir_sguardo:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		_: return Vector2.DOWN


func _aggiorna_anim_locomozione() -> void:
	if _stato == Stato.IDLE:
		_anim.call("riproduci", "idle", _dir_sguardo)
	elif _stato == Stato.INSEGUIMENTO:
		_anim.call("riproduci", "walk", _dir_sguardo)
