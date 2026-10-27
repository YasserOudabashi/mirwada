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

## Bug report utente 2026-09-10: a 0 hp il giocatore restava giocabile
## all'infinito, StatsComponent.died non era collegato a nulla per il
## giocatore (solo enemy.gd lo ascolta). true durante l'animazione "death":
## _physics_process si ferma, niente input processato.
var _morto: bool = false

## US-802: hotbar. true mentre l'animazione "cast" e' in corso, cosi'
## _aggiorna_animazione() non la sovrascrive col walk/idle del frame dopo
## (stesso ruolo di _attaccando per l'attacco).
var _castando: bool = false
## US-8B80: il gesto fuori dal combattimento in corso (interact, pickup, drink, ritual; "" = nessuno). Finche' dura
## l'animazione di camminata/fermo non lo copre; camminare lo interrompe.
var _gesto: String = ""

@onready var _audio: Node = get_node_or_null("/root/AudioManager")

## Etichetta col nome del personaggio sopra lo sprite: come gli NPC (US-813),
## cosi' a schermo si distingue quale figura sei. Il testo viene da
## GameState.nome_personaggio, aggiornato quando parte una partita.
var _nome_lbl: Label = null
var _icone_stato: Node2D = null


func _ready() -> void:
	_monta_nome()
	_icone_stato = _monta_icone_stato()
	_posiziona_sopra()
	_anim.call("configura", CATEGORIA_ANIM)
	_anim.evento_frame.connect(_su_evento_anim)
	_anim.animazione_finita.connect(_su_anim_finita)
	_anim.finestra_cambiata.connect(_su_finestra_anim)
	_hitbox.ha_colpito.connect(_su_colpo_inflitto)
	_hurtbox.parata_riuscita.connect(_su_parata_riuscita)
	_hurtbox.colpito.connect(_su_danno_subito)
	_stats.died.connect(_su_morte)
	_stats.forma_cambiata.connect(_su_forma)
	var ps: Node = get_node_or_null("/root/PotionSystem")
	if ps != null:
		ps.pozione_bevuta.connect(func(_avanzato: bool, _forzato: bool) -> void: gesto("drink"))
	var rs: Node = get_node_or_null("/root/RitualSystem")
	if rs != null:
		rs.rituale_avviato.connect(func(_s: int) -> void: gesto("ritual"))
		rs.rituale_completato.connect(func(_s: int) -> void: fine_gesto("ritual"))
		rs.rituale_interrotto.connect(func(_m: String) -> void: fine_gesto("ritual"))

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


## US-8B71: le icone degli status sopra il nome.
func _monta_icone_stato() -> Node2D:
	var icone: Node2D = preload("res://scripts/status_icons.gd").new()
	icone.name = "IconeStato"
	add_child(icone)
	icone.call("collega", _stats)
	return icone


## Nome e icone degli status sopra la testa: le icone stanno sopra il nome se c'e', e in volo salgono con il disegno.
func _posiziona_sopra() -> void:
	var su: float = ALTEZZA_VOLO if _mezzo == "volo" else 0.0
	if _anim != null:
		su += float(_anim.get("alto_in_piu"))       # US-8B50: una forma piu' grande
	if _nome_lbl != null:
		_nome_lbl.position.y = -34.0 - su
	if _icone_stato != null:
		var con_nome: bool = _nome_lbl != null and not _nome_lbl.text.is_empty()
		_icone_stato.position.y = (-38.0 if con_nome else -26.0) - su


## Nome sopra la testa, stesso stile della Label degli NPC in region_scene.gd.
func _monta_nome() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	_nome_lbl = Label.new()
	_nome_lbl.name = "Nome"
	_nome_lbl.add_theme_font_size_override("font_size", 10)
	_nome_lbl.add_theme_constant_override("outline_size", 4)       # si legge anche sul marmo e sulla neve
	_nome_lbl.add_theme_color_override("font_outline_color", Color("#181425"))
	_nome_lbl.position = Vector2(-32, -34)
	_nome_lbl.custom_minimum_size = Vector2(64, 0)
	_nome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_nome_lbl)
	_nome_lbl.text = str(gs.get("nome_personaggio"))
	if gs.has_signal("partita_iniziata"):
		gs.partita_iniziata.connect(func(n: String) -> void:
			_nome_lbl.text = n
			_posiziona_sopra())


