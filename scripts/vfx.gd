extends Node
## Renderer dei VFX per PRIMITIVA (US-227). Un'abilita' eseguita ->
## per ogni sua primitiva riproduce lo sprite placeholder parametrato coi
## colori della palette del Pathway del caster (data/vfx.json), e sui colpi
## che contano scatta l'impact frame. I momenti forti (Sequenza <= 4, parata
## perfetta, rottura di postura) mangiano lo sfondo di nero.
##
## AGGANCIO AL TIMING: oggi l'esecuzione di un'abilita' e' istantanea, quindi
## il VFX parte su AbilityEngine.ability_executed. Quando ci sara' una vera
## animazione di lancio, il trigger si sposta sull'evento "ability_release"
## dei frame (animations.json) senza toccare questo file: basta che il
## chiamante invochi gioca_primitiva() a quel frame.
##
## NIENTE class_name: coerente col resto del progetto.

const VITA_FRAME := 1.0 / 12.0   # durata di un frame del placeholder
## US-8B40: i fogli veri (tools/art/build_vfx.py) sono a 4 toni di grigio, colorati dalla rampa del Pathway.
const RAMPA := preload("res://shaders/rampa_pathway.gdshader")
const FOGLI := "res://assets/vfx/%s.png"

var _fogli: Dictionary = {}


func _ready() -> void:
	var eng: Node = get_node_or_null("/root/AbilityEngine")
	if eng != null and eng.has_signal("ability_executed"):
		eng.ability_executed.connect(_su_abilita)


func _su_abilita(ability_id: String, caster: Node, _result: Dictionary) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or caster == null:
		return
	var ability: Dictionary = gd.call("get_ability", ability_id)
	if ability.is_empty():
		return
	var pal: Dictionary = gd.call("get_vfx_palette", _pathway_di(caster))

	for entry in ability.get("primitive", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tipo: String = str((entry as Dictionary).get("tipo", ""))
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		if pv.is_empty():
			continue   # primitiva non ancora coperta dai VFX
		gioca_primitiva(tipo, caster, pv, pal)
		if bool(pv.get("impact_frame", false)):
			_overlay_call("impatto")

	# nero di scena per le abilita' di Sequenza bassa
	var trigger: Array = gd.call("get_vfx", "nero_di_scena").get("trigger", [])
	if trigger.has("abilita_sequenza_max_4") and _sequenza_di(ability) <= 4:
		_nero(gd)


## Il VFX di una primitiva per un caster con la sua palette, anche fuori dalle abilita' (l'attacco base del
## giocatore usa il fendente di melee_arc).
func gioca_per(tipo: String, caster: Node) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or caster == null:
		return
	var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
	if not pv.is_empty():
		gioca_primitiva(tipo, caster, pv, gd.call("get_vfx_palette", _pathway_di(caster)))


## Riproduce il VFX di UNA primitiva. Pubblico: quando ci sara' l'animazione
## di lancio, il player lo chiamera' sull'evento ability_release.
func gioca_primitiva(_tipo: String, caster: Node, pv: Dictionary, pal: Dictionary) -> void:
	if not (caster is Node2D):
		return
	var madre: Node = (caster as Node2D).get_parent()
	if madre == null:
		return
	var facing: Vector2 = Vector2.DOWN
	if caster.has_method("get_facing"):
		facing = caster.call("get_facing")
	if bool(pv.get("sul_proiettile", false)):
		return                                  # lo porta il proiettile stesso (veste_proiettile)
	var tex: Texture2D = _foglio(str(pv.get("sprite", "")))
	if tex != null:
		var e := _effetto(tex, int(pv.get("frames", 1)), pal, bool(pv.get("impact_frame", false)))
		e.global_position = (caster as Node2D).global_position + Vector2(0, -6)
		e.rotation = facing.angle()
		madre.add_child(e)
		_anima(e, false)
		return
	var s := Sprite2D.new()
	s.texture = _tex_placeholder()
	s.modulate = _colore(pal, "primario", Color(0.9, 0.9, 0.95))
	s.global_position = (caster as Node2D).global_position + Vector2(0, -6) + facing * 14.0
	s.rotation = facing.angle()
	s.scale = Vector2.ONE * 0.7
	madre.add_child(s)
	# un lampo che si allarga davanti al caster: abbastanza grande e lungo da
	# vedersi (il 6x6 di prima spariva prima di accorgersene). Grafica ancora
	# provvisoria, ma leggibile.
	var durata: float = maxf(0.3, maxi(1, int(pv.get("frames", 3))) * VITA_FRAME)
	var t := s.create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * 2.4, durata)
	t.tween_property(s, "modulate:a", 0.0, durata)
	t.chain().tween_callback(s.queue_free)


## US-8B40: il proiettile in volo porta il suo foglio (ciclo), girato nella direzione di tiro.
func veste_proiettile(proiettile: Node2D, caster: Node, direzione: Vector2) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var pv: Dictionary = gd.call("get_primitive_vfx", "projectile") if gd != null else {}
	var tex: Texture2D = _foglio(str(pv.get("sprite", "")))
	if tex == null:
		return
	var e := _effetto(tex, int(pv.get("frames", 1)), _palette_di(gd, caster), false)
	e.rotation = direzione.angle()
	proiettile.add_child(e)
	_anima(e, true)


