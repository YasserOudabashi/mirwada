extends VBoxContainer
## Pagina "dialogo" del libro (US-613b). Non si sfoglia: ci si finisce quando
## DialogueEngine.avvia() parte. Mostra il nome di chi parla, il testo del nodo
## corrente e un bottone per ogni scelta VALIDA (le altre non compaiono - la
## stessa logica di scelte_valide dell'engine). Il bottone chiama scegli(i).
##
## Si ridisegna a ogni nodo_cambiato. Nessun testo hardcoded: GameData.tr_data.

const C_SPEAKER := Color(0.45, 0.78, 0.82)

## US-811: npc_id del venditore mentre la pagina e' in modalita' negozio
## ("" = dialogo normale). Apribile da DialogueEngine.apri_vendita (una
## scelta di dialogo) O da QuestSystem.apri_vendita (ricompensa di quest
## completata) — due segnali distinti, entrambi reali (vedi dlg_sidon.json/
## q_sidon_01.json), non un doppione: la pagina ascolta entrambi.
var _negozio_npc_id: String = ""


func _ready() -> void:
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de != null:
		de.nodo_cambiato.connect(func(_n): aggiorna())
		de.dialogo_finito.connect(func(_id): aggiorna())
		de.apri_vendita.connect(_su_apri_vendita)
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs != null:
		qs.apri_vendita.connect(_su_apri_vendita)


func _su_apri_vendita(npc_id: String) -> void:
	_negozio_npc_id = npc_id
	aggiorna()


func aggiorna() -> void:
	for c in get_children():
		remove_child(c)   # subito fuori: get_children() non li conta piu' (queue_free e' differito)
		c.queue_free()

	if not _negozio_npc_id.is_empty():
		_disegna_negozio()
		return

	var de: Node = get_node_or_null("/root/DialogueEngine")
	var gd: Node = get_node_or_null("/root/GameData")
	if de == null or gd == null or not bool(de.call("in_corso")):
		add_child(_riga("· nessun dialogo in corso ·"))
		return

	var nodo: Dictionary = de.call("nodo_corrente")
	var chi: String = str(de.call("interlocutore"))
	if chi.is_empty():
		chi = str(nodo.get("speaker", ""))
	var npc: Dictionary = gd.call("get_npc", chi)
	var nome: String = str(gd.call("tr_data", npc.get("name_i18n", chi)))

	var l_nome := _riga(nome)
	l_nome.add_theme_color_override("font_color", C_SPEAKER)
	add_child(l_nome)
	add_child(_riga(str(gd.call("tr_data", nodo.get("text_i18n", "")))))

	var vuota := Control.new()
	vuota.custom_minimum_size = Vector2(0, 8)
	add_child(vuota)

	var valide: Array = de.call("scelte_valide")
	for i in valide.size():
		var b := Button.new()
		b.text = str(gd.call("tr_data", (valide[i] as Dictionary).get("text_i18n", "")))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func() -> void: de.call("scegli", i))
		add_child(b)


# --- modalita' negozio (US-811) ----------------------------------------
## Compra: un bottone per ogni item di npc.vendor.listino, attivo se si ha
## abbastanza valuta. Vendi: un bottone per ogni item posseduto (categoria
## != valuta) a meta' valore (arrotondato per difetto, minimo 1). valuta =
## items_per_categoria("valuta")[0].id: nessun id nel codice.

## Prezzo di un oggetto scalato per rarita' (US-1103, fase 11):
## valore * moltiplicatore_prezzo del suo livello - 'valore' nei dati resta
## sempre il prezzo BASE di un oggetto 'comune' (GameData.rarita_di torna
## 'comune' per default sugli oggetti che non dichiarano nulla).
func _prezzo_con_rarita(gd: Node, item_id: String) -> int:
	var base: int = int((gd.call("get_item", item_id) as Dictionary).get("valore", 0))
	var livello: Dictionary = gd.call("get_item_rarity", str(gd.call("rarita_di", item_id)))
	var mult: float = float(livello.get("moltiplicatore_prezzo", 1.0))
	return int(round(float(base) * mult))