func _physics_process(delta: float) -> void:
	if _morto:
		return
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	if _dashing:
		_dash_left -= delta
		velocity = _dash_vel
		var prima_dash: Vector2 = global_position
		move_and_slide()
		_resta_dove_si_puo(prima_dash)
		if _dash_left <= 0.0:
			_fine_dash()
		return

	if Input.is_action_just_pressed("interagisci"):
		gesto("interact")
	if Input.is_action_just_pressed("parata") and not _attaccando:
		_inizia_parata()
	elif Input.is_action_just_released("parata"):
		_fine_parata()

	if Input.is_action_just_pressed("schivata") and not _attaccando and not _parando and _dash_cd <= 0.0:
		start_dash({})
		return

	if Input.is_action_just_pressed("attacco") and not _attaccando and not _parando:
		_inizia_attacco()

	_gestisci_input_abilita()

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var vel_max: float = _stats.get_stat("velocita")

	if input != Vector2.ZERO:
		# get_vector normalizza gia' la diagonale: nessuna spinta extra in obliquo.
		velocity = velocity.move_toward(input * vel_max, ACCELERAZIONE * delta)
		if not _attaccando:
			_aggiorna_sguardo(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ATTRITO * delta)

	var prima: Vector2 = global_position
	move_and_slide()
	_resta_dove_si_puo(prima)
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


## US-506: la primitiva teleport consegna qui l'ordine. Salto istantaneo di
## 'distanza' px nella direzione dell'input (o, se fermo, di quella guardata).
## Riposizionamento; la porta permanente verso il mondo spirituale e' fase 6.
func teleport_verso(spec: Dictionary) -> void:
	var distanza: float = float(spec.get("distanza", 160.0))
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = get_facing()
	global_position += dir.normalized() * distanza


## Mezzi (US-8B91 barca, US-8B93 volo; decisioni dell'utente 2026-10-25 e 2026-10-26). A piedi
## fermano l'acqua e il vuoto (strato 1 del mondo) e i dislivelli (strato 5, mondo.gd
## STRATO_DISLIVELLI). In barca l'acqua non ferma e la terra si'; in volo non ferma niente (alla
## Frontiera si arriva anche volando). Il mondo passa un vincolo, Callable(Vector2) -> bool, vero
## dove il mezzo puo' stare (solo acqua, dentro la mappa).
const ALTEZZA_VOLO := 14.0
const DENTRO_BARCA := 4.0                     # US-8B81: in ginocchio dentro lo scafo, non sul bordo di poppa
var _mezzo: String = ""                     # "", "barca", "volo"
var _vincolo: Callable = Callable()
var _ombra_volo: Sprite2D = null


func imposta_volo(attivo: bool, vincolo: Callable = Callable()) -> void:
	_imposta_mezzo("volo" if attivo else "", vincolo)


func in_volo() -> bool:
	return _mezzo == "volo"


func imposta_barca(attivo: bool, vincolo: Callable = Callable()) -> void:
	_imposta_mezzo("barca" if attivo else "", vincolo)


func in_barca() -> bool:
	return _mezzo == "barca"


