extends "res://tests/test_case.gd"
## US-8B12 — mondo unico: carica assets/world/ (tools/art/esporta_mondo.py) e
## costruisce solo i blocchi attorno al giocatore.

const Mondo := preload("res://scripts/world/mondo.gd")


func _mondo(tema: String = "luminoso") -> Node2D:
	var m: Node2D = Mondo.new()
	m.tema = tema
	assert_true(m.call("carica"), "mondo caricato")
	return m


func _cella(m: Node2D, p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / m.tile), int(p.y / m.tile))


func test_carica_le_misure_e_la_partenza() -> void:
	var m: Node2D = _mondo()
	assert_eq(m.larghezza, 1200, "larghezza dai dati")
	assert_eq(m.altezza, 1000, "altezza dai dati")
	var c: Vector2i = _cella(m, m.call("partenza"))
	assert_false(m.call("bloccata", c.x, c.y), "la partenza e' calpestabile")
	assert_eq(str(m.call("regione_a", c.x, c.y)), "mirwada", "si parte a Mirwada")
	m.free()


func test_il_mare_aperto_e_il_fuori_mappa_non_si_passano() -> void:
	var m: Node2D = _mondo()
	assert_true(m.call("bloccata", 1199, 999), "mare aperto nell'angolo")
	assert_true(m.call("bloccata", -1, 5), "fuori mappa")
	m.free()


func test_costruisce_solo_attorno_al_giocatore() -> void:
	var m: Node2D = _mondo()
	var p: Vector2 = m.call("partenza")
	m.call("segui", p)
	var lato: int = 2 * int(m.raggio_blocchi) + 1
	assert_eq(int(m.call("blocchi_caricati")), lato * lato, "blocchi attorno al giocatore")
	var terreno: TileMapLayer = m.get_node("Terreno")
	var c: Vector2i = _cella(m, p)
	assert_true(terreno.get_cell_source_id(c) >= 0, "la casella della partenza ha la sua tessera")
	assert_eq(terreno.get_cell_source_id(Vector2i(c.x + 200, c.y)), -1, "lontano non c'e' niente")
	m.call("segui", p + Vector2(200, 0) * m.tile)
	assert_eq(terreno.get_cell_source_id(c), -1, "spostandosi lontano il vecchio pezzo si libera")
	assert_eq(int(m.call("blocchi_caricati")), lato * lato, "sempre lo stesso numero di blocchi")
	m.free()


func test_le_caselle_bloccate_hanno_la_collisione() -> void:
	var m: Node2D = _mondo()
	var p: Vector2 = m.call("partenza")
	m.call("segui", p)
	var ost: TileMapLayer = m.get_node("Ostacoli")
	var c: Vector2i = _cella(m, p)
	var trovate: int = 0
	for y in range(c.y - 30, c.y + 30):
		for x in range(c.x - 30, c.x + 30):
			assert_eq(ost.get_cell_source_id(Vector2i(x, y)) >= 0, bool(m.call("bloccata", x, y)),
				"ostacolo dove i dati dicono bloccato (%d, %d)" % [x, y])
			if m.call("bloccata", x, y):
				trovate += 1
	assert_true(trovate > 0, "attorno al porto c'e' qualcosa che non si passa (il mare)")
	m.free()


func test_gli_oggetti_arrivano_col_loro_blocco() -> void:
	var m: Node2D = _mondo()
	var t: Array = (m.dati["luoghi"] as Dictionary)["trono_del_gigante"]
	m.call("segui", Vector2(float(t[0]) * m.tile, float(t[1]) * m.tile))
	var trono: int = 0
	for c in m.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != null and (c as Sprite2D).position.distance_to(
				Vector2(float(t[0]) + 0.5, float(t[1]) + 0.2) * m.tile) < 1.0:
			trono += 1
	assert_eq(trono, 1, "il trono sulla vetta")
	m.free()


