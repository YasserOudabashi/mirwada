extends TileMapLayer
## Scena placeholder di una regione (US-602/603). UNA sola implementazione per
## tutte e 5 le regioni: il contenuto (id, location_tags, palette) viene dai
## dati (data/world/regions.json via GameData). Una scena .tscn per regione
## imposta solo region_id nell'inspector.
##
## Come la zona di test di US-006, e' un tilemap diagnostico: bordo di muri e
## un pavimento, con una Area2D per ogni location_tag della regione (marcata
## col tag, cosi' entrando ci si legge dove si e') e i passaggi verso le altre
## regioni (hub-and-spoke: la citta' e' collegata a tutte, ognuna torna alla
## citta'). L'arte vera e i biomi disegnati a mano sono un non-goal di questa
## fase; il gating dei passaggi si applica in US-611.
##
## NIENTE class_name: coerente col resto del progetto.

signal zona_cambiata(location_tag: String)

const AreaGate := preload("res://scripts/area_gate.gd")

const TILE := 32
const W := 48
const H := 36

const SORGENTE := 0

## Cella di comparsa del giocatore. Default; _ready() la sovrascrive con
## layout.spawn se la regione ha un layout disegnato a mano (US-805).
var _spawn := Vector2i(4, 4)
## La regione hub: collegata a tutte le altre (design-world cap. 2.1).
const HUB := "mirwada"

## Regione da caricare. Le .tscn in scenes/regioni/ lo impostano.
@export var region_id: String = ""

var _tag_corrente: String = ""
var _in_viaggio: bool = false
## L'NPC nel cui raggio si trova il giocatore ("" = nessuno). Premere
## "interagisci" qui sopra avvia il suo dialogo (US-613b).
var _npc_vicino: String = ""
## US-806: conteggio dei nemici spawnati da layout.nemici ancora vivi, e
## aggregato per l'area_cleared emesso alla morte dell'ultimo.
var _nemici_vivi: int = 0
var _area_nemici_senza_abilita: bool = true


