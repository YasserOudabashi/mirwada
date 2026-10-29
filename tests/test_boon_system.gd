extends "res://tests/test_case.gd"
## US-902 — BoonSystem: il motore generico dei Pathway Non-Standard. Un
## Pathway di prova ("fixture_boon_test"), non Eternal Aeon (che arriva in
## US-904) — stesso principio di test_vertical_slice.gd col Twilight Giant
## per la fase 2.
##
## Niente file su data/pathways_non_standard/: le Sequenze di prova sono
## iniettate direttamente in GameData._sequences (stesso pattern di
## test_hot_reload.gd::test_id_rimosso_dai_dati_sparisce_dopo_reload), cosi'
## non compaiono mai in GameData.pathway_ids() ne' influenzano i conteggi
## globali (sequence_count, i18n, VFX, ...) controllati da altre suite. Ogni
## test chiama GameData.reload() come ultima riga: reload() POTA dai dati in
## memoria tutto cio' che non e' iniettato da un file reale (stesso motivo
## per cui quel test di hot reload esiste), quindi la Sequenza di prova non
## sopravvive oltre il singolo test.

const PATHWAY := "fixture_boon_test"
const SLOT := 922


func _gd() -> Node:
	return Engine.get_main_loop().root.get_node("GameData")


func _boon() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("BoonSystem")


func _prog() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Progression")


func _et() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventTracker")


func _quest() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("QuestSystem")


func _inv() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _car() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("CharacteristicStore")


func _madness() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Madness")


func _sequenze_di_prova() -> Dictionary:
	return {
		# Mista: un requisito per tipo (quest, comportamento, sacrificio).
		"fixture_boon_test_9": {"id": "fixture_boon_test_9", "sequence": 9, "boon": {
			"requisiti": [
				{"tipo": "quest", "quest_id": "q_mirco_01"},
				{"tipo": "comportamento", "evento": "enemy_defeated", "filtri": {}, "target": 3},
				{"tipo": "sacrificio", "costo": {"tipo": "oggetto", "id": "ferro_temperato", "quantita": 2}},
			]
		}},
		"fixture_boon_test_8": {"id": "fixture_boon_test_8", "sequence": 8, "boon": {
			"requisiti": [{"tipo": "comportamento", "evento": "enemy_defeated", "filtri": {}, "target": 2}]
		}},
		"fixture_boon_test_7": {"id": "fixture_boon_test_7", "sequence": 7, "boon": {
			"requisiti": [{"tipo": "sacrificio", "costo": {"tipo": "caratteristica", "id": "char_twilight_giant_9", "quantita": 1}}]
		}},
		"fixture_boon_test_6": {"id": "fixture_boon_test_6", "sequence": 6, "boon": {
			"requisiti": [{"tipo": "sacrificio", "costo": {"tipo": "follia", "quantita": 10}}]
		}},
		"fixture_boon_test_5": {"id": "fixture_boon_test_5", "sequence": 5, "boon": {
			"requisiti": [{"tipo": "quest", "quest_id": "q_sidon_01"}]
		}},
		# Nessun 'boon': equivalente a una Sequenza stub (mai pronta).
		"fixture_boon_test_4": {"id": "fixture_boon_test_4", "sequence": 4},
	}


func _inietta() -> void:
	var seqs: Dictionary = _gd().get("_sequences")
	for sid in _sequenze_di_prova():
		seqs[sid] = _sequenze_di_prova()[sid]


## Toglie dalla memoria di GameData tutto cio' che non e' un file reale su
## disco (compresa la nostra iniezione) e ricarica i dati veri.
func _pulisci_dati() -> void:
	_gd().call("reload")


func prepara() -> void:
	_inietta()
	_et().call("azzera")
	_quest().call("pulisci")
	_inv().call("pulisci")
	_car().call("pulisci")
	_madness().call("azzera")
	_vai_a(9)


func _vai_a(sequenza: int) -> void:
	_prog().configura(PATHWAY, sequenza)   # non emette sequence_changed
	_boon().call("_riparti")               # stesso motivo di Acting._riparti in prepara()


func _completa_quest(quest_id: String) -> void:
	(_quest().get("_completate") as Array).append(quest_id)


# --- Requisito 'quest' (Sequenza 5: un solo requisito) ---------------------