func test_la_modalita_cupa_usa_i_suoi_fogli() -> void:
	var lum: Node2D = _mondo("luminoso")
	var cup: Node2D = _mondo("cupo")
	assert_eq(str(cup.call("tema_caricato")), "cupo", "tema cupo")
	var p: Vector2 = lum.call("partenza")
	lum.call("segui", p)
	cup.call("segui", p)
	var c: Vector2i = _cella(lum, p)
	var a: TileSetAtlasSource = lum.get_node("Terreno").tile_set.get_source(0)
	var b: TileSetAtlasSource = cup.get_node("Terreno").tile_set.get_source(0)
	assert_true(a.texture != b.texture and a.texture.get_image().get_data() != b.texture.get_image().get_data(),
		"fogli diversi")
	assert_eq(lum.call("bloccata", c.x, c.y), cup.call("bloccata", c.x, c.y), "stessi dati di gioco")
	lum.free()
	cup.free()


# --- US-8B12b: regione e zona dalla posizione ---------------------------------

func _ws() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("WorldState")


func _vai(m: Node2D, luogo: String, dx: float = 0.0, dy: float = 0.0) -> void:
	var p: Array = (m.dati["luoghi"] as Dictionary)[luogo]
	m.call("aggiorna_regione", Vector2((float(p[0]) + dx + 0.5) * m.tile, (float(p[1]) + dy + 0.5) * m.tile))


func test_la_regione_viene_dalla_posizione() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	_vai(m, "porto")
	assert_eq(str(_ws().call("regione_corrente")), "mirwada", "al porto: Mirwada")
	assert_eq(str(_ws().call("zona_corrente")), "porto", "zona: il porto")
	_vai(m, "trono_del_gigante")
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo", "al trono: le Marche")
	assert_eq(str(_ws().call("zona_corrente")), "trono_del_gigante", "zona: il trono")
	assert_true(_ws().call("e_scoperta", "marche_crepuscolo"), "le Marche risultano scoperte")
	_vai(m, "campo_di_battaglia")
	assert_eq(str(_ws().call("zona_corrente")), "luogo_di_battaglia", "luoghi_mondo abbina il nome della mappa al tag")
	_vai(m, "rovine_del_boss")
	assert_eq(str(_ws().call("regione_corrente")), "", "terra di mezzo: nessuna regione dei dati")
	assert_almost_eq(float(_ws().call("densita_mistica_corrente")), 0.2, "densita' di default fuori dalle regioni")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


func test_lontano_dai_luoghi_la_zona_e_vuota() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	_vai(m, "trono_del_gigante")
	_vai(m, "trono_del_gigante", 0.0, 60.0)
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo", "ancora nelle Marche")
	assert_eq(str(_ws().call("zona_corrente")), "", "nessun luogo vicino")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


# --- US-8B12c: main nel mondo unico, NPC e passaggi -----------------------------

func _pr() -> Node:
	return Engine.get_main_loop().root.get_node("Progression")


func test_gli_npc_stanno_al_luogo_del_loro_tag() -> void:
	var m: Node2D = _mondo()
	m.call("crea_npc")
	var presenti: Dictionary = Engine.get_main_loop().root.get_node("NpcSystem").call("presenti", "mirwada")
	assert_true(not presenti.is_empty(), "a Mirwada c'e' qualcuno in questo momento")
	var viste: Dictionary = {}
	for id in presenti:
		var a: Node2D = m.get_node_or_null("Npc_%s" % id)
		assert_true(a != null, "NPC %s nel mondo" % id)
		if a == null:
			continue
		var c: Vector2i = _cella(m, a.position)
		var l: Vector2i = m.call("luogo_del_tag", "mirwada", str(presenti[id]))
		assert_true(Vector2(c).distance_to(Vector2(l)) <= 12.0, "%s vicino al suo luogo" % id)
		assert_false(m.call("bloccata", c.x, c.y), "%s su una casella calpestabile" % id)
		assert_false(viste.has(c), "%s non sta sopra un altro NPC" % id)
		viste[c] = true
		assert_true(a.get_node("AnimationMachine").sprite_frames != null, "%s ha il disegno" % id)
		var asp: String = str((Engine.get_main_loop().root.get_node("GameData").call("get_npc", id).get("aspetto", {}) as Dictionary).get("sprite", ""))
		assert_true(ResourceLoader.exists("res://assets/placeholder/personaggio_%s_idle.png" % asp),
			"%s ha il suo aspetto (%s), non il disegno del giocatore" % [id, asp])
	m.free()


