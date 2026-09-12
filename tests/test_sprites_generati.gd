extends "res://tests/test_case.gd"
## US-812 — sprite generati proceduralmente (tools/generate_sprites.py):
## esistenza/dimensioni dei 19 fogli, tell del nemico visibile, destra =
## specchio esatto di sinistra.

const DIM := 32


func _spec() -> Dictionary:
	var f := FileAccess.open("res://data/animations.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _load(cat: String, nome: String) -> Image:
	var img := Image.new()
	var err: int = img.load("res://assets/placeholder/%s_%s.png" % [cat, nome])
	assert_eq(err, OK, "assets/placeholder/%s_%s.png si carica" % [cat, nome])
	return img


func test_ogni_foglio_esiste_con_le_dimensioni_attese() -> void:
	var spec: Dictionary = _spec()
	var direzioni: Array = spec["convenzioni"]["direzioni"]
	var n: int = 0
	for cat in ["personaggio", "nemico_base", "pet"]:
		var anims: Dictionary = spec.get(cat, {})
		for nome in anims:
			if str(nome).begins_with("_"):
				continue
			var anim: Dictionary = anims[nome]
			var img: Image = _load(cat, nome)
			var righe: int = direzioni.size() if bool(anim.get("direzionale", false)) else 1
			var attese_w: int = int(anim["frames"]) * DIM
			var attese_h: int = righe * DIM
			assert_eq(img.get_width(), attese_w, "%s_%s largo %d" % [cat, nome, attese_w])
			assert_eq(img.get_height(), attese_h, "%s_%s alto %d" % [cat, nome, attese_h])
			n += 1
	assert_eq(n, 19, "19 fogli totali (10 personaggio + 6 nemico_base + 3 pet)")


## FR-8: il tell del nemico deve leggersi dal frame 0 dell'anticipo, non
## solo dall'attacco — qui basta che sia visivamente diverso da idle.
func test_il_tell_del_nemico_si_vede_dal_frame_idle() -> void:
	var idle: Image = _load("nemico_base", "idle")
	var anticipo: Image = _load("nemico_base", "anticipo")
	var diversi := false
	for y in DIM:
		for x in DIM:
			if idle.get_pixel(x, y) != anticipo.get_pixel(x, y):
				diversi = true
				break
		if diversi:
			break
	assert_true(diversi, "il frame 0 (down) di anticipo differisce da idle: il tell si vede")


## Convenzione delle 4 direzioni (CLAUDE.md): destra e' lo specchio esatto
## di sinistra, riga per riga, frame per frame (mai la riga intera
## ribaltata: l'ordine dei frame nel tempo resta lo stesso).
func test_frame_destro_e_lo_specchio_esatto_del_sinistro() -> void:
	var spec: Dictionary = _spec()
	var direzioni: Array = spec["convenzioni"]["direzioni"]
	var riga_left: int = direzioni.find("left")
	var riga_right: int = direzioni.find("right")
	var verificati := 0
	for cat in ["personaggio", "nemico_base"]:
		var anims: Dictionary = spec.get(cat, {})
		for nome in anims:
			if str(nome).begins_with("_"):
				continue
			var anim: Dictionary = anims[nome]
			if not bool(anim.get("direzionale", false)):
				continue
			var img: Image = _load(cat, nome)
			var frames: int = int(anim["frames"])
			var mismatch := 0
			for fr in frames:
				for x in DIM:
					for y in DIM:
						var sinistro: Color = img.get_pixel(fr * DIM + x, riga_left * DIM + y)
						var destro: Color = img.get_pixel(fr * DIM + (DIM - 1 - x), riga_right * DIM + y)
						if sinistro != destro:
							mismatch += 1
			assert_eq(mismatch, 0, "%s_%s: destra e' lo specchio esatto di sinistra" % [cat, nome])
			verificati += 1
	assert_true(verificati > 0, "almeno un foglio direzionale verificato")
