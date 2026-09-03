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


## Riproduce il VFX di UNA primitiva. Pubblico: quando ci sara' l'animazione
## di lancio, il player lo chiamera' sull'evento ability_release.
func gioca_primitiva(_tipo: String, caster: Node, pv: Dictionary, pal: Dictionary) -> void:
	if not (caster is Node2D):
		return
	var madre: Node = (caster as Node2D).get_parent()
	if madre == null:
		return
	var s := Sprite2D.new()
	s.texture = _tex_placeholder()
	s.modulate = _colore(pal, "primario", Color(0.9, 0.9, 0.95))
	s.global_position = (caster as Node2D).global_position + Vector2(0, -6)
	madre.add_child(s)
	var frames: int = maxi(1, int(pv.get("frames", 3)))
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, frames * VITA_FRAME)
	t.tween_callback(s.queue_free)


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


func _pathway_di(caster: Node) -> String:
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
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