func test_requisito_quest_non_soddisfatto_di_default() -> void:
	_vai_a(5)
	assert_false(_boon().call("puo_ricevere"), "nessuna quest completata")
	var stato: Array = _boon().call("requisiti_stato")
	assert_eq(stato.size(), 1, "un solo requisito dichiarato")
	assert_false(bool(stato[0]["soddisfatto"]), "requisito quest non soddisfatto")
	_pulisci_dati()


func test_requisito_quest_soddisfatto_dopo_completamento() -> void:
	_vai_a(5)
	_completa_quest("q_sidon_01")
	assert_true(_boon().call("puo_ricevere"), "quest completata -> Boon ricevibile")
	_pulisci_dati()


func test_ricevi_boon_quest_avanza_la_sequenza() -> void:
	_vai_a(5)
	_completa_quest("q_sidon_01")
	var r: Dictionary = _boon().call("ricevi_boon")
	assert_true(bool(r["ok"]), "ricevi_boon ok")
	assert_true(bool(r["avanzato"]), "Sequenza avanzata")
	assert_eq(_prog().sequence(), 4, "5 -> 4")
	_pulisci_dati()


func test_ricevi_boon_senza_requisiti_soddisfatti_non_fa_nulla() -> void:
	_vai_a(5)
	var r: Dictionary = _boon().call("ricevi_boon")
	assert_false(bool(r["ok"]), "ricevi_boon rifiutato")
	assert_false(bool(r["avanzato"]), "nessun avanzamento")
	assert_eq(_prog().sequence(), 5, "Sequenza invariata")
	_pulisci_dati()


# --- Requisito 'comportamento' (Sequenza 8: un solo requisito) -------------

func test_requisito_comportamento_progresso_parziale() -> void:
	_vai_a(8)
	_et().call("emit_event", "enemy_defeated", {})
	var stato: Array = _boon().call("requisiti_stato")
	assert_almost_eq(float(stato[0]["progresso"]), 1.0, "1 su 2 nemici")
	assert_false(bool(stato[0]["soddisfatto"]), "non ancora soddisfatto")
	assert_false(_boon().call("puo_ricevere"), "puo_ricevere falso a meta'")
	_pulisci_dati()


func test_requisito_comportamento_soddisfatto_al_target() -> void:
	_vai_a(8)
	_et().call("emit_event", "enemy_defeated", {})
	_et().call("emit_event", "enemy_defeated", {})
	assert_true(_boon().call("puo_ricevere"), "2 nemici -> requisito soddisfatto")
	_pulisci_dati()


func test_requisito_comportamento_baseline_alla_sequenza_corrente() -> void:
	# eventi emessi PRIMA di entrare nella Sequenza non contano (stesso
	# principio di Acting._baseline).
	_et().call("emit_event", "enemy_defeated", {})
	_et().call("emit_event", "enemy_defeated", {})
	_vai_a(8)
	assert_false(_boon().call("puo_ricevere"), "eventi pre-baseline non contano")
	_pulisci_dati()


# --- Requisito 'sacrificio' — caratteristica (Sequenza 7) -------------------

func test_sacrificio_caratteristica_non_disponibile() -> void:
	_vai_a(7)
	assert_false(_boon().call("puo_ricevere"), "caratteristica non posseduta")
	_pulisci_dati()


func test_sacrificio_caratteristica_consumata_da_ricevi_boon() -> void:
	_vai_a(7)
	_car().call("aggiungi", "char_twilight_giant_9")
	assert_true(_boon().call("puo_ricevere"), "caratteristica posseduta")
	var r: Dictionary = _boon().call("ricevi_boon")
	assert_true(bool(r["ok"]), "ricevi_boon ok")
	assert_false(bool(_car().call("possiede", "char_twilight_giant_9")), "caratteristica consumata")
	assert_eq(_prog().sequence(), 6, "7 -> 6")
	_pulisci_dati()


# --- Requisito 'sacrificio' — follia (Sequenza 6) ---------------------------

func test_sacrificio_follia_sempre_disponibile_e_aumenta_la_follia() -> void:
	_vai_a(6)
	assert_true(_boon().call("puo_ricevere"), "il costo di follia si paga, non si possiede in anticipo")
	var prima: float = float(_madness().call("valore"))
	var r: Dictionary = _boon().call("ricevi_boon")
	assert_true(bool(r["ok"]), "ricevi_boon ok")
	assert_gt(float(_madness().call("valore")), prima, "follia aumentata dal sacrificio")
	assert_eq(_prog().sequence(), 5, "6 -> 5")
	_pulisci_dati()


