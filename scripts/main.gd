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
## fase 10: il mondo e' continuo e non si ricarica mai; dal merge con l'arte
## il mondo di main.tscn e' quello generato, scripts/world/mondo.gd). Cosi'
## l'ingresso in una nuova partita — anche sopra una sessione gia' in corso
## nella stessa esecuzione — riparte pulito (player alla cella di spawn).
## NPC/nemici/oggetti restano quelli gia' in scena: sono dati statici della
## regione, nessuno stato di partita precedente li sporca.
##
## NIENTE class_name: coerente col resto del progetto.


func _ready() -> void:
	_al_punto_di_partenza()
	var book: Node = get_node_or_null("/root/Book")
	if book != null:
		book.call("apri")
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_signal("partita_iniziata"):
		gs.partita_iniziata.connect(_su_partita_iniziata)


func _su_partita_iniziata(_nome: String) -> void:
	_mondo_della_modalita()
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not bool(gs.get("da_salvataggio")):   # una partita caricata resta dove si era salvato
		_al_punto_di_partenza()


## Il mondo sceglie le sue immagini (luminoso | cupo) quando nasce, all'avvio, prima che si sappia la modalita'
## della partita: se la partita ne vuole un'altra il mondo si rifa' con quelle giuste, col giocatore dov'era.
func _mondo_della_modalita() -> void:
	var vecchio: Node = _trova_regione()
	var gs: Node = get_node_or_null("/root/GameState")
	if vecchio == null or gs == null or not vecchio.has_method("tema_caricato") \
			or str(vecchio.call("tema_caricato")) == str(gs.call("tema_arte")):
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	vecchio.call("esci")
	var stato: Array = [str(vecchio.get("livello")), vecchio.call("posizione_da_salvare"), vecchio.call("stato_barca"),
			bool(vecchio.call("in_volo"))]
	var indice: int = vecchio.get_index()
	var nome: String = vecchio.name
	var nuovo := Node2D.new()
	nuovo.set_script(vecchio.get_script())
	vecchio.remove_child(player)
	remove_child(vecchio)
	vecchio.free()        # subito, non queue_free: i suoi figli ascoltano ancora i segnali dei sistemi (orto, strutture)
	nuovo.name = nome
	nuovo.add_child(player)
	add_child(nuovo)
	move_child(nuovo, indice)
	nuovo.callv("riprendi", stato)


## Il giocatore al punto di partenza del mondo (mondo unico generato, US-8B12:
## la casa al porto di Mirwada). Il giocatore e' dentro il nodo mondo (y_sort),
## quindi si cerca nel gruppo "player"; colloca() porta anche la telecamera.
func _al_punto_di_partenza() -> void:
	var mondo: Node = _trova_regione()
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if mondo == null or player == null:
		return
	var pos: Vector2 = mondo.call("punto_spawn", "mirwada")
	if mondo.has_method("colloca"):
		mondo.call("colloca", player, pos)
	else:
		player.global_position = pos


## Il nodo mondo (mondo.gd o world_scene.gd) si riconosce dal suo contratto
## pubblico (viaggia_a), non dal nome del nodo.
func _trova_regione() -> Node:
	for c in get_children():
		if c.has_method("viaggia_a"):
			return c
	return null
