extends "res://tests/test_case.gd"
## US-322 — taming: domare una creatura e renderla il proprio pet.


func _n(p: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(p)


func prepara() -> void:
	if _n("/root/PetSystem") != null:
		_n("/root/PetSystem").call("pulisci")
	if _n("/root/AnchorSystem") != null:
		_n("/root/AnchorSystem").call("pulisci")
	if _n("/root/SummonRegistry") != null:
		_n("/root/SummonRegistry").call("pulisci")
	if _n("/root/Madness") != null:
		_n("/root/Madness").call("azzera")


## RNG seedabile (US-322): non si conosce a priori quale seed dia quale
## esito (dipende dall'implementazione del PRNG di Godot), come gia' fa
## test_experiment.gd per l'alchimia - si cerca il primo seed che produce
## l'esito voluto, entro un tetto ragionevole di tentativi.
func _trova_seed(pet_id: String, successo: bool) -> int:
	var ps: Node = _n("/root/PetSystem")
	for s in range(1, 300):
		ps.call("pulisci")
		_n("/root/AnchorSystem").call("pulisci")
		ps.call("imposta_seed", s)
		if bool(ps.call("doma", pet_id)) == successo:
			ps.call("pulisci")
			_n("/root/AnchorSystem").call("pulisci")
			return s
	return -1


func test_doma_con_seed_fortunato_imposta_pet_e_ancora() -> void:
	var ps: Node = _n("/root/PetSystem")
	var anc: Node = _n("/root/AnchorSystem")
	var s: int = _trova_seed("corvo_predittivo", true)
	assert_true(s >= 0, "esiste un seed fortunato entro 300 tentativi")
	ps.call("imposta_seed", s)
	assert_true(ps.call("doma", "corvo_predittivo"), "doma riesce col seed fortunato")
	assert_eq(ps.call("pet_attivo").get("pet_id"), "corvo_predittivo", "pet impostato")
	assert_true((anc.call("active") as Array).has("anchor_pet_corvo"), "l'Ancora del pet e' attiva")


func test_doma_con_seed_sfortunato_non_imposta_pet() -> void:
	var ps: Node = _n("/root/PetSystem")
	var s: int = _trova_seed("lupo_ombra", false)
	assert_true(s >= 0, "esiste un seed sfortunato entro 300 tentativi")
	ps.call("imposta_seed", s)
	assert_false(ps.call("doma", "lupo_ombra"), "doma fallisce col seed sfortunato")
	assert_true((ps.call("pet_attivo") as Dictionary).is_empty(), "nessun pet impostato")


func test_secondo_taming_bloccato_finche_non_liberi() -> void:
	var ps: Node = _n("/root/PetSystem")
	ps.call("imposta_pet", "lupo_ombra")   # stato "gia' un pet", bypassa il tiro
	assert_false(ps.call("doma", "corvo_predittivo"), "un pet gia' attivo blocca un secondo taming")
	assert_true(ps.call("libera"), "libera il primo")
	var s: int = _trova_seed("corvo_predittivo", true)
	ps.call("imposta_seed", s)
	assert_true(ps.call("doma", "corvo_predittivo"), "libero il posto, il secondo taming puo' riuscire")


func test_libera_non_aggiunge_follia() -> void:
	var ps: Node = _n("/root/PetSystem")
	var madness: Node = _n("/root/Madness")
	ps.call("imposta_pet", "lupo_ombra")
	_n("/root/AnchorSystem").call("register", "anchor_pet_lupo_ombra")
	var f0: float = madness.call("valore")
	assert_true(ps.call("libera"), "libera riesce")
	assert_almost_eq(madness.call("valore"), f0, "rilascio pulito: niente follia (diverso dalla morte)")
	assert_false((_n("/root/AnchorSystem").call("active") as Array).has("anchor_pet_lupo_ombra"),
		"l'Ancora e' stata tolta")


func test_libera_senza_pet_fallisce() -> void:
	assert_false(_n("/root/PetSystem").call("libera"), "niente da liberare -> false")


func test_doma_registra_unevocazione_libera_la_rimuove() -> void:
	var ps: Node = _n("/root/PetSystem")
	var reg: Node = _n("/root/SummonRegistry")
	var s: int = _trova_seed("corvo_predittivo", true)
	ps.call("imposta_seed", s)
	ps.call("doma", "corvo_predittivo")
	assert_eq(reg.call("conta"), 1, "un'evocazione persistente per il pet appena domato")
	ps.call("libera")
	assert_eq(reg.call("conta"), 0, "rimossa alla liberazione")
