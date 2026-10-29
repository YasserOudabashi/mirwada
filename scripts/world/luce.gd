extends CanvasModulate
## US-8B25: la luce del mondo (data/world/luce.json). Figlia del mondo: moltiplica tutto cio' che sta nel mondo col
## colore del momento del giorno e della modalita' (luminosa o cupa); sotto terra la luce fissa del sottosuolo. Passa da
## un colore all'altro piano. Quando si entra in un interno il mondo si nasconde e con lui questa luce: gli interni
## restano come sono. HUD, libro e lucciole stanno su strati loro e non si scuriscono.
##
## NIENTE class_name: coerente col progetto.

var _mondo: Node


func _ready() -> void:
	name = "Luce"
	if _mondo == null:
		_mondo = get_parent()
	color = colore_voluto()


func _process(delta: float) -> void:
	var t: float = maxf(float(_dati().get("transizione", 3.0)), 0.01)
	color = color.lerp(colore_voluto(), clampf(delta * 3.0 / t, 0.0, 1.0))


## Il colore che la luce vuole adesso: quello del sottosuolo, o quello del momento nella modalita' della partita.
func colore_voluto() -> Color:
	var d: Dictionary = _dati()
	if _mondo != null and str(_mondo.get("livello")) == "sottosuolo":
		return Color(str(d.get("sottosuolo", "#ffffff")))
	var gs: Node = _auto("GameState")
	var tema: String = str(gs.call("tema_arte")) if gs != null else "luminoso"
	var ts: Node = _auto("TimeSystem")
	var momento: String = str(ts.call("momento")) if ts != null else ""
	var per_tema: Dictionary = (d.get("momenti", {}) as Dictionary).get(tema, {})
	return Color(str(per_tema.get(momento, "#ffffff")))


func _dati() -> Dictionary:
	var gd: Node = _auto("GameData")
	return gd.call("get_luce") if gd != null else {}


func _auto(nome: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(nome)
