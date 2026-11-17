extends CanvasLayer
## HUD di gioco (US-8B75d, ridisegnato su richiesta dell'utente): pulito e piccolo, per non stancare l'occhio.
## In alto a sinistra le barre (vita, spiritualita', recitazione) con il loro emblema, gli status a sole icone e la
## fiala quando l'avanzamento e' pronto; in basso al centro la hotbar a soli simboli (il nome sta nel libro).
## I numeri compaiono solo quando un valore cambia. Misure e colori in data/ui/hud.json; barre e slot li disegnano
## scripts/hud_barra.gd e hud_slot.gd; le icone sono di tools/art/build_hud.py. Nessun testo hardcoded.
##
## NIENTE class_name: coerente col progetto.

const Barra := preload("res://scripts/hud_barra.gd")
const Slot := preload("res://scripts/hud_slot.gd")
const RIGHE := {"vita": "HP", "spirito": "SP", "recitazione": "Acting"}   # id dei dati -> nome del nodo

var _cfg: Dictionary = {}
var _barre: Dictionary = {}          # id -> barra
var _numeri: Dictionary = {}         # id -> Label (solo vita e spirito)
var _numeri_t: Dictionary = {}       # id -> secondi che restano a vista
var _slot: Array = []
var _rampa := ShaderMaterial.new()
var _rampa_di: String = "?"
var _avanzamento: TextureRect = null
var _stats: Node = null
var _stati: HBoxContainer = null
var _cd_accum: float = 0.0
var _tempo: float = 0.0
var _durate: Dictionary = {}       # status -> durata vista quando e' comparso (per la linea del tempo)


func _ready() -> void:
	add_to_group("hud")                                # US-8B24b: il cannocchiale lo nasconde mentre si guarda
	var gd: Node = get_node_or_null("/root/GameData")
	_cfg = gd.call("get_ui_hud") if gd != null else {}
	var angolo: Array = _cfg.get("angolo", [10, 9])
	$Root/Vitali.position = Vector2(float(angolo[0]), float(angolo[1]))
	for id in ["vita", "spirito", "recitazione"]:
		_monta_riga(id)
	_stati = HBoxContainer.new()                       # status del giocatore: solo icone, con il tempo sotto
	_stati.name = "Stati"
	_stati.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stati.add_theme_constant_override("separation", 3)
	$Root/Vitali.add_child(_stati)
	_monta_hotbar()

	var acting: Node = get_node_or_null("/root/Acting")
	if acting != null:
		acting.acting_progress_changed.connect(_su_acting)
		_su_acting(acting.call("acting_progress"))
	var pozioni: Node = get_node_or_null("/root/PotionSystem")
	if pozioni != null:
		pozioni.pozione_creata.connect(func(_s: int, _p: bool) -> void: _aggiorna_avanzamento())
		pozioni.pozione_bevuta.connect(func(_a: bool, _f: bool) -> void: _aggiorna_avanzamento())
	_aggiorna_avanzamento()
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if ae != null:
		ae.ability_executed.connect(_su_abilita_eseguita)
		ae.hotbar_cambiata.connect(_aggiorna_hotbar)          # US-8B75c
	var prog: Node = get_node_or_null("/root/Progression")
	if prog != null and prog.has_signal("sequence_changed"):
		prog.sequence_changed.connect(func(_n: int, _v: int) -> void: _aggiorna_hotbar())
	_aggiorna_hotbar()

	var p: Node = get_tree().get_first_node_in_group("player")
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	if stats == null:
		push_warning("[HUD] nessun giocatore con StatsComponent in scena")
		return
	_stats = stats
	stats.status_cambiati.connect(_aggiorna_stati)
	stats.hp_changed.connect(_su_hp)
	stats.spiritualita_changed.connect(_su_sp)
	_su_hp(float(stats.get("hp")), stats.get_stat("hp_max"), true)
	_su_sp(float(stats.get("spiritualita")), stats.get_stat("spiritualita_max"), true)
	_aggiorna_stati()


