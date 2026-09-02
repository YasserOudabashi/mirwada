extends SceneTree
## One-shot: costruisce assets/placeholder/tileset.tres da tileset.png.
##
##   godot --headless --path . --script res://tools/build_tileset.gd
##
## tileset.png e' generato da tools/generate_placeholders.py: 4 tile in fila
## da 32x32 — 0 pavimento, 1 muro, 2 ostacolo, 3 acqua. Muro e ostacolo
## ricevono un poligono di collisione a tile pieno; pavimento e acqua no
## (l'acqua sara' un'altra cosa piu' avanti). L'output e' committato: il
## motore non lo rigenera.

const SRC_PNG := "res://assets/placeholder/tileset.png"
const OUT_TRES := "res://assets/placeholder/tileset.tres"
const TILE := 32

# Coordinate atlas che collidono (muro, ostacolo).
const SOLIDI: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]


func _init() -> void:
	var tex: Texture2D = load(SRC_PNG)
	if tex == null:
		push_error("manca " + SRC_PNG + " — esegui prima generate_placeholders.py")
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

	var n: int = int(tex.get_width() / TILE)
	for i in n:
		src.create_tile(Vector2i(i, 0))

	var h := float(TILE) / 2.0
	var quad := PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])
	for coord in SOLIDI:
		var data: TileData = src.get_tile_data(coord, 0)
		data.set_collision_polygons_count(0, 1)
		data.set_collision_polygon_points(0, 0, quad)

	var err := ResourceSaver.save(ts, OUT_TRES)
	print("salvato %s -> %s (err %d), %d tile, %d solidi" % [
		OUT_TRES, "ok" if err == OK else "FAIL", err, n, SOLIDI.size(),
	])
	quit(0 if err == OK else 1)
