extends Node
## US-8B23b: fauna d'atmosfera (data/world/fauna.json, disegni di tools/art/build_fauna.py). Figlio del mondo: quando il
## mondo costruisce un blocco di superficie, per ogni specie della regione e del momento del giorno si tira se metterci
## un gruppo; il gruppo se ne va quando il blocco si scarica. Il seme e' la posizione del blocco: tornando, gli stessi
## animali negli stessi posti. Chi si avvicina li fa scappare: "vola" si alzano e vanno via verso nord svanendo,
## "corre" scappano a terra (girano davanti a muri e acqua), "resta" ondeggiano sul posto. Niente collisioni, niente
## combattimento: sono AnimationMachine figli del mondo (ordinati per profondita' col giocatore).
##
## NIENTE class_name: coerente col progetto.

const AnimationMachine := preload("res://scripts/animation_machine.gd")
const ENTRATA := 0.6                          # secondi per comparire (un blocco nuovo, un momento nuovo)

var _mondo: Node2D
var _animali: Dictionary = {}                 # Vector2i blocco -> Array di AnimatedSprite2D
var _tempo := 0.0


func _ready() -> void:
	if _mondo == null:
		_mondo = get_parent()
	_mondo.connect("blocco_costruito", popola)
	_mondo.connect("blocco_scaricato", togli)
	var ts: Node = _auto("TimeSystem")
	if ts != null and ts.has_signal("momento_cambiato"):
		ts.momento_cambiato.connect(_su_momento)
	for b in (_mondo.get("_caricati") as Dictionary).keys():
		popola(b)


## Gli animali di un blocco di superficie al momento del giorno ("" = quello del TimeSystem); solo: se non vuoto,
## solo quelle specie (un momento del giorno nuovo).
func popola(b: Vector2i, solo: Array = [], momento: String = "") -> void:
	var gd: Node = _auto("GameData")
	if gd == null or str(_mondo.get("livello")) != "superficie":
		return
	var specie: Dictionary = gd.call("get_fauna")
	if momento.is_empty():
		momento = _momento()
	var lato: int = int(_mondo.get_script().get_script_constant_map().get("BLOCCO", 16))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b)
	var lista: Array = _animali.get(b, [])
	var nomi: Array = specie.keys()
	nomi.sort()
	for nome in nomi:
		var s: Dictionary = specie[nome]
		var esce: bool = rng.randf() < float(s.get("probabilita", 0))         # si tira sempre: seme stabile
		var c := Vector2i(b.x * lato + rng.randi_range(2, lato - 3), b.y * lato + rng.randi_range(2, lato - 3))
		var gruppo: Array = s.get("gruppo", [1, 1])
		var quanti: int = rng.randi_range(int(gruppo[0]), int(gruppo[1]))
		var posti: Array = []
		for _k in quanti:
			posti.append(c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2)))
		if not esce or (not solo.is_empty() and nome not in solo) or momento not in (s.get("momenti", []) as Array):
			continue
		for q in posti:
			if _mondo.call("bloccata", q.x, q.y) or _mondo.call("_in_una_casa", q.x, q.y) \
					or str(_mondo.call("regione_a", q.x, q.y)) not in (s.get("regioni", []) as Array):
				continue
			var a: AnimatedSprite2D = _crea(nome, s, q, rng)
			if _coperto(a.position + Vector2(0, -8)):          # sotto una chioma non si vedrebbe: niente
				a.free()
				continue
			lista.append(a)
	_animali[b] = lista


func togli(b: Vector2i) -> void:
	for a in _animali.get(b, []):
		if is_instance_valid(a):
			(a as Node).queue_free()
	_animali.erase(b)


func animali() -> Array:
	var out: Array = []
	for lista in _animali.values():
		out.append_array((lista as Array).filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion()))
	return out