func test_la_frontiera_respinge_chi_e_troppo_avanti() -> void:
	var prima: Dictionary = _pr().call("per_salvataggio")
	var m: Node2D = _mondo()
	_pr().call("configura", "twilight_giant", 2)
	assert_false(m.call("ingresso_aperto", "frontiera_porte"), "sopra la Sequenza 4 la Frontiera e' chiusa")
	var f: Array = (m.dati["luoghi"] as Dictionary)["approdo_frontiera"]
	assert_false(m.call("aggiorna_regione", Vector2((float(f[0]) + 0.5) * m.tile, (float(f[1]) + 0.5) * m.tile)),
		"entrare nella Frontiera e' respinto")
	assert_false(m.call("viaggia_a", "frontiera_porte"), "nemmeno col viaggio veloce")
	_pr().call("configura", "twilight_giant", 9)
	assert_true(m.call("ingresso_aperto", "frontiera_porte"), "alla Sequenza 9 si entra")
	assert_true(m.call("ingresso_aperto", "mirwada"), "Mirwada non ha gating d'ingresso")
	m.free()
	_ws().call("pulisci")
	_pr().call("da_salvataggio", prima)


func test_il_viaggio_veloce_porta_al_primo_luogo_della_regione() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	var p := Node2D.new()
	p.add_to_group("player")
	m.add_child(p)
	Engine.get_main_loop().root.add_child(m)
	assert_true(m.call("viaggia_a", "marche_crepuscolo"), "si viaggia verso le Marche")
	var c: Vector2i = _cella(m, p.position)
	assert_eq(str(m.call("regione_a", c.x, c.y)), "marche_crepuscolo", "arrivato nelle Marche")
	assert_false(m.call("bloccata", c.x, c.y), "su una casella calpestabile")
	assert_eq(str(_ws().call("regione_corrente")), "marche_crepuscolo", "WorldState aggiornato")
	assert_false(m.call("viaggia_a", "marche_crepuscolo"), "gia' qui: niente viaggio")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


func test_il_main_parte_dal_mondo_unico() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var m: Node2D = main.get_node("Mondo")
	assert_true(m.get_script() == Mondo, "il main usa il mondo unico")
	assert_true(m.get_node_or_null("Player") != null, "il giocatore e' dentro il mondo (y_sort)")
	assert_true(m.get_node_or_null("Enemy") == null, "niente nemico di prova: i nemici vengono dai layout")
	main.free()


# --- 2026-10-25: le Marche si raggiungono solo volando o dal sottosuolo ----------

## Caselle raggiungibili dalla partenza: a piedi (solo caselle libere) o in volo
## (anche i dislivelli, mai l'acqua o il vuoto).
func _raggiungibili(m: Node2D, volo: bool) -> PackedByteArray:
	var p: Vector2 = m.call("partenza")
	return _bfs(m, PackedInt32Array([int(p.y / m.tile) * m.larghezza + int(p.x / m.tile)]), volo)


func _luogo_raggiunto(m: Node2D, visto: PackedByteArray, luogo: String, raggio: int = 2) -> bool:
	var l: Array = (m.dati["luoghi"] as Dictionary)[luogo]
	for dy in range(-raggio, raggio + 1):
		for dx in range(-raggio, raggio + 1):
			var x: int = int(l[0]) + dx
			var y: int = int(l[1]) + dy
			if x >= 0 and y >= 0 and x < m.larghezza and y < m.altezza and visto[y * m.larghezza + x] == 1:
				return true
	return false


func test_alle_regioni_senza_cammino_non_si_arriva_a_piedi_ma_volando_si() -> void:
	var m: Node2D = _mondo()
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var piedi: PackedByteArray = _raggiungibili(m, false)
	var volo: PackedByteArray = _raggiungibili(m, true)
	var controllate := 0
	for luogo in (m.dati["luoghi"] as Dictionary):
		var l: Array = m.dati["luoghi"][luogo]
		var rid: String = str(m.call("regione_a", int(l[0]), int(l[1])))
		var reg: Dictionary = gd.call("get_region", rid)
		if reg.is_empty() or rid == "frontiera_porte":
			continue                                   # mare/isole; la Frontiera e' ancora da decidere
		var accesso: Array = reg.get("accesso", ["a_piedi"])
		if "a_piedi" in accesso:
			assert_true(_luogo_raggiunto(m, piedi, luogo), "%s (%s) si raggiunge a piedi" % [luogo, rid])
		else:
			# la casella esatta: il Passo tra le Rupi sta sul bordo, ai suoi piedi si arriva
			assert_false(_luogo_raggiunto(m, piedi, luogo, 0), "%s (%s) NON si raggiunge a piedi" % [luogo, rid])
			if "volo" in accesso:
				assert_true(_luogo_raggiunto(m, volo, luogo), "%s (%s) si raggiunge volando" % [luogo, rid])
			controllate += 1
	assert_true(controllate > 0, "almeno una regione chiusa a piedi (le Marche)")
	m.free()


