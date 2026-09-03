extends VBoxContainer
## Pagina "scaffale" (US-223): gli slot di SaveSystem come tomi. Tomo vuoto =
## nuova partita (porta al frontespizio). Tomo valido = carica. Tomo corrotto
## (US-015 stato CORROTTO) = "bruciato": mostrato, non caricabile, mai
## cancellato in automatico.
##
## Nessun testo hardcoded: tutto da GameData.tr_data().

func aggiorna() -> void:
	for c in get_children():
		c.queue_free()

	var ss: Node = _n("/root/SaveSystem")
	var gs: Node = _n("/root/GameState")
	var book: Node = _n("/root/Book")
	if ss == null or book == null:
		return

	var n_slot: int = int(book.call("config", "slot", 4))
	for slot in n_slot:
		var info: Dictionary = ss.call("anteprima", slot)
		var stato: int = int(info.get("stato", 0))
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 26)

		match stato:
			2:  # SaveSystem.Slot.CORROTTO
				b.text = tr("BOOK_SCAFFALE_TOMO_BRUCIATO")
				b.disabled = true
			1:  # VALIDO
				b.text = "%s  —  %s" % [
					str(info.get("nome_personaggio", "?")),
					_durata(float(info.get("tempo_gioco", 0.0))),
				]
				b.pressed.connect(_carica.bind(slot))
			_:  # VUOTO
				b.text = tr("BOOK_SCAFFALE_TOMO_NUOVO")
				b.pressed.connect(_nuovo.bind(slot))
		add_child(b)

	if gs != null and bool(gs.call("partita_in_corso")):
		var chiudi := Button.new()
		chiudi.text = tr("BOOK_SCAFFALE_RIPRENDI")
		chiudi.pressed.connect(func() -> void: book.call("chiudi"))
		add_child(chiudi)


func _carica(slot: int) -> void:
	var gs: Node = _n("/root/GameState")
	var book: Node = _n("/root/Book")
	if gs == null:
		return
	var r: Dictionary = gs.call("carica_slot", slot)
	if r.get("ok", false) and book != null:
		book.call("chiudi")
	else:
		aggiorna()  # errore gestito: lo slot resta, il libro no-op


func _nuovo(slot: int) -> void:
	var gs: Node = _n("/root/GameState")
	var book: Node = _n("/root/Book")
	if gs != null:
		gs.call("scegli_slot", slot)
	if book != null:
		book.call("vai_a", "frontespizio")


func _durata(secondi: float) -> String:
	var m: int = int(secondi) / 60
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%dm" % m


func _n(path: String) -> Node:
	return get_node_or_null(path)
