extends Node
## EndingSystem (fase 7, US-717). Valuta i finali (data/endings.json) e li
## sceglie: LETTORE puro, nessun `if` per un id di finale (FR-15). Le
## 'condizioni' di ogni finale sono il vocabolario chiuso di conditions.gd
## (FR-9): nessun tipo nuovo qui.
##
## Un'eccezione strutturale, non un id: un finale con eredita_profilo ==
## "ancore" richiede anche almeno un'Ancora viva (US-716) - non e' un tipo di
## condizione (conditions.gd non ne ha uno per "Ancore attive"), e' una
## regola generica sul PROFILO, applicata a qualunque finale lo dichiari.
##
## Il flag "rituale_sequenza_0_completato" (condizione dell'Apoteosi) lo pone
## QUESTO motore: RitualSystem.rituale_completato porta la Sequenza di
## PARTENZA del rituale (non quella di arrivo), quindi il vero controllo e'
## Progression.sequence() == 0 DOPO l'avanzamento.
##
## Al finale raggiunto: EndgameState.finale si aggiorna (round-trip nel save
## gia' garantito da US-701), il gioco entra in pausa sulla pagina del libro
## che mostra il finale (US-718 estende il colophon, non aggiunge un tipo di
## pagina nuovo). US-719: compone anche la parte automatica del contratto di
## eredita' (conoscenza sempre, reputazione se il profilo e' 'completo');
## Ancora e oggetto restano una scelta del giocatore (scegli_ancora/
## scegli_oggetto), applicata al nuovo personaggio da GameState.nuova_partita.
##
## NIENTE class_name: coerente col resto del progetto.

signal finale_raggiunto(id: String, gruppo: String)

const Conditions := preload("res://scripts/conditions.gd")
const FLAG_RITUALE_SEQ0 := "rituale_sequenza_0_completato"


func _ready() -> void:
	var m: Node = _n("/root/Madness")
	if m != null:
		m.connect("madness_changed", func(_v, _s): _rivaluta())
	var rs: Node = _n("/root/RitualSystem")
	if rs != null:
		rs.connect("rituale_completato", _su_rituale_completato)
	var ks: Node = _n("/root/KnowledgeStore")
	if ks != null:
		ks.connect("appreso", func(_f): _rivaluta())


# --- API ------------------------------------------------------------------

## L'id del finale con priorita' piu' alta le cui condizioni sono TUTTE
## soddisfatte, "" se nessuno. Pubblico per i test e per la rivalutazione.
func valuta() -> String:
	var gd: Node = _n("/root/GameData")
	if gd == null:
		return ""
	var migliore: String = ""
	var miglior_priorita: float = -INF
	for e in gd.call("get_endings"):
		var ed: Dictionary = e
		if not Conditions.tutte_soddisfatte(ed.get("condizioni", [])):
			continue
		if str(ed.get("eredita_profilo", "")) == "ancore" and _ancore_vive() == 0:
			continue
		var p: float = float(ed.get("priorita", 0))
		if p > miglior_priorita:
			miglior_priorita = p
			migliore = str(ed.get("id", ""))
	return migliore


func azzera() -> void:
	pass   # nessuno stato proprio: EndgameState.pulisci() basta per i test.


# --- Interno ----------------------------------------------------------

func _su_rituale_completato(_sequenza_di_partenza: int) -> void:
	var prog: Node = _n("/root/Progression")
	if prog != null and int(prog.call("sequence")) == 0:
		var ks: Node = _n("/root/KnowledgeStore")
		if ks != null:
			ks.call("imposta", FLAG_RITUALE_SEQ0, true)
	_rivaluta()


func _rivaluta() -> void:
	var eg: Node = _n("/root/EndgameState")
	if eg == null or not str(eg.get("finale")).is_empty():
		return   # gia' concluso: un finale non si sovrascrive
	var id: String = valuta()
	if not id.is_empty():
		_raggiungi(id)