func _disegna_negozio() -> void:
	var gd: Node = get_node_or_null("/root/GameData")
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null:
		add_child(_riga("· negozio non disponibile ·"))
		return

	var npc: Dictionary = gd.call("get_npc", _negozio_npc_id)
	var l_nome := _riga(str(gd.call("tr_data", npc.get("name_i18n", _negozio_npc_id))))
	l_nome.add_theme_color_override("font_color", C_SPEAKER)
	add_child(l_nome)
	add_child(_riga("%s: %d" % [tr("BOOK_NEGOZIO_MONETE"), int(inv.call("ricchezza"))]))

	var valuta_items: Array = gd.call("items_per_categoria", "valuta")
	if valuta_items.is_empty():
		add_child(_riga(tr("BOOK_NEGOZIO_VALUTA_ASSENTE")))
		_aggiungi_chiudi()
		return
	var valuta_id: String = str((valuta_items[0] as Dictionary).get("id", ""))

	var listino: Array = (npc.get("vendor", {}) as Dictionary).get("listino", [])
	for item_id in listino:
		var iid: String = str(item_id)
		var it: Dictionary = gd.call("get_item", iid)
		var valore: int = _prezzo_con_rarita(gd, iid)
		var h := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(200, 0)
		l.text = "%s — %d" % [str(gd.call("tr_data", it.get("name_i18n", iid))), valore]
		h.add_child(l)
		var b := Button.new()
		b.text = tr("BOOK_NEGOZIO_COMPRA")
		b.disabled = int(inv.call("conta", valuta_id)) < valore
		b.pressed.connect(func() -> void: compra(iid))
		h.add_child(b)
		add_child(h)

	for categoria in gd.call("item_categories"):
		if str(categoria) == "valuta":
			continue
		for riga in (inv.call("per_categoria", str(categoria)) as Array):
			var r: Dictionary = riga
			var iid2: String = str(r.get("item_id", ""))
			var it2: Dictionary = gd.call("get_item", iid2)
			var prezzo: int = maxi(1, _prezzo_con_rarita(gd, iid2) / 2)
			var h2 := HBoxContainer.new()
			var l2 := Label.new()
			l2.custom_minimum_size = Vector2(200, 0)
			l2.text = "%s  x%d" % [str(gd.call("tr_data", it2.get("name_i18n", iid2))), int(r.get("quantita", 0))]
			h2.add_child(l2)
			var b2 := Button.new()
			b2.text = "%s (%d)" % [tr("BOOK_NEGOZIO_VENDI"), prezzo]
			b2.pressed.connect(func() -> void: vendi(iid2))
			h2.add_child(b2)
			add_child(h2)

	_aggiungi_chiudi()


func _aggiungi_chiudi() -> void:
	var b := Button.new()
	b.text = tr("BOOK_NEGOZIO_CHIUDI")
	b.pressed.connect(_chiudi_negozio)
	add_child(b)


## Torna al dialogo in corso se ce n'e' uno (es. la vendita di una quest
## completata mentre si parlava d'altro); altrimenti chiude il libro (es.
## la vendita e' partita da una scelta che ha gia' terminato il dialogo).
func _chiudi_negozio() -> void:
	_negozio_npc_id = ""
	var de: Node = get_node_or_null("/root/DialogueEngine")
	if de != null and bool(de.call("in_corso")):
		aggiorna()
	else:
		var b: Node = get_node_or_null("/root/Book")
		if b != null:
			b.call("chiudi")


## Pubblica, interrogabile dai test (mirror del bottone Compra).
func compra(item_id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null:
		return {"ok": false, "reason": "no_inventory"}
	var valuta_items: Array = gd.call("items_per_categoria", "valuta")
	if valuta_items.is_empty():
		return {"ok": false, "reason": "no_valuta"}
	var valuta_id: String = str((valuta_items[0] as Dictionary).get("id", ""))
	var valore: int = _prezzo_con_rarita(gd, item_id)
	if int(inv.call("conta", valuta_id)) < valore:
		return {"ok": false, "reason": "fondi_insufficienti"}
	inv.call("rimuovi", valuta_id, valore)
	inv.call("aggiungi", item_id, 1)
	aggiorna()
	return {"ok": true}


## Pubblica, interrogabile dai test (mirror del bottone Vendi).
func vendi(item_id: String) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null:
		return {"ok": false, "reason": "no_inventory"}
	if int(inv.call("conta", item_id)) < 1:
		return {"ok": false, "reason": "non_posseduto"}
	var valuta_items: Array = gd.call("items_per_categoria", "valuta")
	if valuta_items.is_empty():
		return {"ok": false, "reason": "no_valuta"}
	var valuta_id: String = str((valuta_items[0] as Dictionary).get("id", ""))
	var prezzo: int = maxi(1, _prezzo_con_rarita(gd, item_id) / 2)
	inv.call("rimuovi", item_id, 1)
	inv.call("aggiungi", valuta_id, prezzo)
	aggiorna()
	return {"ok": true}


func in_negozio() -> bool:
	return not _negozio_npc_id.is_empty()


# --- Interrogabile dai test / verifica a schermo --------------------

func scelte_a_schermo() -> int:
	var n := 0
	for c in get_children():
		if c is Button:
			n += 1
	return n


func _riga(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