func test_i_dislivelli_hanno_il_loro_strato_di_collisione() -> void:
	var m: Node2D = _mondo()
	var t: Array = (m.dati["luoghi"] as Dictionary)["trono_del_gigante"]
	var p := Vector2(float(t[0]) * m.tile, float(t[1]) * m.tile)
	m.call("segui", p)
	var ost: TileMapLayer = m.get_node("Ostacoli")
	var dislivelli := 0
	var acqua := 0
	var c := Vector2i(int(t[0]), int(t[1]))
	for y in range(c.y - 24, c.y + 24):                # dentro i blocchi caricati
		for x in range(c.x - 24, c.x + 24):
			if not m.call("bloccata", x, y):
				continue
			var atlante: Vector2i = ost.get_cell_atlas_coords(Vector2i(x, y))
			if m.call("dislivello", x, y):
				assert_eq(atlante, Vector2i(1, 0), "dislivello sulla tessera dei dislivelli (%d, %d)" % [x, y])
				dislivelli += 1
			elif ost.get_cell_source_id(Vector2i(x, y)) >= 0:
				assert_eq(atlante, Vector2i(0, 0), "acqua sulla tessera dei muri (%d, %d)" % [x, y])
				acqua += 1
	assert_true(dislivelli > 0, "attorno al Trono ci sono dislivelli")
	var ts: TileSet = ost.tile_set
	assert_eq(ts.get_physics_layer_collision_layer(1), 16, "i dislivelli stanno sullo strato 5")
	m.free()


func test_chi_vola_passa_i_dislivelli() -> void:
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	assert_true(p.get_collision_mask_value(1) and p.get_collision_mask_value(5), "a piedi: muri e dislivelli")
	assert_false(p.call("in_volo"), "si parte a piedi")
	p.call("imposta_volo", true)
	assert_true(p.call("in_volo"), "in volo")
	assert_false(p.get_collision_mask_value(5), "in volo i dislivelli non fermano")
	assert_true(p.get_collision_mask_value(1), "in volo l'acqua ferma ancora")
	var e: CharacterBody2D = load("res://scenes/enemy.tscn").instantiate()
	assert_true(e.get_collision_mask_value(5), "i nemici non scendono dai dislivelli")
	p.free()
	e.free()


# --- 2026-10-25: il sottosuolo, secondo livello sulla stessa griglia --------------

func test_gli_ingressi_del_sottosuolo_sono_nel_mondo() -> void:
	var m: Node2D = _mondo()
	m.call("crea_ingressi")
	var ing: Dictionary = (m.dati.get("sottosuolo", {}) as Dictionary).get("ingressi", {})
	assert_true(ing.size() >= 40, "il sottosuolo ha i suoi ingressi (%d)" % ing.size())
	for nome in ing:
		var a: Node2D = m.get_node_or_null("Ingresso_%s" % nome)
		assert_true(a != null and (a.get_node("Disegno") as Sprite2D).texture != null, "%s ha il suo disegno" % nome)
	m.free()