func _imposta_mezzo(mezzo: String, vincolo: Callable) -> void:
	_mezzo = mezzo
	_vincolo = vincolo if not mezzo.is_empty() else Callable()
	set_collision_mask_value(1, mezzo.is_empty())
	set_collision_mask_value(5, mezzo != "volo")
	var vola: bool = mezzo == "volo"
	z_index = 5 if vola else 0                  # in volo sopra case e alberi
	if _anim != null:
		_anim.position.y = -ALTEZZA_VOLO if vola else (DENTRO_BARCA if mezzo == "barca" else 0.0)
	_posiziona_sopra()                          # nome e icone salgono con il disegno
	if _ombra_volo == null and vola:            # l'ombra a terra, composta nel gioco (CLAUDE.md)
		var img := Image.create(18, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 18:
				if pow((x - 8.5) / 9.0, 2) + pow((y - 3.0) / 3.5, 2) <= 1.0:
					img.set_pixel(x, y, Color(0.094, 0.078, 0.145, 0.45))
		_ombra_volo = Sprite2D.new()
		_ombra_volo.name = "OmbraVolo"
		_ombra_volo.texture = ImageTexture.create_from_image(img)
		_ombra_volo.z_index = -1
		add_child(_ombra_volo)
	if _ombra_volo != null:
		_ombra_volo.visible = vola


## In barca un passo che esce dall'acqua scivola lungo la costa (prima solo x, poi solo y).
func _resta_dove_si_puo(prima: Vector2) -> void:
	if not _vincolo.is_valid() or _vincolo.call(global_position):
		return
	var dopo: Vector2 = global_position
	for prova in [Vector2(dopo.x, prima.y), Vector2(prima.x, dopo.y), prima]:
		global_position = prova
		if _vincolo.call(prova):
			return


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
	_vfx_evento("dash", self)


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


## Hotbar (US-802): abilita_1..4 lanciano la N-esima abilita' posseduta
## (AbilityEngine.owned_abilities, stesso ordine che mostra l'HUD). Stessi
## guard di _inizia_attacco (non durante un attacco/parata/cast gia' in
## corso: schivata e dash tornano prima di arrivare qui).
func _gestisci_input_abilita() -> void:
	if _attaccando or _parando or _castando:
		return
	for n in 4:
		if Input.is_action_just_pressed("abilita_%d" % (n + 1)):
			lancia_abilita_slot(n)
			return  # un solo tasto abilita' per frame, come attacco/schivata/parata


## Lancia la N-esima abilita' posseduta (indice 0-based, stesso ordine di
## AbilityEngine.owned_abilities e della hotbar dell'HUD). Pubblico, come
## start_dash: lo usa l'input qui sopra, e i test lo chiamano direttamente
## bypassando Input (stesso pattern di _su_colpo_inflitto/_su_danno_subito).
## Nessuna logica di bersaglio: la fa gia' AbilityEngine.execute.
func lancia_abilita_slot(n: int) -> Dictionary:
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if ae == null:
		return {"ok": false, "reason": "nessun_ability_engine"}
	var owned: Array = ae.call("owned_abilities", self)
	if n < 0 or n >= owned.size():
		return {"ok": false, "reason": "slot_vuoto"}
	var risultato: Dictionary = ae.call("execute", str(owned[n]), self)
	if bool(risultato.get("ok", false)):
		_castando = true
		_anim.call("riproduci", "cast", _dir_sguardo)
	return risultato


func _su_evento_anim(nome: String) -> void:
	match nome:
		"hitbox_on":
			var arco: Dictionary = _combat.get("attacco_leggero", {})
			_hitbox.call("attiva",
				float(arco.get("danno", 12.0)), float(arco.get("stagger", 6.0)), self,
				str(arco.get("tag_danno", "")))
			var vfx: Node = get_node_or_null("/root/Vfx")       # US-8B40: il fendente dell'attacco base
			if vfx != null:
				vfx.call("gioca_per", "melee_arc", self)
		"hitbox_off":
			_hitbox.call("disattiva")


func _su_anim_finita(stato: String) -> void:
	if _morto:
		# checkpoint di fase 5/7/8: "death" come stringa bare e' vietata fuori
		# dalla riga "riproduci" (nome di Sequenza di Death). _morto la evita:
		# nessun altro stato puo' finire mentre e' vero (_physics_process
		# ferma input/attacco/cast/schivata finche' non torna false).
		_respawn()
		return
	if stato == STATO_ATTACCO:
		_attaccando = false
		_hitbox.call("disattiva")
	elif stato == "cast":
		_castando = false
	elif stato == _gesto:
		_gesto = ""


## StatsComponent.died: hp a 0. Ferma il giocatore e riproduce "death"
## (gia' nei dati di animations.json, mai suonata finora); il respawn
## arriva a fine animazione via _su_anim_finita.
func _su_morte() -> void:
	_morto = true
	_attaccando = false
	_dashing = false
	_parando = false
	_castando = false
	velocity = Vector2.ZERO
	_hitbox.call("disattiva")
	_hurtbox.call("set_invulnerabile", true)
	_anim.call("riproduci", "death", _dir_sguardo)


## Torna al punto di spawn della regione corrente (stesso contratto
## pubblico con cui main.gd riconosce il nodo regione: has_method
## "viaggia_a") e resuscita a hp pieni.
func _respawn() -> void:
	imposta_barca(false)                       # si rinasce a terra (la barca torna al suo ormeggio: mondo.gd)
	var regione: Node = _regione_corrente()
	if regione != null and regione.has_method("colloca"):
		regione.call("colloca", self, regione.call("punto_spawn"))   # mondo generato: anche la telecamera
	elif regione != null and regione.has_method("punto_spawn"):
		global_position = regione.call("punto_spawn")
	_stats.call("revivi")
	_hurtbox.call("set_invulnerabile", false)
	_morto = false
	_anim.call("riproduci", "idle", _dir_sguardo)


func _regione_corrente() -> Node:
	var padre: Node = get_parent()
	if padre == null:
		return null
	if padre.has_method("viaggia_a"):          # mondo generato: il giocatore sta dentro il nodo mondo
		return padre
	for c in padre.get_children():
		if c.has_method("viaggia_a"):
			return c
	return null


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
			vfx.call("evento_combat", "parry_perfect", self)
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
func _su_colpo_inflitto(bersaglio: Node, danno: float, tag_danno: String = "") -> void:
	if _audio != null:
		_audio.call("feedback", "hit_light")
	_vfx_evento("hit_light", bersaglio)
	if danno > 0.0:
		_traccia("damage_dealt", {"quantita": danno, "tag_danno": tag_danno})


## US-8B40b: il foglio del momento (vfx.json feedback_colpo) su chi lo vive.
func _vfx_evento(nome: String, dove: Node) -> void:
	var vfx: Node = get_node_or_null("/root/Vfx")
	if vfx != null and dove is Node2D:
		vfx.call("evento_combat", nome, dove)


## US-8B80: un gesto (animations.json personaggio: interact, pickup, drink, ritual), solo se Enel non sta gia'
## facendo altro. Pubblico: lo chiamano i pickup, i sistemi via segnale e i test.
func gesto(nome: String) -> void:
	if _morto or _attaccando or _dashing or _parando or _castando:
		return
	_gesto = nome
	_anim.call("riproduci", nome, _dir_sguardo)


## Chiude un gesto in ciclo (il rituale) quando finisce la cosa che lo teneva acceso.
func fine_gesto(nome: String) -> void:
	if _gesto != nome:
		return
	_gesto = ""
	_aggiorna_animazione()


func gesto_corrente() -> String:
	return _gesto


## US-8B50: in una forma (data/forms.json "aspetto") Enel ha i suoi fogli; stessi tempi, stesso stato di prima.
func _su_forma(aspetto: String) -> void:
	var stato: String = str(_anim.call("stato_corrente"))
	_anim.call("configura", CATEGORIA_ANIM, aspetto)
	if not stato.is_empty():
		_anim.call("riproduci", stato, _dir_sguardo)
	_posiziona_sopra()                                # il nome sopra la testa della forma


func _su_danno_subito(danno: float, _stagger: float, _da: Node, tag_danno: String = "") -> void:
	if danno > 0.0 and _audio != null:
		_audio.call("feedback", "damage_taken")
	if danno > 0.0:
		if _anim != null:
			_anim.call("lampo")
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
	if _attaccando or _dashing or _parando or _castando:
		return
	var in_moto: bool = velocity.length() > SOGLIA_MOTO
	if not _gesto.is_empty() and not in_moto:
		return                                          # il gesto finisce da se' (o col rituale)
	_gesto = ""
	var stato: String = "walk" if in_moto else "idle"
	if not _mezzo.is_empty():                       # US-8B81: in volo sospeso, in barca a remare
		stato = "fly" if _mezzo == "volo" else "sail"
	_anim.call("riproduci", stato, _dir_sguardo)
