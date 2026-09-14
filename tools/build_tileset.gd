extends SceneTree
## One-shot: costruisce assets/placeholder/tileset.tres da tileset.png.
##
##   godot --headless --path . --script res://tools/build_tileset.gd
##
## tileset.png e' generato da tools/generate_sprites.py (US-813): 8 colonne
## (pavimento, muro, ostacolo, acqua, pavimento variante, sentiero,
## ostacolo2, decoro — l'ordine deciso dall'AC, diverso da quello della
## legenda di layout.schema.json) x N righe (riga 0 neutra, poi una riga
## per ogni chiave di data/vfx.json.pathway_palette_visiva, nel loro
## ordine). Le colonne solide sono [1,2,3,6] (muro/ostacolo/acqua/
## ostacolo2) e ricevono un poligono di collisione a tile pieno, su OGNI
## riga (non solo la 0): region_scene.gd sceglie la riga in base alla
## palette_visiva della regione. L'output e' committato: il motore non lo
## rigenera.

const SRC_PNG := "res://assets/placeholder/tileset.png"
const OUT_TRES := "res://assets/placeholder/tileset.tres"
const TILE := 32
const COLONNE := 8

# Indici di colonna che collidono su ogni riga (muro, ostacolo, acqua,
# ostacolo2 — stesso ordine di generate_sprites.py.TILESET_COLONNE).
const COLONNE_SOLIDE: Array[int] = [1, 2, 3, 6]


func _init() -> void:
	var tex: Texture2D = load(SRC_PNG)
	if tex == null:
		push_error("manca " + SRC_PNG + " — esegui prima generate_sprites.py")
		quit(1)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)

	var righe: int = int(tex.get_height() / TILE)
	for r in righe:
		for c in COLONNE:
			src.create_tile(Vector2i(c, r))

	var h := float(TILE) / 2.0
	var quad := PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])
	var n_solidi := 0
	for r in righe:
		for c in COLONNE_SOLIDE:
			var data: TileData = src.get_tile_data(Vector2i(c, r), 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, quad)
			n_solidi += 1

	var err := ResourceSaver.save(ts, OUT_TRES)
	print("salvato %s -> %s (err %d), %d righe x %d colonne, %d tile solidi" % [
		OUT_TRES, "ok" if err == OK else "FAIL", err, righe, COLONNE, n_solidi,
	])
	quit(0 if err == OK else 1)