func test_scendere_e_risalire_da_un_ingresso() -> void:
	var prima: Dictionary = _ws().call("per_salvataggio")
	var m: Node2D = _mondo()
	var p := Node2D.new()
	p.add_to_group("player")
	m.add_child(p)
	Engine.get_main_loop().root.add_child(m)
	m.call("crea_npc")
	m.call("crea_ingressi")
	var v: Array = (m.dati["sottosuolo"]["ingressi"] as Dictionary)["fogne_1"]
	var c := Vector2i(int(v[0]), int(v[1]))
	var sopra: int = m.call("tessera_a", c.x, c.y)
	assert_true(m.call("attraversa", "fogne_1"), "si scende dalla botola")
	assert_eq(str(m.get("livello")), "sottosuolo", "ora si e' sotto")
	var q: Vector2i = _cella(m, p.position)
	assert_false(m.call("bloccata", q.x, q.y), "sotto si arriva su una casella libera")
	assert_true(Vector2(q).distance_to(Vector2(c)) <= 3.0, "nello stesso punto dell'ingresso")
	for n in m.get_children():
		if n is Area2D and n.has_meta("npc_id"):
			assert_false((n as Area2D).visible, "gli NPC della superficie non si vedono sotto")
			break
	assert_true(m.call("attraversa", "fogne_1"), "si risale")
	assert_eq(str(m.get("livello")), "superficie", "di nuovo in superficie")
	assert_eq(int(m.call("tessera_a", c.x, c.y)), sopra, "le tessere della superficie tornano")
	m.free()
	_ws().call("pulisci")
	_ws().call("da_salvataggio", prima)


## Dalle fogne di Mirwada, camminando sotto terra, si arriva alle catacombe: le
## loro uscite sono nelle regioni con "sottosuolo" in accesso (le Marche).
func test_dal_sottosuolo_si_arriva_alle_regioni_che_lo_prevedono() -> void:
	var m: Node2D = _mondo()
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var piedi: PackedByteArray = _raggiungibili(m, false)
	var ing: Dictionary = m.dati["sottosuolo"]["ingressi"]
	var partenze := PackedInt32Array()
	for nome in ing:
		if _luogo_cella_raggiunta(m, piedi, ing[nome]):
			partenze.append(int(ing[nome][1]) * m.larghezza + int(ing[nome][0]))
	assert_true(partenze.size() > 0, "dalla partenza si arriva a piedi ad almeno un ingresso")
	assert_true(m.call("cambia_livello", "sottosuolo"), "il sottosuolo e' esportato")
	var sotto: PackedByteArray = _bfs(m, partenze, false)
	var regioni_raggiunte := {}
	for nome in ing:
		if _luogo_cella_raggiunta(m, sotto, ing[nome]):
			regioni_raggiunte[str(m.call("regione_a", int(ing[nome][0]), int(ing[nome][1])))] = true
	for reg in gd.call("get_regions"):
		if "sottosuolo" in ((reg as Dictionary).get("accesso", []) as Array):
			assert_true(regioni_raggiunte.has(str(reg["id"])), "dal sottosuolo si sbuca in %s" % reg["id"])
	m.free()


func _luogo_cella_raggiunta(m: Node2D, visto: PackedByteArray, v: Array) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x: int = int(v[0]) + dx
			var y: int = int(v[1]) + dy
			if x >= 0 and y >= 0 and x < m.larghezza and y < m.altezza and visto[y * m.larghezza + x] == 1:
				return true
	return false


func _bfs(m: Node2D, partenze: PackedInt32Array, volo: bool) -> PackedByteArray:
	var b: PackedByteArray = m.call("blocchi_grezzi")
	var w: int = m.larghezza
	var visto := PackedByteArray()
	visto.resize(w * m.altezza)
	var coda := partenze.duplicate()
	for c in partenze:
		visto[c] = 1
	var i := 0
	while i < coda.size():
		var c: int = coda[i]
		i += 1
		var x: int = c % w
		for n in [c - 1 if x > 0 else -1, c + 1 if x < w - 1 else -1, c - w, c + w]:
			if n < 0 or n >= visto.size() or visto[n] == 1:
				continue
			var k: int = b[n]
			if k == 0 or (volo and k != 255):
				visto[n] = 1
				coda.append(n)
	return visto


# --- 2026-10-25: il contenuto dei layout (fase 10/11) sul mondo generato ---------

