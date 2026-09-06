extends Node
## Il motore delle sinergie (fase 4). Legge SynergySources.tag_sinergia_globali()
## e decide quali sinergie sono ATTIVE — richiede_tag tutti soddisfatti, nessun
## esclude_tag presente.
##
## US-401: risoluzione tag -> insieme attivo. US-402: rivalutazione reattiva
## (segnali delle fonti + poll ogni ~0.5 s), segnali sinergia_attivata/
## disattivata sui cambi reali. Gli EFFETTI li applicano US-403..405;
## anti-sinergie US-407.
##
## E' l'UNICO sistema che conosce le regole di sinergia. Nessuna fonte le
## conosce, nessun if per una sinergia specifica.
##
## NIENTE class_name: coerente col resto del progetto.

signal sinergia_attivata(id: String)
signal sinergia_disattivata(id: String)

const _POLL_S := 0.5

## Solo per i test: se non vuoto, sostituisce SynergySources.tag_sinergia_globali().
var _tag_override: Dictionary = {}
## L'insieme attivo all'ultima rivalutazione: il diff si fa contro questo.
var _attive_prec: Array = []
var _accumulo: float = 0.0
## US-403: { synergy_id: delta_al_minuto } delle sinergie modifica_follia attive.
var _follia_attive: Dictionary = {}
var _acc_follia: float = 0.0
## US-404: { synergy_id: ability_id } delle sinergie aggiungi_abilita attive.
var _abilita_attive: Dictionary = {}


func _ready() -> void:
	# Le fonti emettono gia' i loro segnali di cambiamento (fase 3). Un segnale
	# mancante e' un bug di quella fonte: si apre una micro-story, non un if qui.
	_collega("/root/Equipment", ["equip_cambiato"])
	_collega("/root/PetSystem", ["pet_impostato", "pet_liberato", "pet_morto",
			"bond_cambiato", "pet_avanzato"])
	_collega("/root/TalentSystem", ["talento_sbloccato"])
	_collega("/root/BaseSystem", ["stanza_costruita", "stanza_potenziata"])
	_collega("/root/Progression", ["sequence_changed"])
	# US-403+: il motore reagisce ai PROPRI segnali per applicare/togliere gli
	# effetti. Diff e applicazione restano separati.
	sinergia_attivata.connect(_su_attivata)
	sinergia_disattivata.connect(_su_disattivata)


func _collega(path: String, segnali: Array) -> void:
	var n: Node = get_node_or_null(path)
	if n == null:
		return
	for s in segnali:
		if n.has_signal(s):
			# .unbind lascia passare qualsiasi firma: al motore importa solo
			# che QUALCOSA e' cambiato.
			var ar: int = _arita(n, s)
			n.connect(s, (_su_fonte_cambiata.unbind(ar) if ar > 0 else _su_fonte_cambiata))


func _arita(n: Node, s: String) -> int:
	for info in n.get_signal_list():
		if info["name"] == s:
			return (info["args"] as Array).size()
	return 0


func _su_fonte_cambiata() -> void:
	rivaluta()


func _process(delta: float) -> void:
	_accumulo += delta
	if _accumulo >= _POLL_S:
		_accumulo = 0.0
		rivaluta()
	# US-403: le sinergie modifica_follia versano il loro delta_al_minuto in
	# Madness un secondo alla volta. Negativo = riducono la follia nel tempo.
	if not _follia_attive.is_empty():
		_acc_follia += delta
		if _acc_follia >= 1.0:
			var m: Node = get_node_or_null("/root/Madness")
			if m != null:
				for id in _follia_attive:
					var q: float = float(_follia_attive[id]) / 60.0 * _acc_follia
					if q != 0.0:
						m.call("add", q, "synergy:" + str(id), false)
			_acc_follia = 0.0


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


## { tag: conteggio } di tutto cio' che il giocatore porta. Da SynergySources,
## o dall'override nei test.
func tag_globali() -> Dictionary:
	if not _tag_override.is_empty():
		return _tag_override.duplicate()
	var ss: Node = get_node_or_null("/root/SynergySources")
	return (ss.call("tag_sinergia_globali") as Dictionary) if ss != null else {}