## Lo scoppio quando il proiettile colpisce o finisce la gittata (primitive_vfx.projectile.scoppio).
func scoppio_proiettile(posizione: Vector2, caster: Node, madre: Node) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var pv: Dictionary = gd.call("get_primitive_vfx", "projectile") if gd != null else {}
	var sc: Dictionary = pv.get("scoppio", {}) if pv.get("scoppio") is Dictionary else {}
	var tex: Texture2D = _foglio(str(sc.get("sprite", "")))
	if tex == null or madre == null:
		return
	var e := _effetto(tex, int(sc.get("frames", 1)), _palette_di(gd, caster), bool(pv.get("impact_frame", false)))
	e.global_position = posizione
	madre.add_child(e)
	_anima(e, false)


func evento_combat(nome: String) -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var trigger: Array = gd.call("get_vfx", "nero_di_scena").get("trigger", [])
	if trigger.has(nome):
		_nero(gd)


# --- Interno ----------------------------------------------------------

func _nero(gd: Node) -> void:
	_overlay_call("nero", float(gd.call("get_vfx", "nero_di_scena").get("durata_ms", 250)))


func _palette_di(gd: Node, caster: Node) -> Dictionary:
	return gd.call("get_vfx_palette", _pathway_di(caster)) if gd != null else {}


## Foglio di un VFX (assets/vfx/<sprite>.png), letto dal disco una volta; null se non c'e' ancora.
func _foglio(sprite: String) -> Texture2D:
	if sprite.is_empty():
		return null
	if not _fogli.has(sprite):
		var path: String = FOGLI % sprite
		_fogli[sprite] = preload("res://scripts/world/mondo.gd")._texture(path) if FileAccess.file_exists(path) else null
	return _fogli[sprite]


## Uno sprite a frame in colonne, a mezza grandezza come gli altri sprite, colorato dalla rampa della palette;
## con `lampo` il primo frame e' bianco (non con riduci_flash).
func _effetto(tex: Texture2D, frames: int, pal: Dictionary, lampo: bool) -> Sprite2D:
	var e := Sprite2D.new()
	e.texture = tex
	e.hframes = maxi(1, frames)
	e.scale = Vector2(0.5, 0.5)
	e.z_index = 1
	var m := ShaderMaterial.new()
	m.shader = RAMPA
	var ink := _colore(pal, "inchiostro", Color("#181425"))
	var pri := _colore(pal, "primario", Color("#8b9bb4"))
	m.set_shader_parameter("inchiostro", ink)
	m.set_shader_parameter("scuro", pri.lerp(ink, 0.45))
	m.set_shader_parameter("primario", pri)
	m.set_shader_parameter("accento", _colore(pal, "accento", Color("#ffffff")))
	m.set_shader_parameter("lampo", 1.0 if lampo and not _flash_ridotto() else 0.0)
	e.material = m
	return e


## Un frame ogni VITA_FRAME: una volta sola (poi sparisce, il lampo solo nel primo frame) o in ciclo.
func _anima(e: Sprite2D, ciclo: bool) -> void:
	var t := e.create_tween()
	if ciclo:
		t.set_loops()
	for k in range(1, e.hframes):
		t.tween_interval(VITA_FRAME)
		t.tween_callback(e.set.bind("frame", k))
		if k == 1 and not ciclo:
			t.tween_callback((e.material as ShaderMaterial).set_shader_parameter.bind("lampo", 0.0))
	t.tween_interval(VITA_FRAME)
	t.tween_callback(e.set.bind("frame", 0) if ciclo else e.queue_free)


func _flash_ridotto() -> bool:
	var am: Node = get_node_or_null("/root/AudioManager")
	return bool(am.call("accessibilita", "riduci_flash")) if am != null else false


func _pathway_di(caster: Node) -> String:
	if not is_instance_valid(caster):
		return ""
	if caster.is_in_group("player"):
		var prog: Node = get_node_or_null("/root/Progression")
		return str(prog.call("pathway")) if prog != null else ""
	return ""


func _sequenza_di(ability: Dictionary) -> int:
	var sid: String = str(ability.get("sequence_id", ""))
	var parti: PackedStringArray = sid.rsplit("_", true, 1)
	return int(parti[parti.size() - 1]) if parti.size() > 1 and parti[parti.size() - 1].is_valid_int() else 9


func _colore(pal: Dictionary, chiave: String, fallback: Color) -> Color:
	var h: String = str(pal.get(chiave, ""))
	return Color.from_string(h, fallback) if h.begins_with("#") else fallback


func _overlay_call(metodo: String, arg: Variant = null) -> void:
	var ov: Node = _overlay()
	if ov == null:
		return
	if arg == null:
		ov.call(metodo)
	else:
		ov.call(metodo, arg)


func _overlay() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.find_child("VfxOverlay", true, false)


func _tex_placeholder() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