func test_nemici_e_oggetti_dei_layout_stanno_nella_loro_regione() -> void:
	var m: Node2D = _mondo()
	m.call("popola")
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var attesi := 0
	for reg in gd.call("get_regions"):
		var lay: Dictionary = gd.call("get_layout", str(reg["id"]))
		attesi += (lay.get("nemici", []) as Array).size() + (lay.get("oggetti", []) as Array).size()
	var camp: Dictionary = gd.call("get_campagna")
	attesi += (camp.get("nemici", []) as Array).size() + (camp.get("oggetti", []) as Array).size()
	var trovati := 0
	var boss: Dictionary = {}
	var posti: Dictionary = {}
	for c in m.get_children():
		if not c.has_meta("regione_layout"):
			continue
		trovati += 1
		var rid: String = str(c.get_meta("regione_layout"))
		var cella: Vector2i = _cella(m, (c as Node2D).position)
		var attesa: String = "terra_di_mezzo" if rid == "campagna" else rid
		assert_eq(str(m.call("regione_a", cella.x, cella.y)), attesa, "%s sta nella sua regione (%s)" % [c.name, rid])
		var liv: String = str(c.get_meta("livello", "superficie"))
		m.call("cambia_livello", liv)
		assert_false(m.call("bloccata", cella.x, cella.y), "%s su una casella libera del suo livello (%s)" % [c.name, liv])
		m.call("cambia_livello", "superficie")
		assert_false(posti.has(cella), "%s non sta sopra un altro" % c.name)
		posti[cella] = true
		if c is CharacterBody2D and (c as Node2D).scale.x > 1.0:    # fuori scena: il gruppo arriva in _ready
			boss[rid] = true
	assert_eq(trovati, attesi, "tutti i nemici e gli oggetti dei layout sono nel mondo")
	for reg in gd.call("get_regions"):
		if not (gd.call("get_layout", str(reg["id"])) as Dictionary).is_empty():
			assert_true(boss.has(str(reg["id"])), "%s ha il suo boss" % reg["id"])
	m.free()


func test_un_elemento_di_una_zona_va_vicino_al_suo_luogo() -> void:
	var m: Node2D = _mondo()
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var lay: Dictionary = gd.call("get_layout", "mirwada")
	var r: Array = (lay["zone"] as Dictionary)["porto"]
	var posto: Dictionary = m.call("posto_dal_layout", "mirwada", lay, int(r[0]) + int(r[2]) / 2, int(r[1]) + int(r[3]) / 2)
	var c: Vector2i = posto["cella"]
	assert_eq(str(posto["livello"]), "superficie", "il porto e' in superficie")
	var porto: Vector2i = m.call("luogo_del_tag", "mirwada", "porto")
	assert_true(Vector2(c).distance_to(Vector2(porto)) <= 6.0, "il centro della zona del porto finisce al porto")
	m.free()


func test_il_sotterraneo_di_mirwada_e_nelle_fogne() -> void:
	var m: Node2D = _mondo()
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var lay: Dictionary = gd.call("get_layout", "mirwada")
	var r: Array = (lay["zone"] as Dictionary)["sotterraneo"]
	var posto: Dictionary = m.call("posto_dal_layout", "mirwada", lay, int(r[0]) + int(r[2]) / 2, int(r[1]) + int(r[3]) / 2)
	assert_eq(str(posto["livello"]), "sottosuolo", "la zona 'sotterraneo' del layout va sotto terra")
	var boss: Array = m.dati["sottosuolo"]["boss"]["boss_fogne"]
	assert_true(Vector2(posto["cella"]).distance_to(Vector2(float(boss[0]), float(boss[1]))) <= 8.0, "vicino al boss delle fogne")
	m.call("popola")
	for c in m.get_children():
		if c is CharacterBody2D and str(c.get_meta("livello", "")) == "sottosuolo":
			assert_false((c as CanvasItem).visible, "un nemico del sottosuolo non si vede in superficie")
			m.call("cambia_livello", "sottosuolo")
			assert_true((c as CanvasItem).visible, "sotto terra si vede")
			break
	m.free()


func test_nessun_nemico_vicino_alla_partenza() -> void:
	var m: Node2D = _mondo()
	m.call("popola")
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var r: float = float((gd.call("get_balance", "mondo") as Dictionary).get("raggio_partenza_senza_nemici", 0))
	assert_true(r > 0.0, "il raggio e' nei dati")
	var sp: Vector2 = m.call("partenza")
	for c in m.get_children():
		if c is CharacterBody2D and c.has_meta("regione_layout"):
			assert_true((c as Node2D).position.distance_to(sp) / m.tile > r, "%s lontano dalla partenza" % c.name)
	m.free()


# --- US-8B18: edifici e porte verso gli interni -------------------------------------

