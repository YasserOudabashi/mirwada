extends "res://tests/test_case.gd"
## US-8B41..43 — i VFX delle primitive (tools/art/build_vfx.py): un foglio per primitiva, attorno a chi lancia.

const GRUPPO_1 := ["buff_stat", "summon", "aura", "heal", "reveal_info", "teleport", "debuff_stat", "illusion"]
const GRUPPO_2 := ["curse", "terrain_modify", "fear", "steal", "dot", "shadow_meld", "time_rewind", "plant_growth"]
const GRUPPO_3 := ["mind_read", "shield", "light_purify", "possess", "transform", "soul_detach", "resurrect", "decay"]


func _root() -> Node:
	return Engine.get_main_loop().root


func test_il_gruppo_1_ha_i_fogli_con_i_frame_dei_dati() -> void:
	_fogli(GRUPPO_1)


func test_il_gruppo_2_ha_i_fogli_con_i_frame_dei_dati() -> void:
	_fogli(GRUPPO_2)


func test_il_gruppo_3_ha_i_fogli_con_i_frame_dei_dati() -> void:
	_fogli(GRUPPO_3)


func test_ogni_primitiva_implementata_ha_il_suo_foglio() -> void:
	var gd: Node = _root().get_node("GameData")
	for tipo in _root().get_node("AbilityEngine").call("tipi_primitiva_implementati"):
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		assert_true(FileAccess.file_exists("res://assets/vfx/%s.png" % pv.get("sprite", "")),
			"%s non usa piu' il segnaposto" % tipo)


func _fogli(tipi: Array) -> void:
	var gd: Node = _root().get_node("GameData")
	for tipo in tipi:
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		var path: String = "res://assets/vfx/%s.png" % pv["sprite"]
		assert_true(FileAccess.file_exists(path), "%s ha il foglio %s" % [tipo, path])
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_eq(img.get_width(), img.get_height() * int(pv["frames"]), "%s: %d frame quadrati in colonna" % [tipo, int(pv["frames"])])


func test_gli_effetti_attorno_a_chi_lancia_non_girano_col_lo_sguardo() -> void:
	var madre := Node2D.new()
	_root().add_child(madre)
	var p: Node = preload("res://scenes/player.tscn").instantiate()
	madre.add_child(p)
	p.set("_dir_sguardo", "right")
	_root().get_node("Progression").call("configura", "twilight_giant", 9)
	var vfx: Node = _root().get_node("Vfx")
	vfx.call("gioca_per", "aura", p)
	vfx.call("gioca_per", "melee_arc", p)
	var effetti: Array = madre.get_children().filter(func(n: Node) -> bool: return n is Sprite2D)
	assert_eq(effetti.size(), 2, "due effetti")
	assert_eq((effetti[0] as Sprite2D).rotation, 0.0, "l'anello dell'aura sta dritto")
	assert_eq((effetti[1] as Sprite2D).rotation, Vector2.RIGHT.angle(), "il fendente si gira con lo sguardo")
	assert_eq((effetti[0] as Sprite2D).hframes, 4, "il foglio dell'aura, non il segnaposto")
	madre.free()


# --- US-8B44b: gli effetti sul bersaglio ------------------------------------------------

## Ogni effetto dice dove si disegna; sul bersaglio vanno quelli delle primitive che di base colpiscono un nemico.
func test_ogni_effetto_dice_dove_si_disegna() -> void:
	var gd: Node = _root().get_node("GameData")
	for tipo in _root().get_node("AbilityEngine").call("tipi_primitiva_implementati"):
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		var di_base: String = str((gd.call("get_primitive", tipo) as Dictionary).get("bersaglio", "self"))
		assert_eq(str(pv.get("su", "")), "bersaglio" if di_base == "nemico" else "chi_lancia", "%s: dove si disegna" % tipo)
	for tipo in ["curse", "possess", "soul_detach"]:
		assert_eq(str((gd.call("get_primitive_vfx", tipo) as Dictionary)["su"]), "bersaglio", "%s sul bersaglio" % tipo)


## Gli effetti dei VFX (lo shader della rampa) figli di un nodo.
func _effetti_in(n: Node) -> Array:
	return n.get_children().filter(func(c: Node) -> bool:
		return c is Sprite2D and (c as Sprite2D).material is ShaderMaterial and not c.is_queued_for_deletion())


func _scena(pathway: String, sequenza: int) -> Array:
	_root().get_node("AbilityEngine").call("clear_cooldowns")
	_root().get_node("Progression").call("configura", pathway, sequenza)
	var madre := Node2D.new()
	madre.position = Vector2(60000, 60000)       # lontano dai nemici che altri test lasciano nell'albero
	_root().add_child(madre)
	var p: Node2D = preload("res://scenes/player.tscn").instantiate()
	madre.add_child(p)
	var s: Node = p.get_node("StatsComponent")
	s.set("spiritualita", float(s.call("get_stat", "spiritualita_max")))
	var e: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	madre.add_child(e)
	e.global_position = p.global_position + Vector2(0, 60)
	return [madre, p, e]


func test_anima_recisa_maleficio_e_possessione_si_disegnano_sul_nemico() -> void:
	for caso in [["death", 3, "death_recisione", 2], ["fool", 2, "fool_sfortuna_altrui", 2],
			["error", 4, "error_innesto_parassita", 1]]:
		var sc: Array = _scena(caso[0], caso[1])
		var r: Dictionary = _root().get_node("AbilityEngine").call("execute", caso[2], sc[1])
		assert_true(bool(r["ok"]), "%s parte: %s" % [caso[2], r["reason"]])
		assert_eq(_effetti_in(sc[2]).size(), caso[3], "%s: gli effetti stanno sul nemico (e lo seguono)" % caso[2])
		assert_eq(_effetti_in(sc[0]).size(), 0, "%s: niente attorno a chi lancia" % caso[2])
		sc[0].free()


func test_un_costo_su_di_se_si_disegna_su_chi_lancia() -> void:
	var sc: Array = _scena("moon", 5)
	var r: Dictionary = _root().get_node("AbilityEngine").call("execute", "moon_patto_di_sangue", sc[1])
	assert_true(bool(r["ok"]), "il patto parte")
	assert_eq(_effetti_in(sc[0]).size(), 2, "forza e sangue attorno a chi lo stringe")
	assert_eq(_effetti_in(sc[2]).size(), 0, "niente sul nemico")
	sc[0].free()


## Furto e fioritura devono vedersi: piu' lenti degli altri effetti (fps nei dati), almeno 0.6 secondi.
func test_furto_e_fioritura_durano_abbastanza() -> void:
	var gd: Node = _root().get_node("GameData")
	for tipo in ["steal", "plant_growth"]:
		var pv: Dictionary = gd.call("get_primitive_vfx", tipo)
		assert_true(pv.has("fps") and float(pv["fps"]) < 12.0, "%s piu' lento del ritmo di base" % tipo)
		assert_true(float(pv["frames"]) / float(pv["fps"]) >= 0.6, "%s dura almeno 0.6 s" % tipo)