func _ready() -> void:
	tile_set = load("res://assets/placeholder/tileset.tres")
	var layout: Dictionary = _layout_dati()
	if not layout.is_empty():
		var sp: Array = (layout.get("spawn", []) as Array)
		if sp.size() == 2:
			_spawn = Vector2i(int(sp[0]), int(sp[1]))
	_dipingi()
	_tinta_di_fondo()
	_crea_zone()
	_crea_passaggi()
	_crea_gate()
	_crea_nemici()
	_crea_oggetti()
	_crea_npc()
	_colloca_giocatore()
	_registra_regione()
	var ts: Node = get_node_or_null("/root/TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):
		ts.momento_cambiato.connect(func(_m): _crea_npc())


func _regione_dati() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_region", region_id) if gd != null else {}


## {} se la regione non ha un layout disegnato a mano (US-805): ogni chiamante
## qui sotto cade sul comportamento piatto di sempre.
func _layout_dati() -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	return gd.call("get_layout", region_id) if gd != null else {}


## Mappa carattere-legenda (layout.schema.json) -> colonna di tileset.png,
## stesso ordine di generate_sprites.py.TILESET_COLONNE (US-813). L'acqua e'
## fisicamente solida in questa story: la resa grafica distinta arriva, il
## comportamento speciale resta un non-goal.
const _COLONNA_PER_CARATTERE := {
	".": 0, "#": 1, "o": 2, "~": 3, ",": 4, "=": 5, "t": 6, "+": 7,
}
const _COLONNA_MURO := 1
const _COLONNA_PAVIMENTO := 0


## Riga di tileset.png per questa regione: 0 (neutra) o 1 + indice della sua
## palette_visiva in vfx.json.pathway_palette_visiva (stesso ordine con cui
## generate_sprites.py.build_tileset ha disegnato le righe). Nessun nome di
## Pathway qui: solo l'indice.
func _riga_tileset() -> int:
	var pal_id: String = str(_regione_dati().get("palette_visiva", ""))
	if pal_id.is_empty() or pal_id == "neutra":
		return 0
	var gd: Node = get_node_or_null("/root/GameData")
	var ids: Array = gd.call("vfx_palette_ids") if gd != null else []
	var i: int = ids.find(pal_id)
	return 1 + i if i >= 0 else 0


func _dipingi() -> void:
	var riga: int = _riga_tileset()
	var layout: Dictionary = _layout_dati()
	var mappa: Array = (layout.get("mappa", []) as Array)
	if mappa.size() == H:
		for y in H:
			var stringa: String = str(mappa[y])
			if stringa.length() != W:
				continue
			for x in W:
				var col: int = int(_COLONNA_PER_CARATTERE.get(stringa[x], _COLONNA_PAVIMENTO))
				set_cell(Vector2i(x, y), SORGENTE, Vector2i(col, riga))
		return
	for x in W:
		for y in H:
			var bordo: bool = x == 0 or y == 0 or x == W - 1 or y == H - 1
			var col: int = _COLONNA_MURO if bordo else _COLONNA_PAVIMENTO
			set_cell(Vector2i(x, y), SORGENTE, Vector2i(col, riga))


## Densita' mistica visiva minima: una tinta di sfondo dalla palette_visiva
## della regione (design-world cap. 2). 'neutra' non ha palette -> niente
## tinta (la citta' resta piatta).
func _tinta_di_fondo() -> void:
	var pal_id: String = str(_regione_dati().get("palette_visiva", ""))
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null or pal_id.is_empty() or pal_id == "neutra":
		return
	var pal: Dictionary = gd.call("get_vfx_palette", pal_id)
	var hex: String = str(pal.get("primario", ""))
	if not hex.begins_with("#"):
		return
	var c := Color(hex)
	c.a = 0.14
	var rect := ColorRect.new()
	rect.name = "TintaRegione"
	rect.color = c
	rect.position = Vector2.ZERO
	rect.size = Vector2(W * TILE, H * TILE)
	rect.z_index = -100
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## Una Area2D per location_tag, disposte a griglia nell'interno. Ogni zona
## porta il proprio tag come meta: entrando, il giocatore "legge" dove si
## trova (US-602). La grafica e' assente: e' un rettangolo invisibile.
func _crea_zone() -> void:
	var tags: Array = (_regione_dati().get("location_tags", []) as Array)
	if tags.is_empty():
		return

	var zone: Dictionary = (_layout_dati().get("zone", {}) as Dictionary)

	# griglia di celle-zona nell'area interna (dentro il bordo di muri):
	# fallback per i tag senza rettangolo nel layout (o senza layout affatto).
	var cols: int = int(ceil(sqrt(float(tags.size()))))
	var righe: int = int(ceil(float(tags.size()) / float(cols)))
	var cell_w: float = float(W - 2) * TILE / float(cols)
	var cell_h: float = float(H - 2) * TILE / float(righe)

	for i in tags.size():
		var tag: String = str(tags[i])
		var centro: Vector2
		var dim: Vector2
		if zone.has(tag):
			var r: Array = (zone[tag] as Array)
			dim = Vector2(float(r[2]), float(r[3])) * TILE
			centro = Vector2(float(r[0]), float(r[1])) * TILE + dim * 0.5
		else:
			var col: int = i % cols
			var row: int = i / cols
			dim = Vector2(cell_w, cell_h)
			centro = Vector2(
				TILE + cell_w * (col + 0.5),
				TILE + cell_h * (row + 0.5))
		var area := Area2D.new()
		area.name = "Zona_%s" % tag
		area.set_meta("location_tag", tag)
		area.position = centro
		# monitora il corpo del giocatore (layer 1): mask di default 1 basta.
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = dim
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(_su_ingresso_zona.bind(tag))
		add_child(area)


## I passaggi verso le altre regioni. Hub-and-spoke: la citta' ha un passaggio
## per ogni altra regione lungo il bordo destro; ogni altra regione ne ha uno
## verso la citta' lungo il bordo sinistro. Gli id di destinazione escono dai
## dati (GameData.get_regions), nessun nome hardcoded.
func _crea_passaggi() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var destinazioni: Array = []
	if region_id == HUB:
		for r in gd.call("get_regions"):
			var rid: String = str((r as Dictionary).get("id", ""))
			if rid != HUB and not rid.is_empty():
				destinazioni.append(rid)
	elif not region_id.is_empty():
		destinazioni.append(HUB)

	var passaggi: Dictionary = (_layout_dati().get("passaggi", {}) as Dictionary)

	for i in destinazioni.size():
		var dest: String = str(destinazioni[i])
		var pos: Vector2
		if passaggi.has(dest):
			var c: Array = (passaggi[dest] as Array)
			pos = Vector2(float(c[0]) + 0.5, float(c[1]) + 0.5) * TILE
		else:
			var lato_destro: bool = region_id == HUB
			var x: float = float(W - 3) * TILE if lato_destro else 3.0 * TILE
			var y: float = TILE * 3 + (float(H - 6) * TILE) * (float(i) + 0.5) / float(maxi(destinazioni.size(), 1))
			pos = Vector2(x, y)
		var area := Area2D.new()
		area.name = "Passaggio_%s" % dest
		area.set_meta("target_region", dest)
		area.position = pos
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE * 1.5, TILE * 2)
		shape.shape = rect
		area.add_child(shape)
		# US-813: passaggio.png (arco/cartello), un tile sopra l'altro per
		# coprire l'area 1.5x2 tile del varco.
		var tex: Texture2D = load("res://assets/placeholder/passaggio.png")
		if tex != null:
			for cy in 2:
				var s := Sprite2D.new()
				s.texture = tex
				s.position = Vector2(0, -TILE * 0.5 + TILE * cy)
				area.add_child(s)
		area.body_entered.connect(_su_passaggio.bind(dest))
		add_child(area)