func test_gli_edifici_stanno_sul_loro_sedime_e_non_si_attraversano() -> void:
	var m: Node2D = _mondo()
	var ed: Array = m.dati.get("edifici", [])
	assert_true(ed.size() > 100, "la citta' e i villaggi hanno i loro edifici (%d)" % ed.size())
	var sp: Vector2 = m.call("partenza")
	var cp := Vector2i(int(sp.x / m.tile), int(sp.y / m.tile))
	for e in ed:
		var x0: int = int(e[0])
		var y0: int = int(e[1])
		assert_true(m.call("bloccata", x0 + int(e[2]) / 2, y0 + int(e[3]) / 2), "il sedime %s non si attraversa" % [e])
		assert_false(cp.x >= x0 and cp.x < x0 + int(e[2]) and cp.y >= y0 and cp.y < y0 + int(e[3]), "la partenza non e' dentro una casa")
	var con_sprite := 0
	for o in m.dati["oggetti"]:
		if str(o[0]).begins_with("edificio_"):
			con_sprite += 1
			assert_true((m.dati["sprite"] as Dictionary).has(str(o[0])), "%s ha il suo disegno" % o[0])
	assert_eq(con_sprite, ed.size(), "un disegno per edificio")
	m.free()


func test_ogni_interno_ha_la_sua_porta_su_una_casa() -> void:
	var m: Node2D = _mondo()
	m.call("crea_porte")
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var interni: Array = []
	for reg in gd.call("get_regions"):
		interni.append_array((gd.call("get_layout", str(reg["id"])) as Dictionary).get("edifici", []))
	interni.append_array((gd.call("get_campagna") as Dictionary).get("edifici", []))
	assert_eq(interni.size(), 14, "14 interni nei dati")
	for spec in interni:
		var iid: String = str(spec["interno_id"])
		var porta: Area2D = m.get_node_or_null("Porta_%s" % iid)
		assert_true(porta != null, "%s ha una porta" % iid)
		if porta == null:
			continue
		var c: Vector2i = _cella(m, porta.position)
		var liv: String = str(porta.get_meta("livello"))
		m.call("cambia_livello", liv)
		assert_false(m.call("bloccata", c.x, c.y), "la porta di %s e' su una casella libera (%s)" % [iid, liv])
		if liv == "superficie":
			var su_casa := false
			for e in m.dati["edifici"]:
				if c == Vector2i(int(e[0]) + int(e[2]) / 2, int(e[1]) + int(e[3])):
					su_casa = true
			assert_true(su_casa, "la porta di %s e' davanti a una casa" % iid)
			for dy in [1, 2, 3]:
				assert_false(m.call("bloccata", c.x, c.y + dy), "la soglia di %s non e' sotto il tetto di un'altra casa" % iid)
			if spec.has("villaggio"):
				var v: Array = m.dati["villaggi"][spec["villaggio"]]
				assert_true(Vector2(c).distance_to(Vector2(v[0], v[1])) < 16.0, "%s sta nel suo villaggio" % iid)
		m.call("cambia_livello", "superficie")
	m.free()


func test_entrare_e_uscire_da_un_interno() -> void:
	var main := Node2D.new()
	var m: Node2D = _mondo()
	main.add_child(m)
	var p := CharacterBody2D.new()
	p.add_to_group("player")
	m.add_child(p)
	Engine.get_main_loop().root.add_child(main)                  # _ready crea anche le porte
	var porta: Area2D = m.get_node("Porta_mirwada_bettola_del_porto")
	assert_true(m.call("entra", porta), "si entra nella bettola")
	assert_true(m.call("in_un_interno"), "dentro")
	assert_eq(p.get_parent().get("interno_id"), "mirwada_bettola_del_porto", "il giocatore esce dal nodo mondo ed entra nella stanza")
	assert_false(m.visible, "il mondo si nasconde")
	m.call("esci")
	assert_false(m.call("in_un_interno"), "fuori")
	assert_eq(p.get_parent(), m, "il giocatore torna nel mondo")
	assert_true(p.position.distance_to(porta.position) < 1.0, "davanti alla porta")
	main.free()


