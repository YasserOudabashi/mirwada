extends "res://tests/test_case.gd"
## US-719 — eredita' al personaggio successivo (FR-14). EndingSystem compila
## endgame.eredita al finale (conoscenza sempre, reputazione se il profilo e'
## 'completo'; Ancora e oggetto sono una scelta esplicita del giocatore).
## GameState.nuova_partita() la applica quando lo slot che sta per riscrivere
## la porta gia'.

const SLOT := 902


func _root() -> Node: return Engine.get_main_loop().root
func _gs() -> Node: return _root().get_node("GameState")
func _es() -> Node: return _root().get_node("EndingSystem")
func _eg() -> Node: return _root().get_node("EndgameState")
func _prog() -> Node: return _root().get_node("Progression")
func _madness() -> Node: return _root().get_node("Madness")
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _anc() -> Node: return _root().get_node("AnchorSystem")
func _fs() -> Node: return _root().get_node("FactionSystem")
func _inv() -> Node: return _root().get_node("Inventory")
func _save() -> Node: return _root().get_node("SaveSystem")
func _book() -> Node: return _root().get_node("Book")


func _pulisci_slot() -> void:
	if bool(_save().call("esiste", SLOT)):
		_save().call("cancella", SLOT)


func _azzera_tutto() -> void:
	_madness().call("azzera")
	_ks().call("dimentica_tutto")
	_anc().call("pulisci")
	_fs().call("pulisci")
	_inv().call("pulisci")
	_eg().call("pulisci")
	if bool(_book().call("e_aperto")):
		_book().call("chiudi")
	# nuova_partita()/carica_slot() attivano GameState._partita_attiva senza
	# un modo pubblico per spegnerla: le altre suite (scaffale) si aspettano
	# lo stato di boot, come gia' fa test_creazione_talenti.gd.
	_gs().set("_partita_attiva", false)


func prepara() -> void:
	_pulisci_slot()
	_azzera_tutto()
	_prog().call("configura", "twilight_giant", 5)


func _fine() -> void:
	_pulisci_slot()
	_azzera_tutto()
	_prog().call("configura", "", 9)


func test_ciclo_completo_consumazione_con_eredita() -> void:
	# --- il personaggio che finisce ---
	_ks().call("impara", "pathway:darkness")
	_ks().call("impara", "sequenza:moon:5")
	_anc().call("register", "anchor_mirco")   # forza 10 (data/anchors.json)
	_anc().call("register", "anchor_sidon")   # 2 Ancore vive
	_fs().call("modifica", "giustizia", 4.0, "test")
	_fs().call("modifica", "porto", -2.0, "test")
	_inv().call("aggiungi", "moneta_comune", 3)

	_madness().call("add", 100.0, "test", false)   # madness_min 100 -> Consumazione
	assert_eq(str(_eg().call("get", "finale")), "consumazione", "finale raggiunto")

	var eredita: Dictionary = _eg().call("get", "eredita")
	assert_eq((eredita.get("conoscenza", []) as Array).size(), 2, "conoscenza compilata subito, sempre")
	assert_almost_eq(float((eredita.get("reputazione", {}) as Dictionary).get("giustizia", 0.0)), 2.0,
		"reputazione dimezzata (profilo completo)", 0.01)
	assert_almost_eq(float((eredita.get("reputazione", {}) as Dictionary).get("porto", 0.0)), -1.0,
		"reputazione dimezzata anche se negativa", 0.01)
	assert_false(eredita.has("ancora"), "l'Ancora e' una scelta: non ancora fatta")
	assert_false(eredita.has("oggetto"), "l'oggetto e' una scelta: non ancora fatta")

	assert_false(bool(_es().call("scegli_ancora", "anchor_promessa")), "non attiva adesso: rifiutata")
	assert_false(bool(_es().call("scegli_oggetto", "oggetto_inesistente")), "non posseduto: rifiutato")
	assert_true(bool(_es().call("scegli_ancora", "anchor_mirco")), "un'Ancora attiva: accettata")
	assert_true(bool(_es().call("scegli_oggetto", "moneta_comune")), "un oggetto posseduto: accettato")

	eredita = _eg().call("get", "eredita")
	assert_almost_eq(float((eredita["ancora"] as Dictionary).get("forza", -1.0)), 5.0,
		"forza dimezzata: 10/2", 0.01)
	assert_eq(str(eredita.get("oggetto")), "moneta_comune", "l'oggetto scelto e' nel contratto")

	var salvato: Dictionary = _gs().call("salva_slot", SLOT)
	assert_true(bool(salvato.get("ok")), "lo slot con finale + eredita' e' salvato")

	# --- il nuovo personaggio, stessa sessione, stesso slot ---
	var res: Dictionary = _gs().call("nuova_partita", "Erede", SLOT, [])
	assert_true(bool(res.get("ok")), "nuova partita creata sullo stesso slot")

	assert_eq(int(_prog().call("sequence")), 9, "Sequenza di nuovo a 9")
	assert_almost_eq(float(_madness().call("valore")), 0.0, "follia azzerata", 0.01)
	assert_true(bool(_ks().call("conosce", "pathway:darkness")), "conoscenza seminata")
	assert_true(bool(_ks().call("conosce", "sequenza:moon:5")), "conoscenza seminata")
	assert_eq((_anc().call("active") as Array), ["anchor_mirco"], "1 sola Ancora ereditata")
	assert_almost_eq(float(_anc().call("forza_di", "anchor_mirco")), 5.0, "resta a forza dimezzata", 0.01)
	assert_almost_eq(float(_fs().call("reputazione", "giustizia")), 2.0, "reputazione a meta'", 0.01)
	assert_almost_eq(float(_fs().call("reputazione", "porto")), -1.0, "reputazione a meta'", 0.01)
	assert_true(bool(_inv().call("possiede", "moneta_comune", 1)), "oggetto ereditato nello zaino")
	assert_eq(str(_eg().call("get", "finale")), "", "il nuovo personaggio non ha (ancora) un finale")
	assert_eq((_eg().call("get", "eredita") as Dictionary).size(), 0, "endgame azzerato per il nuovo personaggio")

	_fine()