## Una AreaGate per ogni voce di regions.json.gating[]: una barriera che si
## apre/chiude coi 6 modi di gate_types.json (US-611). Disposte in colonna
## nell'interno; l'arte vera e la geometria sono un non-goal di fase 6.
func _crea_gate() -> void:
	var gates: Array = (_regione_dati().get("gating", []) as Array)
	for i in gates.size():
		var g: Variant = gates[i]
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var ag: Area2D = AreaGate.new()
		ag.name = "Gate_%s" % str((g as Dictionary).get("area", i))
		ag.position = Vector2(
			float(W) * 0.5 * TILE,
			TILE * 4 + (float(H - 8) * TILE) * (float(i) + 0.5) / float(maxi(gates.size(), 1)))
		ag.call("configura", region_id, g)
		add_child(ag)


## US-806: i nemici dichiarati in layout.nemici (Sequenza, scala, override
## sono DATI: un boss e' sequenza piu' bassa + override piu' duro + scala
## piu' grande, MAI un flag "boss" nel codice). override e scale vanno
## impostati PRIMA di add_child (enemy.gd li legge in _ready);
## configure_from_balance va DOPO (sovrascrive il default Sequenza 9 di
## StatsComponent._ready). Nessuna voce (layout assente o senza nemici) ->
## nessun nemico spawnato, come oggi per le regioni senza layout.
## US-809a: layout.drop ({"<sequenza>": [item_id, ...]}) e' l'UNICA fonte
## di override.oggetti_a_morte — nessuna tabella nel codice. Iniettato su
## una COPIA dell'override dichiarato (.duplicate: lo stesso dict di
## layout.nemici[i].override e' condiviso, mutarlo direttamente lo
## corromperebbe per ogni futura istanza dello stesso layout, stesso bug
## gia' corretto in enemy.gd::_ready per _cfg in US-806).
func _crea_nemici() -> void:
	var layout: Dictionary = _layout_dati()
	var nemici: Array = (layout.get("nemici", []) as Array)
	var drop: Dictionary = (layout.get("drop", {}) as Dictionary)
	_nemici_vivi = nemici.size()
	_area_nemici_senza_abilita = true
	for n in nemici:
		var spec: Dictionary = n as Dictionary
		var sequenza: int = int(spec.get("sequenza", 9))
		var override: Dictionary = (spec.get("override", {}) as Dictionary).duplicate(true)
		if drop.has(str(sequenza)):
			override["oggetti_a_morte"] = drop[str(sequenza)]
		var e: Node = preload("res://scenes/enemy.tscn").instantiate()
		e.set("override", override)
		e.set("scale", Vector2.ONE * float(spec.get("scala", 1.0)))
		add_child(e)
		e.set("global_position", to_global(map_to_local(
			Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		e.set("sequenza", sequenza)
		e.get_node("StatsComponent").call("configure_from_balance", sequenza)
		e.connect("morto", _su_nemico_morto)


## Contratto di US-804: emesso alla morte dell'ultimo nemico spawnato dal
## layout. senza_alleati_caduti e' sempre true in questa fase (nessun
## alleato in scena, come tg_9_protettore); senza_abilita e' l'aggregato
## (true solo se OGNI nemico dell'area e' morto senza che il player abbia
## mai lanciato un'abilita' durante il suo scontro); senza_uccidere e'
## sempre false (l'area si libera uccidendo, in questa fase).
func _su_nemico_morto(chi: Node) -> void:
	if not bool(chi.call("senza_abilita")):
		_area_nemici_senza_abilita = false
	_nemici_vivi -= 1
	if _nemici_vivi > 0:
		return
	var et: Node = get_node_or_null("/root/EventTracker")
	if et != null:
		et.call("emit_event", "area_cleared", {
			"senza_alleati_caduti": true,
			"senza_abilita": _area_nemici_senza_abilita,
			"senza_uccidere": false,
		})


## US-806: gli oggetti a terra dichiarati in layout.oggetti. item_pickup.gd
## riusa Area2D/setup di characteristic_pickup.gd; solo 'quantita' e' un
## campo in piu'.
func _crea_oggetti() -> void:
	var oggetti: Array = (_layout_dati().get("oggetti", []) as Array)
	for o in oggetti:
		var spec: Dictionary = o as Dictionary
		var pickup := preload("res://scripts/item_pickup.gd").new()
		add_child(pickup)
		pickup.call("setup", str(spec.get("item_id", "")), to_global(map_to_local(
			Vector2i(int(spec.get("x", 0)), int(spec.get("y", 0))))))
		pickup.set("quantita", int(spec.get("quantita", 1)))


## Gli NPC presenti ORA (schedule + momento corrente, US-612): uno sprite
## nella zona del loro location_tag, con sopra una Label col nome (US-813:
## niente piu' un ColorRect anonimo). Ricostruito a ogni momento_cambiato -
## Bruno compare solo di notte, Mirco sparisce a notte_fonda. Entrarci =
## "incontrato".
##
## US-813: piu' NPC con lo stesso location_tag (es. 6 a "piazza") non vanno
## impilati sullo stesso punto - prima erano ColorRect anonimi identici e non
## si notava, ora con sprite+nome l'impilamento e' illeggibile (etichette
## sovrapposte). Distribuiti in fila, centrati sulla posizione della zona.
func _crea_npc() -> void:
	for c in get_children():
		if c is Area2D and c.has_meta("npc_id"):
			c.queue_free()
	var ns: Node = get_node_or_null("/root/NpcSystem")
	var gd: Node = get_node_or_null("/root/GameData")
	if ns == null:
		return
	var presenti: Dictionary = ns.call("presenti", region_id)
	var per_zona: Dictionary = {}
	for id in presenti:
		var tag: String = str(presenti[id])
		if not per_zona.has(tag):
			per_zona[tag] = []
		(per_zona[tag] as Array).append(str(id))

	for tag in per_zona:
		var ids: Array = per_zona[tag]
		var zona: Node2D = get_node_or_null("Zona_%s" % tag) as Node2D
		var centro: Vector2 = zona.position if zona != null else Vector2(W, H) * TILE * 0.5
		for i in ids.size():
			_crea_un_npc(str(ids[i]), gd,
				centro + Vector2((float(i) - (ids.size() - 1) * 0.5) * TILE * 1.5, 0))


func _crea_un_npc(id: String, gd: Node, posizione: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Npc_%s" % id
	area.set_meta("npc_id", id)
	area.position = posizione
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE) * 1.2
	shape.shape = rect
	area.add_child(shape)

	var npc_dati: Dictionary = gd.call("get_npc", id) if gd != null else {}
	var variante: int = int((npc_dati.get("aspetto", {}) as Dictionary).get("variante", 0))
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/placeholder/npc_popolano.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, variante * TILE, TILE, TILE)
	area.add_child(sprite)

	var nome := Label.new()
	nome.name = "Nome"
	nome.text = str(gd.call("tr_data", npc_dati.get("name_i18n", id))) if gd != null else id
	nome.add_theme_font_size_override("font_size", 10)
	nome.position = Vector2(-TILE, -TILE * 0.95)
	area.add_child(nome)

	# US-onboarding: prompt "[F] Parla" mentre il giocatore e' nel raggio, solo
	# per gli NPC che hanno davvero un dialogo. Nascosto finche' non ci si
	# avvicina.
	if not str(npc_dati.get("dialogue_id", "")).is_empty():
		var prompt := Label.new()
		prompt.name = "Prompt"
		prompt.add_theme_font_size_override("font_size", 10)
		prompt.position = Vector2(-TILE, TILE * 0.7)
		prompt.text = tr("HUD_PROMPT_INTERAGISCI").format({"tasto": _tasto_interagisci()})
		prompt.hide()
		area.add_child(prompt)

	area.body_entered.connect(_npc_avvicinato.bind(id))
	area.body_exited.connect(_npc_allontanato.bind(id))
	add_child(area)


func _npc_avvicinato(body: Node, id: String) -> void:
	if not body.is_in_group("player"):
		return
	var ns: Node = get_node_or_null("/root/NpcSystem")
	if ns != null:
		ns.call("incontra", id)
	_npc_vicino = id
	_mostra_prompt(id, true)


func _npc_allontanato(body: Node, id: String) -> void:
	if body.is_in_group("player") and _npc_vicino == id:
		_npc_vicino = ""
		_mostra_prompt(id, false)


func _mostra_prompt(id: String, visibile: bool) -> void:
	var p: Node = get_node_or_null("Npc_%s/Prompt" % id)
	if p != null:
		p.visible = visibile


## Il tasto legato a "interagisci" da mostrare nel prompt (rispetta i remap
## del colophon). "F" se l'azione non ha un tasto.
func _tasto_interagisci() -> String:
	for ev in InputMap.action_get_events("interagisci"):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "F"


## "interagisci" vicino a un NPC -> avvia il suo dialogo (nessun if per un NPC:
## dialogue_id viene dal roster). No-op se il libro e' gia' aperto o un dialogo
## e' in corso.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagisci") or _npc_vicino.is_empty():
		return
	var de: Node = get_node_or_null("/root/DialogueEngine")
	var book: Node = get_node_or_null("/root/Book")
	if de == null or bool(de.call("in_corso")) or (book != null and bool(book.call("e_aperto"))):
		return
	var gd: Node = get_node_or_null("/root/GameData")
	var did: String = str(gd.call("get_npc", _npc_vicino).get("dialogue_id", "")) if gd != null else ""
	if not did.is_empty() and de.call("avvia", did, _npc_vicino):
		get_viewport().set_input_as_handled()


func _su_ingresso_zona(body: Node, location_tag: String) -> void:
	if not body.is_in_group("player"):
		return
	if location_tag == _tag_corrente:
		return
	_tag_corrente = location_tag
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("imposta_zona", location_tag)
	zona_cambiata.emit(location_tag)


func _su_passaggio(body: Node, target: String) -> void:
	if _in_viaggio or not body.is_in_group("player"):
		return
	if not _ingresso_aperto(target):
		return  # la regione respinge (es. la Frontiera oltre la Sequenza 4)
	_in_viaggio = true
	_viaggia_verso.call_deferred(target)


## Un gating con area "ingresso" chiude la regione stessa (US-611): la
## convenzione e' nel dato, non un caso per una regione. Le altre aree di
## gating sono barriere interne (AreaGate in scena).
func _ingresso_aperto(target: String) -> bool:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return true
	for g in (gd.call("get_region", target).get("gating", []) as Array):
		if typeof(g) == TYPE_DICTIONARY and str((g as Dictionary).get("area", "")) == "ingresso":
			return AreaGate.valuta_gate(target, g, get_tree().root)
	return true


## US-617: fast travel dalla pagina mappa del libro. Come _su_passaggio ma
## senza l'Area2D di confine (il "mezzo" lo verifica la pagina). Rispetta
## comunque il gating d'ingresso. false se un viaggio e' gia' in corso o la
## regione respinge.
func viaggia_a(target: String) -> bool:
	if _in_viaggio or target == region_id or not _ingresso_aperto(target):
		return false
	if not ResourceLoader.exists("res://scenes/regioni/%s.tscn" % target):
		return false
	_in_viaggio = true
	_viaggia_verso.call_deferred(target)
	return true


## Sostituisce questa scena di regione con quella della destinazione. Il player
## e gli overlay vivono in main.tscn (fratelli): restano, la nuova regione li
## riposiziona nel suo _ready. Finche' il gating (US-611) non c'e', ogni
## passaggio e' aperto.
func _viaggia_verso(target: String) -> void:
	var scena_path: String = "res://scenes/regioni/%s.tscn" % target
	var padre: Node = get_parent()
	if padre == null or not ResourceLoader.exists(scena_path):
		_in_viaggio = false
		return
	var nuova: Node = load(scena_path).instantiate()
	padre.add_child(nuova)
	queue_free()


## Il location_tag della zona in cui si trova il giocatore ("" fuori da ogni
## zona nominata). Lo leggeranno il gating (US-611) e le condizioni
## in_zona_tag delle abilita' (US-605).
func tag_corrente() -> String:
	return _tag_corrente


## Gli id di regione raggiungibili da un passaggio di questa scena.
func passaggi_verso() -> Array:
	var out: Array = []
	for c in get_children():
		if c is Area2D and c.has_meta("target_region"):
			out.append(str(c.get_meta("target_region")))
	return out


func _colloca_giocatore() -> void:
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		return
	player.global_position = to_global(map_to_local(_spawn))
	var cam := player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("apply_zone_limits"):
		cam.call("apply_zone_limits", Rect2(global_position, Vector2(W * TILE, H * TILE)))


func _registra_regione() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null and not region_id.is_empty():
		ws.call("entra_regione", region_id)