## Una riga: l'emblema (12x12 pixel a 1:1), la barra e, per vita e spirito, il numero che appare quando cambia.
func _monta_riga(id: String) -> void:
	var dati: Dictionary = (_cfg.get("barre", {}) as Dictionary).get(id, {})
	var riga := HBoxContainer.new()
	riga.name = RIGHE[id]
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riga.add_theme_constant_override("separation", 3)
	$Root/Vitali.add_child(riga)
	var em := _icona(str(dati.get("emblema", "")), 6.0)
	em.name = "Emblema"
	riga.add_child(em)
	var b: Control = Barra.new()
	b.name = "Barra"
	b.call("configura", dati, _cfg, id == "vita")
	riga.add_child(b)
	_barre[id] = b
	if id == "recitazione":
		_avanzamento = _icona(str((_cfg.get("avanzamento", {}) as Dictionary).get("icona", "fiala")), 6.0)
		_avanzamento.name = "Avanzamento"
		riga.add_child(_avanzamento)
		return
	var n := Label.new()
	n.name = "Numero"
	n.add_theme_font_size_override("font_size", int((_cfg.get("numeri", {}) as Dictionary).get("corpo", 8)))
	n.add_theme_constant_override("outline_size", 3)
	n.add_theme_color_override("font_outline_color", Color(str(_cfg.get("contorno", "#181425"))))
	n.modulate.a = 0.0
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	riga.add_child(n)
	_numeri[id] = n


func _icona(nome: String, lato: float) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/hud/%s.png" % nome) as Texture2D if not nome.is_empty() else null
	ic.custom_minimum_size = Vector2(lato, lato)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _monta_hotbar() -> void:
	_rampa.shader = preload("res://shaders/rampa_pathway.gdshader")
	var h: Dictionary = _cfg.get("hotbar", {})
	var bar: HBoxContainer = $Root/Hotbar
	bar.add_theme_constant_override("separation", int(h.get("spazio", 4)))
	var lato: float = float(h.get("lato", 22))
	var n: int = 4
	var larg: float = n * lato + (n - 1) * float(h.get("spazio", 4))
	bar.offset_left = -larg / 2.0
	bar.offset_right = larg / 2.0
	bar.offset_bottom = -float(h.get("dal_basso", 8))
	bar.offset_top = bar.offset_bottom - lato
	for i in n:
		var s: Control = Slot.new()
		s.name = "Slot%d" % i
		s.call("configura", h, _cfg, i + 1, _rampa)
		bar.add_child(s)
		_slot.append(s)


func _su_hp(hp: float, hp_max: float, subito: bool = false) -> void:
	_valore("vita", hp, hp_max, subito)


func _su_sp(sp: float, sp_max: float, subito: bool = false) -> void:
	_valore("spirito", sp, sp_max, subito)
	_aggiorna_hotbar()


func _valore(id: String, v: float, v_max: float, subito: bool) -> void:
	(_barre[id] as Control).call("imposta", v / maxf(v_max, 1.0), subito)
	var n: Label = _numeri.get(id)
	n.text = tr("HUD_HP_VALORE").format([roundi(v), roundi(v_max)])
	if not subito:
		_numeri_t[id] = float((_cfg.get("numeri", {}) as Dictionary).get("mostra_s", 1.6))


func _su_acting(valore: float) -> void:
	(_barre["recitazione"] as Control).call("imposta", valore)
	_aggiorna_avanzamento()


## US-212: la fiala accanto alla recitazione quando c'e' una pozione pronta: piena e che batte se l'avanzamento e'
## pronto, spenta se si potrebbe solo forzare. Niente scritte.
func _aggiorna_avanzamento() -> void:
	var pozioni: Node = get_node_or_null("/root/PotionSystem")
	if _avanzamento == null:
		return
	_avanzamento.visible = pozioni != null and not (pozioni.call("pozione_pronta") as Dictionary).is_empty()
	_avanzamento.set_meta("pronto", _avanzamento.visible and bool(pozioni.call("avanzamento_disponibile")))
	_avanzamento.modulate = Color.WHITE if bool(_avanzamento.get_meta("pronto")) else Color(1, 1, 1, 0.45)


func _process(delta: float) -> void:
	_tempo += delta
	for id in _numeri_t.keys():                     # i numeri: a vista un attimo, poi sfumano
		_numeri_t[id] = float(_numeri_t[id]) - delta
		var dis: float = float((_cfg.get("numeri", {}) as Dictionary).get("dissolvenza_s", 0.5))
		(_numeri[id] as Label).modulate.a = clampf((float(_numeri_t[id]) + dis) / maxf(dis, 0.01), 0.0, 1.0)
		if float(_numeri_t[id]) <= -dis:
			_numeri_t.erase(id)
	if _avanzamento != null and _avanzamento.visible and bool(_avanzamento.get_meta("pronto", false)):
		var b: float = float((_cfg.get("avanzamento", {}) as Dictionary).get("battito_s", 1.4))
		_avanzamento.modulate.a = 0.7 + 0.3 * sin(_tempo * TAU / maxf(b, 0.1))
	_cd_accum += delta
	if _cd_accum >= 0.05:
		_cd_accum = 0.0
		_aggiorna_hotbar()
		_aggiorna_tempi_stati()


