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


func _ready() -> void:
	# Le fonti emettono gia' i loro segnali di cambiamento (fase 3). Un segnale
	# mancante e' un bug di quella fonte: si apre una micro-story, non un if qui.
	_collega("/root/Equipment", ["equip_cambiato"])
	_collega("/root/PetSystem", ["pet_impostato", "pet_liberato", "pet_morto",
			"bond_cambiato", "pet_avanzato"])
	_collega("/root/TalentSystem", ["talento_sbloccato"])
	_collega("/root/BaseSystem", ["stanza_costruita", "stanza_potenziata"])
	_collega("/root/Progression", ["sequence_changed"])


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


func pulisci() -> void:
	_tag_override = {}
	_attive_prec = []
	_accumulo = 0.0


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
