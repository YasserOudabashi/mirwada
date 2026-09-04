extends "res://tests/test_case.gd"
## US-335 — IL VERDETTO SULL'ARCHITETTURA DI FASE 3.
##
## Un ciclo di crafting/progressione completo giocato in codice: giardino ->
## laboratorio (sperimentazione + preparazione) -> forgiatura -> incastonatura
## di un sigillo -> taming di un pet + sblocco di un suo comportamento ->
## sblocco di un talento acquisito -> le loro fonti sommate da SynergySources.
##
## Se qualcosa qui richiede un `if` su un item/ricetta/pet specifico,
## l'architettura di fase 3 va corretta prima di aprire fase 4 (come US-219
## per fase 2). test_nessun_nome_di_contenuto_hardcoded_in_scripts() e' il
## verdetto: verifica che scripts/ non nomini nessuno di questi id.

const StatsComponent := preload("res://scripts/stats_component.gd")

var _player: Node2D = null


func _root() -> Node: return Engine.get_main_loop().root
func _n(p: String) -> Node: return _root().get_node_or_null(p)


func prepara() -> void:
	if _player != null and is_instance_valid(_player):
		_player.free()
	_player = Node2D.new()
	_player.add_to_group("player")
	var s: Node = StatsComponent.new()
	s.name = "StatsComponent"
	_player.add_child(s)
	_root().add_child(_player)
	s.call("configure_from_balance", 9)

	for a in ["/root/Inventory", "/root/Equipment", "/root/BaseSystem", "/root/PetSystem",
			"/root/AnchorSystem", "/root/SummonRegistry", "/root/TalentSystem"]:
		if _n(a) != null:
			_n(a).call("pulisci")
	if _n("/root/TalentTracker") != null:
		_n("/root/TalentTracker").call("azzera")
	if _n("/root/EventTracker") != null:
		_n("/root/EventTracker").call("azzera")
	if _n("/root/KnowledgeStore") != null:
		_n("/root/KnowledgeStore").call("dimentica_tutto")
	if _n("/root/GameState") != null:
		_n("/root/GameState").set("tempo_gioco", 0.0)


