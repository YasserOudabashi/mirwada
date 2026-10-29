extends VBoxContainer
## US-8B73b/c: una pagina del libro con la sua facciata destra. Il libro (book_overlay.gd) mette `destra` sulla
## pagina di destra prima che la pagina entri nell'albero; da sola, ad esempio nei test, resta in fondo a questa.
##
## NIENTE class_name: le pagine la estendono per percorso, come il resto del progetto.

var destra := VBoxContainer.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:                   # vale anche per le pagine che hanno il loro _ready
		destra.name = "Destra"
		destra.alignment = alignment                  # le due facciate allineate allo stesso modo
		destra.add_theme_constant_override("separation", get_theme_constant("separation"))
		if destra.get_parent() == null:
			add_child(destra)


## Un bottone che va a capo. Godot 4.3 calcola l'altezza del testo a capo con la larghezza che il bottone ha quando
## nasce e non la rifa' quando la facciata lo allarga: senza questo, arrivando voltando pagina, resta alto come una
## colonna di lettere (si vede solo a schermo, non nei test headless).
static func a_capo(b: Button) -> void:
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.resized.connect(func() -> void:
		if b.has_meta("largo") and is_equal_approx(float(b.get_meta("largo")), b.size.x):
			return
		b.set_meta("largo", b.size.x)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF       # rifa' l'impaginazione del testo con la larghezza vera
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART)


## Toglie subito (non solo in coda) tutto quello che la pagina aveva scritto, sulle due facciate.
func svuota() -> void:
	for madre in [self, destra]:
		for c in madre.get_children():
			if c == destra:
				continue
			madre.remove_child(c)
			c.queue_free()
