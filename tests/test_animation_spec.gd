extends "res://tests/test_case.gd"
## US-021a — animations.json caricato da GameData e letto tramite AnimationSpec.

const AnimationSpec := preload("res://scripts/animation_spec.gd")


func _data() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


func _spec(cat: String, nome: String) -> RefCounted:
	return AnimationSpec.new(_data().call("get_animation", cat, nome))


func test_animations_caricato_senza_errori() -> void:
	var gd: Node = _data()
	assert_eq((gd.call("last_errors") as PackedStringArray).size(), 0, "nessun errore di caricamento")
	assert_true((gd.call("animation_categories") as Array).has("personaggio"), "categoria personaggio presente")


func test_convenzioni() -> void:
	var gd: Node = _data()
	# JSON legge i numeri come float: confronto elemento per elemento come int.
	var dim: Array = gd.call("animation_convention", "dimensione_frame")
	assert_eq(int(dim[0]), 32, "larghezza frame")
	assert_eq(int(dim[1]), 32, "altezza frame")
	assert_eq(gd.call("animation_convention", "direzioni"), ["down", "up", "left", "right"], "4 direzioni")
	assert_eq(gd.call("animation_convention", "chiave_inventata"), null, "chiave assente -> null")


func test_campi_base_walk() -> void:
	var s: RefCounted = _spec("personaggio", "walk")
	assert_true(s.is_valid(), "walk valida")
	assert_eq(s.frame_count(), 6, "6 frame")
	assert_eq(s.fps(), 12.0, "12 fps")
	assert_true(s.loops(), "walk in loop")
	assert_true(s.is_directional(), "walk direzionale")
	assert_almost_eq(s.duration_sec(), 0.5, "durata 6/12 s")


func test_animazione_inesistente() -> void:
	var s: RefCounted = _spec("personaggio", "non_esiste")
	assert_false(s.is_valid(), "animazione ignota non valida")
	assert_eq(s.frame_count(), 0, "0 frame")
	assert_eq(s.phase_of(0), "", "nessuna fase")


func test_fasi_del_combat_attack_light() -> void:
	var s: RefCounted = _spec("personaggio", "attack_light")
	# animations.json: anticipo [0,1], attivi [2], recupero [3,4]
	assert_eq(s.phase_of(0), "anticipo", "frame 0 = anticipo")
	assert_eq(s.phase_of(1), "anticipo", "frame 1 = anticipo")
	assert_eq(s.phase_of(2), "attivi", "frame 2 = attivi")
	assert_eq(s.phase_of(3), "recupero", "frame 3 = recupero")
	assert_eq(s.phase_of(4), "recupero", "frame 4 = recupero")


func test_eventi_hitbox_attack_light() -> void:
	var s: RefCounted = _spec("personaggio", "attack_light")
	assert_true(s.has_event_at(2, "hitbox_on"), "hitbox_on al frame 2")
	assert_true(s.has_event_at(3, "hitbox_off"), "hitbox_off al frame 3")
	assert_false(s.has_event_at(0, "hitbox_on"), "niente hitbox al frame 0")


func test_iframe_del_dash() -> void:
	var s: RefCounted = _spec("personaggio", "dash")
	# animations.json: iframe_da 0, iframe_a 2
	assert_eq(s.iframe_window(), Vector2i(0, 2), "finestra i-frame 0..2")
	assert_true(s.is_invulnerable_at(0), "invulnerabile al frame 0")
	assert_true(s.is_invulnerable_at(2), "invulnerabile al frame 2")
	assert_false(s.is_invulnerable_at(3), "vulnerabile al frame 3")


func test_niente_iframe_dove_non_dichiarati() -> void:
	var s: RefCounted = _spec("personaggio", "walk")
	assert_eq(s.iframe_window(), Vector2i(-1, -1), "walk senza i-frame")
	assert_false(s.is_invulnerable_at(0), "walk mai invulnerabile")


func test_finestra_parata_perfetta() -> void:
	var s: RefCounted = _spec("personaggio", "parry")
	# animations.json: finestra_perfetta [0, 1]
	assert_eq(s.perfect_parry_frames(), [0, 1], "finestra perfetta [0,1]")
	assert_true(s.is_perfect_parry_at(1), "frame 1 perfetto")
	assert_false(s.is_perfect_parry_at(2), "frame 2 non piu' perfetto")


func test_anticipo_in_stato_del_nemico() -> void:
	var s: RefCounted = _spec("nemico_base", "attack")
	assert_eq(s.prefix_state(), "anticipo", "attack del nemico usa lo stato 'anticipo'")
	var idle: RefCounted = _spec("personaggio", "idle")
	assert_eq(idle.prefix_state(), "", "idle senza stato di anticipo")


func test_coerenza_frame_ed_eventi() -> void:
	# Ogni evento/fase deve citare un frame dentro [0, frames). Stesso
	# controllo del validator Python, qui su cio' che e' finito in memoria.
	var gd: Node = _data()
	var problemi: PackedStringArray = []
	for cat in gd.call("animation_categories"):
		for nome in gd.call("animation_names", cat):
			var s: RefCounted = _spec(cat, nome)
			var n: int = s.frame_count()
			if n <= 0:
				problemi.append("%s/%s: frames <= 0" % [cat, nome])
				continue
			for fase in ["anticipo", "attivi", "recupero", "finestra_perfetta"]:
				for idx in s.frames_in_phase(fase):
					if int(idx) < 0 or int(idx) >= n:
						problemi.append("%s/%s: %s cita il frame %s fuori da [0,%d)" % [cat, nome, fase, idx, n])
			var w: Vector2i = s.iframe_window()
			if w.x >= 0 and (w.x >= n or w.y >= n or w.y < w.x):
				problemi.append("%s/%s: finestra i-frame %s incoerente con %d frame" % [cat, nome, w, n])
	assert_eq(problemi.size(), 0, "incoerenze frame/eventi: " + ", ".join(problemi))
