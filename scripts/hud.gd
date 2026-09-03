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
@onready var _label_avanz: Label = $Root/VBox/Avanzamento


func _ready() -> void:
	var acting: Node = get_node_or_null("/root/Acting")
	if acting != null:
		acting.acting_progress_changed.connect(_su_acting)
		_su_acting(acting.call("acting_progress"))
	var pozioni: Node = get_node_or_null("/root/PotionSystem")
	if pozioni != null:
		pozioni.pozione_creata.connect(func(_s: int, _p: bool) -> void: _aggiorna_avanzamento())
		pozioni.pozione_bevuta.connect(func(_a: bool, _f: bool) -> void: _aggiorna_avanzamento())
	_aggiorna_avanzamento()

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
