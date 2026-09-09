extends Node2D
## Vero entry point del gioco (US-801). Fino a questa story, main.tscn non
## avviava mai una partita: il libro restava chiuso e GameState.
## partita_attiva era false all'avvio.
##
## In _ready() apre il libro sullo scaffale (Book.apri(): con nessun'altra
## pagina "ultima" visitata si apre su 'copertina' = ordine piu' basso, il
## menu principale). Il giocatore crea un personaggio (scelta del Pathway
## in page_creazione_personaggio.gd) o carica uno slot esattamente come nel
## gioco finito.
##
## Su GameState.partita_iniziata ricostruisce la regione corrente: stesso
## meccanismo di region_scene.gd::_viaggia_verso (ricarica la stessa scena,
## il vecchio nodo si libera). Cosi' l'ingresso in una nuova partita — anche
## sopra una sessione gia' in corso nella stessa esecuzione — riparte pulito
## (player alla cella di spawn, NPC ricostruiti). Nessun id di regione
## hardcoded: si riusa lo scene_file_path del nodo regione gia' in scena.
##
## NIENTE class_name: coerente col resto del progetto.


func _ready() -> void:
	var book: Node = get_node_or_null("/root/Book")
	if book != null:
		book.call("apri")
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_signal("partita_iniziata"):
		gs.partita_iniziata.connect(_su_partita_iniziata)


func _su_partita_iniziata(_nome: String) -> void:
	var regione: Node = _trova_regione()
	if regione == null:
		return
	var percorso: String = regione.scene_file_path
	if percorso.is_empty() or not ResourceLoader.exists(percorso):
		return
	var nuova: Node = load(percorso).instantiate()
	add_child(nuova)
	regione.queue_free()


## Il nodo regione e' l'unico figlio la cui radice e' uno script di
## region_scene.gd: lo riconosco dal suo contratto pubblico (viaggia_a),
## non dal nome del nodo o dall'id della regione.
func _trova_regione() -> Node:
	for c in get_children():
		if c.has_method("viaggia_a"):
			return c
	return null
