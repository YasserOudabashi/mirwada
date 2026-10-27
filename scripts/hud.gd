extends CanvasLayer
## HUD minimo: barra salute e barra spiritualita' agganciate ai segnali di
## StatsComponent del giocatore. Nessun testo hardcoded: tutto da tr().
##
## NIENTE class_name: coerente col progetto.

@onready var _barra_hp: ProgressBar = $Root/VBox/HP/Barra
@onready var _label_hp: Label = $Root/VBox/HP/Etichetta
@onready var _barra_sp: ProgressBar = $Root/VBox/SP/Barra
@onready var _label_sp: Label = $Root/VBox/SP/Etichetta
@onready var _barra_acting: ProgressBar = $Root/VBox/Acting/Barra
@onready var _label_acting: Label = $Root/VBox/Acting/Etichetta
@onready var _hotbar: Array = [
	$Root/VBox/Hotbar/Slot0, $Root/VBox/Hotbar/Slot1,
	$Root/VBox/Hotbar/Slot2, $Root/VBox/Hotbar/Slot3,
]
@onready var _label_avanz: Label = $Root/VBox/Avanzamento

## US-802: il cooldown scorre col tempo, non con un segnale — si ridisegna
## la hotbar ogni 0.1s invece che ogni frame (60 volte al secondo sarebbe
## sprecato per un numero che cambia percettibilmente una volta ogni tanto).
var _cd_accum: float = 0.0
## US-8B72: davanti a ogni slot il glifo della prima primitiva dell'abilita', colorato dalla palette del Pathway
## (shaders/rampa_pathway.gdshader, data/vfx.json): un materiale per tutti, si aggiorna se cambia il Pathway.
var _icone: Array = []
var _rampa := ShaderMaterial.new()
var _rampa_di: String = "?"


func _ready() -> void:
	add_to_group("hud")                                # US-8B24b: il cannocchiale lo nasconde mentre si guarda
	var acting: Node = get_node_or_null("/root/Acting")
	if acting != null:
		acting.acting_progress_changed.connect(_su_acting)
		_su_acting(acting.call("acting_progress"))
	var pozioni: Node = get_node_or_null("/root/PotionSystem")
	if pozioni != null:
		pozioni.pozione_creata.connect(func(_s: int, _p: bool) -> void: _aggiorna_avanzamento())
		pozioni.pozione_bevuta.connect(func(_a: bool, _f: bool) -> void: _aggiorna_avanzamento())
	_aggiorna_avanzamento()
	_monta_icone()

	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if ae != null:
		ae.ability_executed.connect(_su_abilita_eseguita)
	var prog: Node = get_node_or_null("/root/Progression")
	if prog != null and prog.has_signal("sequence_changed"):
		prog.sequence_changed.connect(func(_n: int, _v: int) -> void: _aggiorna_hotbar())
	_aggiorna_hotbar()

	var p: Node = get_tree().get_first_node_in_group("player")
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	if stats == null:
		push_warning("[HUD] nessun giocatore con StatsComponent in scena")
		return

	stats.hp_changed.connect(_su_hp)
	stats.spiritualita_changed.connect(_su_sp)
	_su_hp(float(stats.get("hp")), stats.get_stat("hp_max"))
	_su_sp(float(stats.get("spiritualita")), stats.get_stat("spiritualita_max"))


func _su_hp(hp: float, hp_max: float) -> void:
	_barra_hp.max_value = hp_max
	_barra_hp.value = hp
	_label_hp.text = "%s  %s" % [
		tr("HUD_HP"),
		tr("HUD_HP_VALORE").format([roundi(hp), roundi(hp_max)]),
	]


func _su_sp(sp: float, sp_max: float) -> void:
	_barra_sp.max_value = sp_max
	_barra_sp.value = sp
	_label_sp.text = "%s  %s" % [
		tr("HUD_SPIRITUALITA"),
		tr("HUD_HP_VALORE").format([roundi(sp), roundi(sp_max)]),
	]


func _su_acting(valore: float) -> void:
	_barra_acting.value = valore
	_label_acting.text = tr("HUD_RECITAZIONE")
	_aggiorna_avanzamento()


## US-212: mostra se l'avanzamento e' PRONTO (recitazione completa) o solo
## FORZABILE (pozione pronta ma recitazione incompleta). Nascosto se non c'e'
## una pozione.
func _aggiorna_avanzamento() -> void:
	var pozioni: Node = get_node_or_null("/root/PotionSystem")
	if pozioni == null or pozioni.call("pozione_pronta").is_empty():
		_label_avanz.hide()
		return
	_label_avanz.show()
	if pozioni.call("avanzamento_disponibile"):
		_label_avanz.text = tr("HUD_AVANZAMENTO_PRONTO")
	else:
		_label_avanz.text = tr("HUD_AVANZAMENTO_FORZATO")