func test_ciclo_completo_di_crafting_e_progressione() -> void:
	var inv: Node = _n("/root/Inventory")
	var bs: Node = _n("/root/BaseSystem")
	var ps: Node = _n("/root/PotionSystem")
	var forge: Node = _n("/root/Forge")
	var eq: Node = _n("/root/Equipment")
	var pet: Node = _n("/root/PetSystem")
	var ts: Node = _n("/root/TalentSystem")
	var tt: Node = _n("/root/TalentTracker")
	var et: Node = _n("/root/EventTracker")
	var ss: Node = _n("/root/SynergySources")

	# --- 1. Giardino: costruisci, pianta, avanza il tempo, raccogli ---
	inv.call("aggiungi", "cuoio_conciato", 1)
	assert_true(bs.call("costruisci", "giardino"), "il giardino si costruisce")
	inv.call("aggiungi", "erba_lunare", 1)
	var idx: int = bs.call("pianta", "erba_lunare")
	assert_true(idx >= 0, "l'ingrediente coltivabile si pianta")
	_n("/root/GameState").set("tempo_gioco", 9999.0)
	assert_true(bs.call("e_pronto", idx), "col tempo avanzato l'appezzamento e' pronto")
	assert_true(bs.call("raccogli", idx), "si raccoglie")
	assert_gt(float(inv.call("conta", "erba_lunare")), 0.0, "l'ingrediente raccolto torna nello zaino")
	# top-up indipendente dalla resa esatta del giardino: i passi 2 ne servono 2.
	inv.call("aggiungi", "erba_lunare", 2)

	# --- 2. Laboratorio: sperimenta -> scoperta, poi prepara la ricetta nota ---
	inv.call("aggiungi", "lingotto_ferro", 2)
	inv.call("aggiungi", "cristallo_grezzo", 1)
	assert_true(bs.call("costruisci", "laboratorio"), "il laboratorio si costruisce")
	assert_false(ps.call("ricetta_nota", "ric_cura_maggiore"), "premessa: la ricetta avanzata non e' ancora nota")

	inv.call("aggiungi", "petalo_solare", 2)
	inv.call("aggiungi", "acqua_sorgiva", 1)
	var esperimento: Dictionary = ps.call("sperimenta",
		["petalo_solare", "petalo_solare", "acqua_sorgiva", "erba_lunare"])
	assert_eq(esperimento.get("esito"), "scoperta", "la combinazione giusta scopre la ricetta avanzata")
	assert_true(ps.call("ricetta_nota", "ric_cura_maggiore"), "la ricetta scoperta e' ora nota")

	inv.call("aggiungi", "petalo_solare", 2)
	inv.call("aggiungi", "acqua_sorgiva", 1)
	var preparata: Dictionary = ps.call("prepara", "ric_cura_maggiore")
	assert_true(preparata.get("ok", false), "la ricetta ora nota si prepara col percorso normale")
	assert_ne(preparata.get("qualita"), "pura",
		"col bonus del laboratorio la qualita' e' migliorata sopra la qualita_base della ricetta")

	# --- 3. Forgiatura: forgia un equip dai materiali, lo equipaggia ---
	inv.call("aggiungi", "cristallo_grezzo", 2)
	inv.call("aggiungi", "lingotto_ferro", 1)
	var forgiato: Dictionary = forge.call("forgia", "bp_amuleto_lunare")
	assert_true(forgiato.get("ok", false), "la forgiatura riesce coi materiali presenti")
	var equip_iid: String = str(forgiato.get("instance_id", ""))
	assert_true(eq.call("equipaggia", equip_iid), "l'oggetto forgiato si equipaggia")

	# --- 4. Sigillo: incastona, verifica effetto + effetto_collaterale ---
	var evasione0: float = _player.get_node("StatsComponent").call("get_stat", "evasione")
	var spirmax0: float = _player.get_node("StatsComponent").call("get_stat", "spiritualita_max")
	var creati: Array = inv.call("aggiungi", "sigillo_ombra_fame", 1)
	var sig_iid: String = str(creati[0]) if not creati.is_empty() else ""
	assert_true(eq.call("incastona", "accessorio_1", sig_iid), "il sigillo si incastona")
	var stats: Node = _player.get_node("StatsComponent")
	assert_gt(stats.call("get_stat", "evasione"), evasione0, "l'effetto del sigillo alza l'evasione")
	assert_true(stats.call("get_stat", "spiritualita_max") < spirmax0,
		"l'effetto_collaterale abbassa la spiritualita' massima: e' un prezzo, non solo un bonus")

	# --- 5. Pet: doma con un seed fortunato, il bond sblocca un comportamento ---
	var seed_fortunato: int = -1
	for s in range(1, 300):
		pet.call("pulisci")
		_n("/root/AnchorSystem").call("pulisci")
		pet.call("imposta_seed", s)
		if bool(pet.call("doma", "lupo_ombra")):
			seed_fortunato = s
			break
	assert_true(seed_fortunato >= 0, "premessa: esiste un seed fortunato entro 300 tentativi")
	assert_eq(pet.call("pet_attivo").get("pet_id"), "lupo_ombra", "il pet e' domato")
	assert_true((pet.call("comportamenti_sbloccati") as Array).is_empty(), "nessun comportamento a bond 0")
	for i in 10:   # bond_per_enemy_defeated (2.0) x10 = 20 = soglia_bond di fiuto_base
		et.call("emit_event", "enemy_defeated", {})
	assert_true((pet.call("comportamenti_sbloccati") as Array).has("fiuto_base"),
		"il bond accumulato sblocca il comportamento della soglia")
	assert_true((pet.call("tag_attivi") as Dictionary).has("analisi"),
		"il tag del comportamento sbloccato e' attivo")

	# --- 6. Talenti: un acquisito si sblocca superando la soglia del suo evento ---
	assert_false(ts.call("possiede", "cacciatore_paziente"), "premessa: non ancora sbloccato")
	for i in 10:   # cacciatore_paziente: sblocco nemici_risparmiati, target 10
		tt.call("emit_event", "nemici_risparmiati", {})
	assert_true(ts.call("possiede", "cacciatore_paziente"), "il talento si sblocca superando la soglia")

	# --- 7. SynergySources: la somma include i tag di ogni fonte ---
	var tag: Dictionary = ss.call("tag_sinergia_globali")
	assert_true(tag.has("luna"), "il tag dell'equip indossato conta (inventario/Equipment)")
	assert_true(tag.has("crescita"), "il tag della specie del pet conta (PetSystem)")
	assert_true(tag.has("non_letale"), "il tag_grant del talento sbloccato conta (TalentSystem)")
	assert_true(tag.has("pozione"), "il tag della stanza costruita conta (BaseSystem)")


## Il verdetto (come US-219): scripts/ (ricorsivo, quindi anche scripts/pages/)
## non deve nominare NESSUN id specifico di item, ricetta, blueprint o pet -
## quei sistemi devono comporre leggendo i dati, non con un `if` sul contenuto.
## I 4 tipi di stanza (laboratorio/stanza_rituale/biblioteca/giardino) sono
## ESCLUSI apposta: sono il vocabolario CHIUSO di data/schema/room_types.json,
## strutturale come i 12 tracked_events, non "contenuto" - gia' cosi' da
## US-326/327 (Forge/PotionSystem leggono bonus() passando il tipo).
func test_nessun_nome_di_contenuto_hardcoded_in_scripts() -> void:
	var gd: Node = _n("/root/GameData")
	var vietati: Array = []
	vietati.append_array(gd.call("item_ids"))
	vietati.append_array(gd.call("recipe_ids"))
	vietati.append_array(gd.call("blueprint_ids"))
	vietati.append_array(gd.call("pet_species_ids"))

	var colpevoli: PackedStringArray = []
	for f in _script_files("res://scripts"):
		var testo: String = FileAccess.get_file_as_string(f)
		for riga in testo.split("\n"):
			var codice: String = riga.split("##")[0].split("#")[0]
			for v in vietati:
				if str(v) != "" and codice.contains(str(v)):
					colpevoli.append("%s: %s" % [f, riga.strip_edges()])
	assert_eq(colpevoli.size(), 0,
		"nessun id di item/ricetta/blueprint/pet hardcoded in scripts/: %s" % colpevoli)


func _script_files(path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			var full: String = path + "/" + name
			if d.current_is_dir():
				out.append_array(_script_files(full))
			elif name.ends_with(".gd"):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out
