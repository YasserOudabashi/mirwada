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
## Su GameState.partita_iniziata riposiziona il giocatore a Mirwada (US-1002B,
## fase 10: il mondo e' continuo, world_scene.gd non si ricarica mai). Cosi'
## l'ingresso in una nuova partita — anche sopra una sessione gia' in corso
## nella stessa esecuzione — riparte pulito (player alla cella di spawn).
## NPC/nemici/oggetti restano quelli gia' in scena: sono dati statici della
## regione, nessuno stato di partita precedente li sporca.
##
## NIENTE class_name: coerente col resto del progetto.


func _ready() -> void:
	var mondo: Node = _trova_regione()
	var player: Node = get_node_or_null("Player")
	if mondo != null and player != null:
		player.global_position = mondo.call("punto_spawn", "mirwada")
	var book: Node = get_node_or_null("/root/Book")
	if book != null:
		book.call("apri")
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_signal("partita_iniziata"):
		gs.partita_iniziata.connect(_su_partita_iniziata)


func _su_partita_iniziata(_nome: String) -> void:
	var mondo: Node = _trova_regione()
	if mondo != null:
		mondo.call("viaggia_a", "mirwada")


## Il nodo mondo e' l'unico figlio con lo script di world_scene.gd: lo
## riconosco dal suo contratto pubblico (viaggia_a), non dal nome del nodo.
func _trova_regione() -> Node:
	for c in get_children():
		if c.has_method("viaggia_a"):
			return c
	return null
