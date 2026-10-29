extends "res://tests/test_case.gd"
## US-812 — fogli di personaggio/nemico_base/pet: esistenza e dimensioni,
## tell del nemico visibile, un disegno in ogni direzione. Dal 2026-10-14 li fa
## tools/art/build_personaggi.py (sprite-forge, 64 px): la dimensione si legge
## da data/animations.json, e destra NON e' piu' lo specchio di sinistra (la
## luce viene sempre da alto-sinistra: specchiare il disegno la sposterebbe).

var DIM: int = 64


func _spec() -> Dictionary:
	var f := FileAccess.open("res://data/animations.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _load(cat: String, nome: String) -> Image:
	var img := Image.new()
	var err: int = img.load("res://assets/placeholder/%s_%s.png" % [cat, nome])
	assert_eq(err, OK, "assets/placeholder/%s_%s.png si carica" % [cat, nome])
	return img


func prepara() -> void:
	DIM = int(_spec()["convenzioni"]["dimensione_frame"][0])


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
	assert_true(n >= 19, "almeno i 19 fogli della fase 8 (ora %d, da data/animations.json)" % n)


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


## Ogni direzione ha il suo disegno (sprite-forge disegna le 4 viste dal
## modello 3D con la stessa luce): nessuna riga vuota, e destra diversa da
## sinistra (non una copia).
func test_ogni_direzione_ha_il_suo_disegno() -> void:
	var spec: Dictionary = _spec()
	var direzioni: Array = spec["convenzioni"]["direzioni"]
	var riga_left: int = direzioni.find("left")
	var riga_right: int = direzioni.find("right")
	var verificati := 0
	for cat in ["personaggio", "nemico_base"]:
		var anims: Dictionary = spec.get(cat, {})
		for nome in anims:
			if str(nome).begins_with("_") or not bool((anims[nome] as Dictionary).get("direzionale", false)):
				continue
			var img: Image = _load(cat, nome)
			for r in direzioni.size():
				assert_false(img.get_region(Rect2i(0, r * DIM, DIM, DIM)).is_invisible(),
					"%s_%s: la riga %s ha un disegno" % [cat, nome, direzioni[r]])
			var sx: Image = img.get_region(Rect2i(0, riga_left * DIM, DIM, DIM))
			var dx: Image = img.get_region(Rect2i(0, riga_right * DIM, DIM, DIM))
			assert_true(sx.get_data() != dx.get_data(), "%s_%s: destra non e' una copia di sinistra" % [cat, nome])
			verificati += 1
	assert_true(verificati > 0, "almeno un foglio direzionale verificato")