func _raggiungi(id: String) -> void:
	var eg: Node = _n("/root/EndgameState")
	if eg == null:
		return
	eg.call("imposta_finale", id)
	eg.call("imposta_eredita", _componi_eredita_iniziale(id))
	var gruppo: String = _gruppo_corrente()
	finale_raggiunto.emit(id, gruppo)
	var book: Node = _n("/root/Book")
	if book != null:
		book.call("apri_a", "colophon")


## US-719, FR-14: la parte AUTOMATICA del contratto di eredita', compilata
## subito al finale. 'conoscenza' sempre; 'reputazione' solo pel profilo
## 'completo'. 'ancora' e 'oggetto' sono una SCELTA del giocatore alla
## schermata di finale (scegli_ancora/scegli_oggetto sotto): non c'e' modo
## corretto di sceglierli in automatico quando ce n'e' piu' di uno.
func _componi_eredita_iniziale(id: String) -> Dictionary:
	var gd: Node = _n("/root/GameData")
	var ending: Dictionary = gd.call("get_ending", id) if gd != null else {}
	var profilo: String = str(ending.get("eredita_profilo", ""))
	var out: Dictionary = {}

	var kn: Node = _n("/root/KnowledgeStore")
	if kn != null:
		var flags: Array = []
		for f in (kn.call("tutti") as Array):
			var s: String = str(f)
			if s.begins_with("pathway:") or s.begins_with("sequenza:"):
				flags.append(s)
		out["conoscenza"] = flags

	if profilo == "completo":
		var fs: Node = _n("/root/FactionSystem")
		if fs != null:
			var rep: Dictionary = {}
			for fid in (fs.call("per_salvataggio") as Dictionary):
				rep[fid] = float((fs.call("per_salvataggio") as Dictionary)[fid]) * 0.5
			out["reputazione"] = rep

	return out


## Sceglie l'Ancora da ereditare (profili 'ancore'/'completo'): deve essere
## una delle Ancore attive ADESSO. Passa a forza dimezzata (FR-14). false se
## l'id non e' un'Ancora attiva.
func scegli_ancora(anchor_id: String) -> bool:
	var eg: Node = _n("/root/EndgameState")
	var anc: Node = _n("/root/AnchorSystem")
	var gd: Node = _n("/root/GameData")
	if eg == null or anc == null or gd == null:
		return false
	if not (anc.call("active") as Array).has(anchor_id):
		return false
	var forza: float = float(anc.call("forza_di", anchor_id))
	var contratto: Dictionary = (eg.get("eredita") as Dictionary).duplicate(true)
	contratto["ancora"] = {"id": anchor_id, "forza": forza / 2.0}
	eg.call("imposta_eredita", contratto)
	return true


## Sceglie l'oggetto da ereditare (profilo 'completo'): deve essere posseduto
## ADESSO. false se non e' nell'inventario.
func scegli_oggetto(item_id: String) -> bool:
	var eg: Node = _n("/root/EndgameState")
	var inv: Node = _n("/root/Inventory")
	if eg == null or inv == null or not bool(inv.call("possiede", item_id, 1)):
		return false
	var contratto: Dictionary = (eg.get("eredita") as Dictionary).duplicate(true)
	contratto["oggetto"] = item_id
	eg.call("imposta_eredita", contratto)
	return true


func _gruppo_corrente() -> String:
	var prog: Node = _n("/root/Progression")
	var gd: Node = _n("/root/GameData")
	if prog == null or gd == null:
		return ""
	var pw: Dictionary = gd.call("get_pathway", str(prog.call("pathway")))
	return str(pw.get("group", ""))


func _ancore_vive() -> int:
	var anc: Node = _n("/root/AnchorSystem")
	return (anc.call("active") as Array).size() if anc != null else 0


func _n(path: String) -> Node:
	return get_node_or_null(path)