## Gli id delle sinergie soddisfatte dai tag correnti, in ordine lessicografico.
func attive() -> Array:
	if _gd() == null:
		return []
	var tg: Dictionary = tag_globali()
	var out: Array = []
	for id in _gd().call("synergy_ids"):
		if _soddisfatta(_gd().call("get_synergy", id), tg):
			out.append(str(id))
	out.sort()
	return out


func e_attiva(id: String) -> bool:
	return attive().has(id)


## { tag: quanti ne mancano } per completare la sinergia. {} se gia' soddisfatta
## o id ignoto. Usato dalla UI del registro (US-409/410).
func tag_mancanti(id: String) -> Dictionary:
	var syn: Dictionary = _gd().call("get_synergy", id) if _gd() != null else {}
	if syn.is_empty():
		return {}
	var tg: Dictionary = tag_globali()
	var out: Dictionary = {}
	for t in syn.get("richiede_tag", {}):
		var manca: int = int(syn["richiede_tag"][t]) - int(tg.get(t, 0))
		if manca > 0:
			out[str(t)] = manca
	return out


## Ricalcola l'insieme attivo e, per ogni cambio REALE rispetto all'ultima
## volta, emette sinergia_attivata / sinergia_disattivata. Idempotente: due
## chiamate consecutive senza cambi di tag non emettono niente.
func rivaluta() -> void:
	var ora: Array = attive()
	for id in ora:
		if not _attive_prec.has(id):
			sinergia_attivata.emit(id)
	for id in _attive_prec:
		if not ora.has(id):
			sinergia_disattivata.emit(id)
	_attive_prec = ora


## Ri-applica gli effetti "spinti" (modifica_stat, aggiungi_abilita) delle
## sinergie attive: da chiamare quando compare il giocatore in scena o dopo un
## load (come TalentSystem.riapplica). Gli effetti "tirati" (qualita_crafting,
## primitiva) e modifica_follia non hanno bisogno di essere ri-applicati.
func riapplica() -> void:
	for id in _attive_prec:
		_applica_effetto(str(id))


func pulisci() -> void:
	var st: Node = _stats()
	if st != null:
		for id in _attive_prec:
			st.call("remove_modifier", "synergy:" + str(id))
	var ae: Node = get_node_or_null("/root/AbilityEngine")
	if ae != null:
		for id in _abilita_attive:
			ae.call("revoca_permanente", str(_abilita_attive[id]))
	_tag_override = {}
	_attive_prec = []
	_accumulo = 0.0
	_follia_attive = {}
	_acc_follia = 0.0
	_abilita_attive = {}


# --- Applicazione degli effetti (US-403..405) ------------------------

func _su_attivata(id: String) -> void:
	_applica_effetto(id)


func _su_disattivata(id: String) -> void:
	_rimuovi_effetto(id)


## US-404: modifica_qualita_crafting e' ESCLUSIVO per categoria - PotionSystem/
## Forge chiedono qui il delta (in passi di qualita') della sinergia attiva con
## priorita' piu' alta su quella categoria (tie: id lessicografico minore).
func bonus_qualita(categoria: String) -> int:
	if _gd() == null:
		return 0
	var scelta_pri: int = -2147483648
	var scelta_id: String = ""
	var scelta_delta: int = 0
	for id in _attive_prec:
		var syn: Dictionary = _gd().call("get_synergy", id)
		var eff: Dictionary = syn.get("effetto", {})
		if str(eff.get("tipo", "")) != "modifica_qualita_crafting":
			continue
		if str(eff.get("categoria", "")) != categoria:
			continue
		var pri: int = int(syn.get("priorita", 0))
		if pri > scelta_pri or (pri == scelta_pri and (scelta_id == "" or str(id) < scelta_id)):
			scelta_pri = pri
			scelta_id = str(id)
			scelta_delta = int(eff.get("delta", 0))
	return scelta_delta