func test_slot_vuoto_nessuna_eredita_applicata() -> void:
	_pulisci_slot()
	var res: Dictionary = _gs().call("nuova_partita", "Primo", SLOT, [])
	assert_true(bool(res.get("ok")), "nuova partita su uno slot vuoto")
	assert_eq((_ks().call("tutti") as Array).size(), 0, "nessuna conoscenza da ereditare")
	assert_eq((_anc().call("active") as Array).size(), 0, "nessuna Ancora da ereditare")
	_fine()


func test_eredita_id_ignoti_scartati_non_fidato() -> void:
	# FR-13: id ignoti scartati, mai un crash o un dato inventato.
	_eg().call("imposta_finale", "consumazione")
	_eg().call("imposta_eredita", {
		"conoscenza": ["pathway:darkness", 42, ""],
		"ancora": {"id": "ancora_che_non_esiste", "forza": 999.0},
		"reputazione": {"giustizia": 2.0, "fazione_fantasma": 1.0},
		"oggetto": "oggetto_che_non_esiste",
	})
	var salvato: Dictionary = _gs().call("salva_slot", SLOT)
	assert_true(bool(salvato.get("ok")), "slot con eredita' malformata salvato comunque")
	_azzera_tutto()

	var res: Dictionary = _gs().call("nuova_partita", "Erede2", SLOT, [])
	assert_true(bool(res.get("ok")), "nuova partita creata")
	assert_true(bool(_ks().call("conosce", "pathway:darkness")), "il flag valido entra")
	assert_eq((_ks().call("tutti") as Array).size(), 1, "gli id non-stringa/vuoti sono scartati")
	assert_eq((_anc().call("active") as Array).size(), 0, "un'Ancora inesistente non si registra")
	assert_false(bool(_inv().call("possiede", "oggetto_che_non_esiste", 1)), "oggetto inesistente non aggiunto")
	# la reputazione non e' filtrata per fazione esistente (FactionSystem.da_salvataggio
	# accetta qualunque chiave stringa/numero: la fazione ignota resta innocua, mai letta)
	assert_almost_eq(float(_fs().call("reputazione", "giustizia")), 2.0, "reputazione valida applicata", 0.01)

	_fine()
