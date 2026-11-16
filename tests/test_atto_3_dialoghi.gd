extends "res://tests/test_case.gd"
## US-1307 / US-1308 / US-1309 — Le tre scene dell'Atto III: Doran sa, Lena capisce, Vesna sceglie. Solo da tier
## saint, una volta sola (condizione flag_assente), con le conseguenze scritte nei dati.

func _root() -> Node: return Engine.get_main_loop().root
func _ks() -> Node: return _root().get_node("KnowledgeStore")
func _fs() -> Node: return _root().get_node("FactionSystem")
func _de() -> Node: return _root().get_node("DialogueEngine")
func _pr() -> Node: return _root().get_node("Progression")
func _anc() -> Node: return _root().get_node("AnchorSystem")
func _ns() -> Node: return _root().get_node("NpcSystem")
func _qs() -> Node: return _root().get_node("QuestSystem")


func prepara() -> void:
	_qs().call("pulisci")
	_ks().call("dimentica_tutto")
	_root().get_node("EventTracker").call("azzera")
	_ns().call("pulisci")
	_anc().call("pulisci")
	_fs().call("pulisci")
	_de().call("termina")
	_pr().call("configura", "twilight_giant", 4)


func _dopo() -> void:
	_de().call("termina")
	_anc().call("pulisci")
	_ns().call("pulisci")
	_qs().call("pulisci")
	_pr().call("configura", "twilight_giant", 9)


func _scegli(chiave: String) -> bool:
	var valide: Array = _de().call("scelte_valide")
	for i in valide.size():
		if str(valide[i]["text_i18n"]) == chiave:
			return bool(_de().call("scegli", i))
	return false


func _parla(dialogo: String, npc: String, scelte: Array) -> bool:
	_de().call("termina")
	_de().call("avvia", dialogo, npc)
	var tutte := true
	for s in scelte:
		tutte = _scegli(str(s)) and tutte
	return tutte


func test_le_scene_si_aprono_solo_da_tier_saint() -> void:
	_pr().call("configura", "twilight_giant", 6)
	assert_false(_parla("dlg_doran", "npc_doran", ["dialogue.doran.n1.affronta"]), "Doran: non prima")
	assert_false(_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.riconosci"]), "Lena: non prima")
	assert_false(_parla("dlg_vesna", "npc_vesna", ["dialogue.vesna.n1.bivio"]), "Vesna: non prima")
	_dopo()


func test_doran_sa_e_si_fa_un_patto() -> void:
	assert_true(_parla("dlg_doran", "npc_doran", ["dialogue.doran.n1.affronta"]), "a tier saint lo si affronta")
	assert_eq(str(_de().call("nodo_corrente").get("text_i18n", "")), "dialogue.doran.n4", "e Doran dice quello che sa")
	assert_true(_ks().call("conosce", "tribolazione_doran_affrontato"), "il flag della tribolazione resta quello di prima")
	_scegli("dialogue.doran.n4.patto")
	assert_true(_ks().call("conosce", "doran_patto"), "il patto e' scritto")
	assert_eq(float(_fs().call("reputazione", "giustizia")), 20.0, "la giustizia ti guarda meglio")
	assert_false(_parla("dlg_doran", "npc_doran", ["dialogue.doran.n1.affronta"]), "la scena non si ripete")
	assert_eq(float(_fs().call("reputazione", "giustizia")), 20.0, "ne' la reputazione")
	_dopo()


func test_doran_sfidato_diventa_un_nemico() -> void:
	_parla("dlg_doran", "npc_doran", ["dialogue.doran.n1.affronta", "dialogue.doran.n4.sfida"])
	assert_true(_ks().call("conosce", "doran_nemico"), "sfidarlo e' scritto")
	assert_eq(float(_fs().call("reputazione", "giustizia")), -20.0, "e la giustizia ti cerca")
	_dopo()


func test_un_ancora_persona_ferma_la_follia() -> void:
	_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.gioca"])
	assert_true("anchor_lena" in _anc().call("active"), "giocare con Lena la rende un'Ancora vera, non solo un nome")
	assert_eq(float(_anc().call("forza_di", "anchor_lena")), 5.0, "con la forza dei dati")
	_anc().call("destroy", "anchor_lena")
	assert_false("npc_lena" in _ns().call("ancore_attive"), "persa l'Ancora, Lena non e' piu' fra le Ancore")
	_dopo()


func test_lena_capisce_e_la_sua_ancora_si_rafforza() -> void:
	_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.gioca"])
	assert_true(_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.riconosci", "dialogue.lena.n4.ancora_io"]), "Lena ti riconosce")
	assert_eq(str(_qs().call("stato", "q_lena_02")), "completata", "la quest della scena si chiude")
	assert_eq(float(_anc().call("forza_di", "anchor_lena")), 10.0, "la sua Ancora raddoppia")
	assert_false(_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.riconosci"]), "la scena non si ripete")
	_dopo()


func test_lena_ha_paura_e_la_sua_ancora_si_assottiglia() -> void:
	_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.gioca"])
	_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.riconosci", "dialogue.lena.n4.non_del_tutto"])
	assert_eq(float(_anc().call("forza_di", "anchor_lena")), 2.0, "allontanata, regge quasi niente")
	assert_eq(str(_qs().call("stato", "q_lena_02")), "non_iniziata", "l'altro lato non parte")
	_dopo()


func test_lena_senza_ancora_non_ne_crea_una() -> void:
	_parla("dlg_lena", "npc_lena", ["dialogue.lena.n1.riconosci", "dialogue.lena.n4.ancora_io"])
	assert_true(_ks().call("conosce", "lena_ha_capito"), "la scena c'e' lo stesso")
	assert_false("anchor_lena" in _anc().call("active"), "ma chi non ha mai giocato con lei non ha un'Ancora")
	_dopo()


func test_vesna_resta_o_se_ne_va() -> void:
	_parla("dlg_vesna", "npc_vesna", ["dialogue.vesna.n1.bivio", "dialogue.vesna.n4.resta"])
	assert_true(_ks().call("conosce", "vesna_resta"), "Vesna resta")
	assert_eq(float(_fs().call("reputazione", "quartiere")), 15.0, "e il quartiere lo sa")
	assert_false(_parla("dlg_vesna", "npc_vesna", ["dialogue.vesna.n1.bivio"]), "il bivio si passa una volta")
	_ks().call("dimentica_tutto")
	_fs().call("pulisci")
	_parla("dlg_vesna", "npc_vesna", ["dialogue.vesna.n1.bivio", "dialogue.vesna.n4.vai"])
	assert_true(_ks().call("conosce", "vesna_se_ne_va"), "oppure se ne va")
	assert_eq(float(_fs().call("reputazione", "quartiere")), -10.0, "e il quartiere perde la sua guaritrice")
	_dopo()