func _process(delta: float) -> void:
	_cd_accum += delta
	if _cd_accum >= 0.1:
		_cd_accum = 0.0
		_aggiorna_hotbar()


## US-802: quando parte un'abilita' del giocatore, lo slot che l'ha lanciata
## lampeggia - cosi' si vede A COLPO D'OCCHIO che si e' usata un'abilita' (e
## quale), non solo dal numero di spiritualita' che cala.
func _su_abilita_eseguita(ability_id: String, caster: Node, result: Dictionary) -> void:
	_aggiorna_hotbar()
	if caster == null or not caster.is_in_group("player") or not bool(result.get("ok", false)):
		return
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	var owned: Array = ae.call("owned_abilities", caster) if ae != null else []
	var idx: int = owned.find(ability_id)
	if idx < 0 or idx >= _hotbar.size():
		return
	var lbl: Label = _hotbar[idx]
	lbl.modulate = Color(1.7, 1.7, 0.5)
	create_tween().tween_property(lbl, "modulate", Color.WHITE, 0.45)


func _monta_icone() -> void:
	_rampa.shader = preload("res://shaders/rampa_pathway.gdshader")
	for lbl in _hotbar:
		var ic := TextureRect.new()
		ic.name = "Icona" + str((lbl as Node).name).trim_prefix("Slot")
		ic.custom_minimum_size = Vector2(16, 16)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.material = _rampa
		(lbl as Node).get_parent().add_child(ic)
		(lbl as Node).get_parent().move_child(ic, (lbl as Node).get_index())
		_icone.append(ic)


## La palette del Pathway del giocatore nella rampa: scuro = primario verso l'inchiostro.
func _aggiorna_rampa(gd: Node) -> void:
	var prog: Node = get_node_or_null("/root/Progression")
	var pw: String = str(prog.call("pathway")) if prog != null else ""
	if pw == _rampa_di or gd == null:
		return
	_rampa_di = pw
	var pal: Dictionary = gd.call("get_vfx_palette", pw)
	var ink := Color.from_string(str(pal.get("inchiostro", "")), Color("#181425"))
	var pri := Color.from_string(str(pal.get("primario", "")), Color("#8b9bb4"))
	_rampa.set_shader_parameter("inchiostro", ink)
	_rampa.set_shader_parameter("scuro", pri.lerp(ink, 0.45))
	_rampa.set_shader_parameter("primario", pri)
	_rampa.set_shader_parameter("accento", Color.from_string(str(pal.get("accento", "")), Color("#ffffff")))


## Il glifo di un'abilita': quello della sua prima primitiva che ne ha uno.
func _icona_abilita(gd: Node, ab: Dictionary) -> Texture2D:
	for entry in ab.get("primitive", []):
		if typeof(entry) == TYPE_DICTIONARY:
			var tex: Texture2D = gd.call("icona_primitiva", str((entry as Dictionary).get("tipo", "")))
			if tex != null:
				return tex
	return null


## US-802: una riga per slot 1-4, dalle abilita' possedute
## (AbilityEngine.owned_abilities del giocatore, stesso ordine dei tasti
## abilita_1..4 in player.gd). Nessun nome hardcoded: il testo viene da
## GameData.tr_data sul name_i18n dell'abilita'.
func _aggiorna_hotbar() -> void:
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	var gd: Node = get_node_or_null("/root/GameData")
	var p: Node = get_tree().get_first_node_in_group("player")
	var owned: Array = ae.call("owned_abilities", p) if ae != null and p != null else []
	_aggiorna_rampa(gd)
	for i in _hotbar.size():
		var lbl: Label = _hotbar[i]
		var ic: TextureRect = _icone[i] if i < _icone.size() else null
		if i >= owned.size():
			lbl.text = "%d  %s" % [i + 1, tr("HUD_HOTBAR_VUOTO")]
			if ic != null:
				ic.visible = false
			continue
		var aid: String = str(owned[i])
		var ab: Dictionary = gd.call("get_ability", aid) if gd != null else {}
		if ic != null:
			ic.texture = _icona_abilita(gd, ab) if gd != null else null
			ic.visible = ic.texture != null
			ic.modulate.a = 0.45 if ae != null and float(ae.call("cooldown_left", p, aid)) > 0.0 else 1.0
		var nome: String = str(gd.call("tr_data", ab.get("name_i18n", aid))) if gd != null else aid
		var cd: float = float(ae.call("cooldown_left", p, aid)) if ae != null else 0.0
		if cd > 0.0:
			lbl.text = "%d  %s  %.1fs" % [i + 1, nome, cd]
		else:
			lbl.text = "%d  %s" % [i + 1, nome]