func test_salvare_dentro_un_interno_riporta_davanti_alla_porta() -> void:
	var main := Node2D.new()
	var m: Node2D = _mondo()
	main.add_child(m)
	var p := CharacterBody2D.new()
	p.add_to_group("player")
	m.add_child(p)
	Engine.get_main_loop().root.add_child(main)
	var porta: Area2D = m.get_node("Porta_mirwada_bettola_del_porto")
	m.call("entra", porta)
	var dati: Dictionary = Engine.get_main_loop().root.get_node("GameState").call("snapshot")
	assert_eq(dati["posizione"], porta.position, "si salva la porta, non le coordinate della stanza")
	assert_eq(str(dati["mondo"]["livello"]), "superficie", "e il livello")
	var sotto: Vector2 = Vector2(589.5, 371.5) * float(m.tile)
	m.call("riprendi", "sottosuolo", sotto)
	assert_false(m.call("in_un_interno"), "caricando si esce dall'interno")
	assert_eq(m.livello, "sottosuolo", "sul livello salvato")
	assert_eq(p.get_parent(), m, "il giocatore e' di nuovo nel mondo")
	assert_eq(p.position, sotto, "nel punto salvato")
	m.call("cambia_livello", "superficie")
	main.free()


# --- US-8B21a: varchi come ingressi verso le sotto-aree -------------------------------

func test_ogni_varco_e_un_ingresso_nella_sua_regione() -> void:
	var m: Node2D = _mondo()
	m.call("crea_varchi")
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var visti := 0
	for reg in gd.call("get_regions"):
		for g in (reg as Dictionary).get("gating", []):
			if not (g as Dictionary).has("varco"):
				continue
			visti += 1
			var porta: Area2D = m.get_node_or_null("Varco_%s" % g["area"])
			assert_true(porta != null, "il varco %s e' sulla mappa" % g["area"])
			if porta == null:
				continue
			var c: Vector2i = _cella(m, porta.position)
			assert_eq(str(m.call("regione_a", c.x, c.y)), str(reg["id"]), "%s nella sua regione" % g["area"])
			assert_false(m.call("bloccata", c.x, c.y), "%s su una casella libera" % g["area"])
			assert_eq(str(porta.get_meta("interno_id")), str(g["varco"]["interno"]), "%s porta al suo interno" % g["area"])
			assert_false((gd.call("get_interno", str(g["varco"]["interno"])) as Dictionary).is_empty(), "l'interno esiste")
			assert_true(porta.get_node("Chiuso") != null and porta.get_node("Aperto") != null, "disegno chiuso e aperto")
			m.call("segui", porta.position)
			for o in m.get_children():                   # davanti al varco niente alberi o rocce
				if o is Sprite2D:
					var co: Vector2i = _cella(m, (o as Sprite2D).position)
					assert_false(Rect2i(c.x - 3, c.y - 2, 7, 7).has_point(co), "spiazzo sgombro davanti a %s" % g["area"])
	assert_eq(visti, 6, "sei sotto-aree con un varco")
	m.free()


func test_un_varco_chiuso_non_fa_entrare_e_aperto_si() -> void:
	var ks: Node = Engine.get_main_loop().root.get_node("KnowledgeStore")
	ks.call("dimentica", "testi_ordine_minore")
	var main := Node2D.new()
	var m: Node2D = _mondo()
	main.add_child(m)
	var p := CharacterBody2D.new()
	p.add_to_group("player")
	m.add_child(p)
	Engine.get_main_loop().root.add_child(main)
	var varco: Area2D = m.get_node("Varco_ali_interne")
	m.call("_aggiorna_varchi")
	assert_true((varco.get_node("Chiuso") as CanvasItem).visible, "senza la conoscenza il varco e' chiuso")
	assert_eq((varco.get_node("Prompt") as Label).text, tr("HUD_VARCO_CHIUSO"), "e lo dice, senza dire come si apre")
	assert_false(m.call("entra", varco), "chiuso non si entra")
	ks.call("impara", "testi_ordine_minore")
	m.call("_aggiorna_varchi")
	assert_true((varco.get_node("Aperto") as CanvasItem).visible, "con la conoscenza si apre")
	assert_true(m.call("entra", varco), "aperto si entra")
	assert_eq(p.get_parent().get("interno_id"), "archivio_sala_dei_sigilli", "nella sala dei sigilli")
	m.call("esci")
	assert_true(p.position.distance_to(varco.position) < 1.0, "e si torna davanti al varco")
	ks.call("dimentica", "testi_ordine_minore")
	main.free()