## US-802: lo slot che ha lanciato l'abilita' lampeggia.
func _su_abilita_eseguita(ability_id: String, caster: Node, result: Dictionary) -> void:
	_aggiorna_hotbar()
	if caster == null or not caster.is_in_group("player") or not bool(result.get("ok", false)):
		return
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	var idx: int = (ae.call("hotbar", caster) as Array).find(ability_id) if ae != null else -1
	if idx >= 0 and idx < _slot.size():
		(_slot[idx] as Control).call("lampeggia")


## US-8B75b: unita' di schermo occupate dall'HUD dall'alto (la camera degli interni le lascia libere).
func altezza() -> float:
	var v: Control = $Root/Vitali
	return v.position.y + v.get_combined_minimum_size().y


## US-8B75d: e dal basso (la hotbar).
func altezza_sotto() -> float:
	var h: Dictionary = _cfg.get("hotbar", {})
	return float(h.get("lato", 22)) + float(h.get("dal_basso", 8))


## Gli status: un'icona per status (10 unita'), con sotto una linea che si accorcia col tempo che resta e che
## lampeggia negli ultimi secondi. Il nome sta nel libro.
func _aggiorna_stati() -> void:
	for c in _stati.get_children():
		_stati.remove_child(c)
		c.queue_free()
	var gd: Node = get_node_or_null("/root/GameData")
	var ids: Array = _stats.call("status_attivi") if _stats != null else []
	ids.sort()
	for k in _durate.keys():
		if not ids.has(k):
			_durate.erase(k)
	var lato: float = float((_cfg.get("stati", {}) as Dictionary).get("lato", 10))
	for id in ids:
		var box := VBoxContainer.new()                # l'icona e sotto la linea del tempo che resta
		box.name = str(id)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 1)
		var ic := TextureRect.new()
		ic.name = "Icona"
		ic.texture = gd.call("icona_stato", id) if gd != null else null
		ic.custom_minimum_size = Vector2(lato, lato)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)
		var linea := ColorRect.new()
		linea.name = "Tempo"
		linea.color = Color(str((_cfg.get("stati", {}) as Dictionary).get("tempo", "#c0cbdc")))
		linea.custom_minimum_size = Vector2(lato, 0.5)
		linea.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(linea)
		_stati.add_child(box)
	_stati.visible = not ids.is_empty()


func _aggiorna_tempi_stati() -> void:
	if _stati == null or not _stati.visible:
		return
	var st: Dictionary = _cfg.get("stati", {})
	var ultimi: float = float(st.get("lampeggio_ultimi_s", 2.0))
	for box in _stati.get_children():
		var resta: float = float(_stats.call("status_rimasto", str(box.name))) if _stats != null else -1.0
		var durata: float = maxf(float(_durate.get(str(box.name), resta)), resta)     # quanto durava quando e' comparso
		_durate[str(box.name)] = durata
		var linea: ColorRect = box.get_node("Tempo")
		linea.visible = resta >= 0.0
		linea.custom_minimum_size.x = roundf(float(st.get("lato", 10)) * clampf(resta / maxf(durata, 0.01), 0.0, 1.0) * 2.0) / 2.0
		(box as CanvasItem).modulate.a = (0.35 if fmod(_tempo, 0.4) < 0.2 else 1.0) if resta >= 0.0 and resta < ultimi else 1.0


## La palette del Pathway del giocatore nella rampa dei glifi: scuro = primario verso l'inchiostro.
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


## US-802 / US-8B75d: gli slot 1-4 dalle abilita' nei tasti (AbilityEngine.hotbar), solo il simbolo.
func _aggiorna_hotbar() -> void:
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	var gd: Node = get_node_or_null("/root/GameData")
	var p: Node = get_tree().get_first_node_in_group("player")
	var owned: Array = ae.call("hotbar", p) if ae != null and p != null else []
	_aggiorna_rampa(gd)
	var sp: float = float(_stats.get("spiritualita")) if _stats != null else INF
	for i in _slot.size():
		var s: Control = _slot[i]
		if i >= owned.size() or str(owned[i]).is_empty() or gd == null:
			s.call("imposta", "", null, 0.0, false)
			continue
		var aid: String = str(owned[i])
		var ab: Dictionary = gd.call("get_ability", aid)
		var cd: float = float(ae.call("cooldown_left", p, aid)) if ae != null else 0.0
		var cd_tot: float = maxf(float(ab.get("cooldown", 0.0)), cd)
		s.call("imposta", aid, _icona_abilita(gd, ab), cd / cd_tot if cd_tot > 0.0 else 0.0,
			float(ab.get("costo_spiritualita", 0.0)) > sp)