func _crea(nome: String, s: Dictionary, q: Vector2i, rng: RandomNumberGenerator) -> AnimatedSprite2D:
	var a: AnimatedSprite2D = AnimationMachine.new()
	a.name = "Fauna_%s" % nome
	# US-8B25: una luce sta sopra il buio della notte (uno strato suo, che segue la telecamera), le altre nel mondo
	(_strato_luci() if bool(s.get("luce", false)) else _mondo).add_child(a)
	a.call("configura", "fauna", nome)
	var tile: float = float(_mondo.get("tile"))
	a.position = Vector2((q.x + rng.randf()) * tile, (q.y + rng.randf()) * tile)
	# a riposo di profilo: di fronte o di spalle un animale e' una sagoma stretta
	a.call("riproduci", "idle", ("left" if rng.randi() % 2 == 0 else "right") if bool(s.get("gira", true)) else "down")
	a.frame = rng.randi() % maxi(a.sprite_frames.get_frame_count(a.animation), 1)   # un gruppo non batte all'unisono
	if bool(s.get("luce", false)):                         # una luce: si somma a cio' che ha sotto
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		a.material = mat
	a.modulate.a = 0.0
	a.set_meta("specie", nome)
	a.set_meta("fuga", Vector2.ZERO)
	a.set_meta("base", a.position)
	a.set_meta("fase", rng.randf() * TAU)
	return a


var _luci: CanvasLayer = null


## Lo strato delle luci (le lucciole): fuori dal mondo, quindi la luce del mondo (scripts/world/luce.gd) non lo
## scurisce; si vede solo quando si vede il mondo (non dentro un interno).
func _strato_luci() -> CanvasLayer:
	if _luci == null:
		_luci = CanvasLayer.new()
		_luci.name = "Luci"
		_luci.follow_viewport_enabled = true
		add_child(_luci)
		if _mondo is CanvasItem:
			(_mondo as CanvasItem).visibility_changed.connect(func() -> void:
				if is_instance_valid(_luci):
					_luci.visible = (_mondo as CanvasItem).is_visible_in_tree())
	return _luci


func _process(delta: float) -> void:
	_tempo += delta
	var gd: Node = _auto("GameData")
	if gd == null:
		return
	var specie: Dictionary = gd.call("get_fauna")
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	var tile: float = float(_mondo.get("tile"))
	for a in animali():
		var s: Dictionary = specie.get(str(a.get_meta("specie")), {})
		var v: Vector2 = a.get_meta("fuga")
		if v == Vector2.ZERO:
			a.modulate.a = minf(1.0, a.modulate.a + delta / ENTRATA)
			var fugge: String = str(s.get("fugge", "resta"))
			if fugge == "resta":
				var f: float = float(a.get_meta("fase"))
				a.position = (a.get_meta("base") as Vector2) + Vector2(sin(_tempo * 0.7 + f) * 6.0, cos(_tempo * 0.5 + f) * 4.0)
			elif p != null and a.position.distance_to(p.position) < float(s.get("raggio_fuga", 0)) * tile:
				scappa(a, s, p.position)
			continue
		var nuova: Vector2 = a.position + v * delta
		if str(s.get("fugge", "")) == "corre" and _muro(nuova):
			v = _gira(a.position, v)
			a.set_meta("fuga", v)
			_guarda(a, s, v)
			nuova = a.position + v * delta
		a.position = nuova
		a.modulate.a -= delta / maxf(float(s.get("svanisce", 1.0)), 0.1)
		if a.modulate.a <= 0.0:
			a.queue_free()


## Comincia la fuga lontano da chi arriva: chi vola sale anche verso nord (in alto sullo schermo).
func scappa(a: AnimatedSprite2D, s: Dictionary, da: Vector2) -> void:
	var via: Vector2 = (a.position - da).normalized()
	if via == Vector2.ZERO:
		via = Vector2.UP
	if str(s.get("fugge", "")) == "vola":
		via = (via + Vector2(0, -1.2)).normalized()
	var v: Vector2 = via * float(s.get("velocita", 100))
	a.set_meta("fuga", v)
	_guarda(a, s, v)