## US-405: applica ai parametri di 'prim' (che il chiamante ha gia' COPIATO) i
## delta delle sinergie modifica_primitiva attive su quella primitiva. I delta
## flat di piu' sinergie si sommano; i moltiplicativi pure:
##   nuovo = (base + somma_flat) * (1 + somma_mult)
func applica_modifiche_primitiva(primitiva: String, prim: Dictionary) -> void:
	if _gd() == null:
		return
	var flat: Dictionary = {}
	var mult: Dictionary = {}
	for id in _attive_prec:
		var eff: Dictionary = (_gd().call("get_synergy", id) as Dictionary).get("effetto", {})
		if str(eff.get("tipo", "")) != "modifica_primitiva":
			continue
		if str(eff.get("primitiva", "")) != primitiva:
			continue
		var par: String = str(eff.get("parametro", ""))
		if bool(eff.get("moltiplicativo", false)):
			mult[par] = float(mult.get(par, 0.0)) + float(eff.get("delta", 0.0))
		else:
			flat[par] = float(flat.get(par, 0.0)) + float(eff.get("delta", 0.0))
	var pars: Array = flat.keys()
	for p in mult:
		if not pars.has(p):
			pars.append(p)
	for par in pars:
		var base: float = float(prim.get(par, 0.0))
		prim[par] = (base + float(flat.get(par, 0.0))) * (1.0 + float(mult.get(par, 0.0)))


func _applica_effetto(id: String) -> void:
	var eff: Dictionary = (_gd().call("get_synergy", id) as Dictionary).get("effetto", {}) if _gd() != null else {}
	match str(eff.get("tipo", "")):
		"modifica_stat":
			var st: Node = _stats()
			if st == null:
				return
			var stat: String = str(eff.get("stat", ""))
			var v: float = float(eff.get("valore", 0.0))
			var delta: float = v * float(st.call("get_base", stat)) if bool(eff.get("moltiplicativo", false)) else v
			st.call("apply_modifier", "synergy:" + id, {stat: delta})
		"modifica_follia":
			_follia_attive[id] = float(eff.get("delta_al_minuto", 0.0))
		"sblocca_ricetta":
			var kn: Node = get_node_or_null("/root/KnowledgeStore")
			if kn != null:
				# imparare non si dimentica: nessuna revoca alla disattivazione
				kn.call("impara", "ricetta:" + str(eff.get("recipe_id", "")))
		"aggiungi_abilita":
			var ae: Node = get_node_or_null("/root/AbilityEngine")
			if ae != null and ae.call("grant_permanente", str(eff.get("ability_id", ""))):
				_abilita_attive[id] = str(eff.get("ability_id", ""))
		"modifica_qualita_crafting", "modifica_primitiva":
			pass  # PULL: i sistemi leggono bonus_qualita() / applica_modifiche_primitiva()


func _rimuovi_effetto(id: String) -> void:
	var st: Node = _stats()
	if st != null:
		st.call("remove_modifier", "synergy:" + id)
	_follia_attive.erase(id)
	if _abilita_attive.has(id):
		var ae: Node = get_node_or_null("/root/AbilityEngine")
		if ae != null:
			ae.call("revoca_permanente", str(_abilita_attive[id]))
		_abilita_attive.erase(id)


func _stats() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p.get_node_or_null("StatsComponent") if p != null else null


# --- Interno --------------------------------------------------------

func _soddisfatta(syn: Dictionary, tg: Dictionary) -> bool:
	if syn.is_empty():
		return false
	for t in syn.get("richiede_tag", {}):
		if int(tg.get(t, 0)) < int(syn["richiede_tag"][t]):
			return false
	for t in syn.get("esclude_tag", {}):
		if int(tg.get(t, 0)) >= int(syn["esclude_tag"][t]):
			return false
	return true


# --- Solo test -----------------------------------------------------

## Sostituisce la lettura di SynergySources con un set di tag fisso.
func imposta_override_tag(d: Dictionary) -> void:
	_tag_override = d.duplicate(true)