# --- Requisito misto: quest + comportamento + sacrificio (Sequenza 9) ------

func test_boon_misto_richiede_tutti_i_requisiti() -> void:
	_vai_a(9)
	var stato: Array = _boon().call("requisiti_stato")
	assert_eq(stato.size(), 3, "tre requisiti dichiarati")
	assert_false(_boon().call("puo_ricevere"), "nessun requisito soddisfatto")

	_completa_quest("q_mirco_01")
	assert_false(_boon().call("puo_ricevere"), "manca ancora comportamento e sacrificio")

	for i in 3:
		_et().call("emit_event", "enemy_defeated", {})
	assert_false(_boon().call("puo_ricevere"), "manca ancora il sacrificio (oggetto insufficiente)")

	_inv().call("aggiungi", "ferro_temperato", 2)
	assert_true(_boon().call("puo_ricevere"), "tutti e tre i requisiti soddisfatti")
	_pulisci_dati()


func test_boon_misto_ricevi_consuma_solo_alla_riuscita() -> void:
	_vai_a(9)
	_completa_quest("q_mirco_01")
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {})
	_inv().call("aggiungi", "ferro_temperato", 2)

	var r: Dictionary = _boon().call("ricevi_boon")
	assert_true(bool(r["ok"]), "ricevi_boon ok")
	assert_true(bool(r["avanzato"]), "Sequenza avanzata")
	assert_eq(_prog().sequence(), 8, "9 -> 8")
	assert_eq(int(_inv().call("conta", "ferro_temperato")), 0, "2 ferro_temperato consumati")
	_pulisci_dati()


func test_boon_misto_ricevi_boon_non_consuma_se_manca_un_requisito() -> void:
	_vai_a(9)
	_completa_quest("q_mirco_01")
	for i in 3:
		_et().call("emit_event", "enemy_defeated", {})
	# nessun ferro_temperato in inventario: il sacrificio manca

	var r: Dictionary = _boon().call("ricevi_boon")
	assert_false(bool(r["ok"]), "ricevi_boon rifiutato")
	assert_eq(_prog().sequence(), 9, "Sequenza invariata, nessun avanzamento parziale")
	assert_eq(int(_inv().call("conta", "ferro_temperato")), 0, "nulla consumato (non c'era comunque nulla)")
	_pulisci_dati()


# --- Sequenza senza 'boon' ---------------------------------------------------

func test_sequenza_senza_boon_non_e_mai_pronta() -> void:
	_vai_a(4)   # fixture_boon_test_4 non ha 'boon'
	assert_true((_boon().call("requisiti_stato") as Array).is_empty(), "nessun requisito su una Sequenza senza boon")
	assert_false(_boon().call("puo_ricevere"), "niente da ricevere su una Sequenza senza boon")
	var r: Dictionary = _boon().call("ricevi_boon")
	assert_false(bool(r["ok"]), "ricevi_boon rifiutato")
	assert_eq(str(r["reason"]), "nessun_boon", "motivo esplicito")
	_pulisci_dati()


# --- Persistenza nel save ---------------------------------------------------

func test_persistenza_baseline_nel_save() -> void:
	var s: Node = Engine.get_main_loop().root.get_node("SaveSystem")
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")

	_vai_a(8)
	_et().call("emit_event", "enemy_defeated", {})
	var atteso: Array = _boon().call("requisiti_stato")
	assert_almost_eq(float(atteso[0]["progresso"]), 1.0, "progresso da salvare")

	if s.esiste(SLOT):
		s.cancella(SLOT)
	assert_true(s.salva(SLOT, gs.snapshot())["ok"], "salva ok")

	# reset totale, poi reload dal save
	_et().call("azzera")
	_boon().call("_riparti")
	assert_almost_eq(float((_boon().call("requisiti_stato") as Array)[0]["progresso"]), 0.0, "azzerato")

	var c: Dictionary = s.carica(SLOT)
	gs.applica(c["dati"])
	assert_almost_eq(float((_boon().call("requisiti_stato") as Array)[0]["progresso"]), 1.0,
		"progresso ripristinato dal save")
	s.cancella(SLOT)
	_pulisci_dati()