func _guarda(a: AnimatedSprite2D, s: Dictionary, v: Vector2) -> void:
	var dir: String = "down"
	if bool(s.get("gira", true)):
		dir = ("right" if v.x > 0 else "left") if absf(v.x) > absf(v.y) else ("down" if v.y > 0 else "up")
	a.call("riproduci", "fuga", dir)


func _muro(pos: Vector2) -> bool:
	var tile: float = float(_mondo.get("tile"))
	return bool(_mondo.call("bloccata", floori(pos.x / tile), floori(pos.y / tile)))


## Davanti a un muro: prova a girare di 90 gradi da una parte o dall'altra, se no torna indietro.
func _gira(da: Vector2, v: Vector2) -> Vector2:
	for w in [v.orthogonal(), -v.orthogonal()]:
		if not _muro(da + (w as Vector2).normalized() * float(_mondo.get("tile"))):
			return w
	return -v


## Un punto coperto da un oggetto di scena che gli sta davanti (un albero piu' a sud, con la chioma sopra il punto):
## il disegno dell'oggetto non e' trasparente li'.
func _coperto(punto: Vector2) -> bool:
	var tile: float = float(_mondo.get("tile"))
	var lato: int = int(_mondo.get_script().get_script_constant_map().get("BLOCCO", 16))
	var meta: Dictionary = (_mondo.get("dati") as Dictionary).get("sprite", {})
	var per_blocco: Dictionary = _mondo.get("_oggetti_per_blocco")
	var c := Vector2i(floori(punto.x / tile / lato), floori(punto.y / tile / lato))
	for dy in range(0, 2):                                  # chi copre sta allo stesso blocco o a quello sotto
		for dx in range(-1, 2):
			for o in per_blocco.get(c + Vector2i(dx, dy), []):
				var base := Vector2(float(o[1]) * tile, float(o[2]) * tile)
				if base.y <= punto.y:
					continue
				var img: Image = _immagine(str(o[0]))
				var m: Dictionary = meta.get(str(o[0]), {})
				var t: Vector2i = Vector2i(punto - base + Vector2(float(m.get("ax", 0)), float(m.get("ay", 0))))
				if img != null and t.x >= 0 and t.y >= 0 and t.x < img.get_width() and t.y < img.get_height() \
						and img.get_pixel(t.x, t.y).a > 0.5:
					return true
	return false


var _immagini: Dictionary = {}


func _immagine(chiave: String) -> Image:
	if not _immagini.has(chiave):
		var tex: Texture2D = _mondo.call("_texture_oggetto", chiave)
		_immagini[chiave] = tex.get_image() if tex != null else null
	return _immagini[chiave]


func _momento() -> String:
	var ts: Node = _auto("TimeSystem")
	return str(ts.call("momento")) if ts != null else ""


## Un momento del giorno nuovo: chi non e' di questo momento svanisce (sale piano), chi lo e' e non c'era arriva.
func _su_momento(m: String) -> void:
	var gd: Node = _auto("GameData")
	var specie: Dictionary = gd.call("get_fauna") if gd != null else {}
	var presenti: Dictionary = {}
	for a in animali():
		var s: Dictionary = specie.get(str(a.get_meta("specie")), {})
		if m in (s.get("momenti", []) as Array):
			presenti[a.get_meta("specie")] = true
		elif a.get_meta("fuga") == Vector2.ZERO:
			a.set_meta("fuga", Vector2(0, -12))
	var nuove: Array = specie.keys().filter(func(k): return not presenti.has(k) and m in (specie[k].get("momenti", []) as Array))
	if nuove.is_empty():
		return
	for b in _animali.keys():
		popola(b, nuove, m)


## Un autoload anche da fuori dell'albero (i test popolano un mondo che non e' nella scena).
func _auto(nome: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(nome)
