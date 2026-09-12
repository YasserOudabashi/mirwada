extends Node
## Concoction: combina una Caratteristica Beyonder con gli ingredienti per
## creare la pozione della Sequenza successiva, poi la si beve per avanzare.
##
## - concoct(formula_id, characteristic_id, ingredienti[]) -> crea la pozione
##   (completa o PARZIALE se mancano ingredienti, sopra la soglia della
##   formula), consumando la Caratteristica.
## - bevi(forza) -> se l'Acting e' completo, avanza; altrimenti la pozione e'
##   "digerita male" (fondamenta giu', follia su, nessun avanzamento) — a meno
##   che forza sia true (US-212: avanza comunque, malus pesante).
##
## NIENTE class_name: coerente col resto del progetto.

signal pozione_creata(sequenza_da: int, parziale: bool)
signal pozione_bevuta(avanzato: bool, forzato: bool)

var _pozione: Dictionary = {}


# --- Concoction --------------------------------------------------------

func concoct(formula_id: String, characteristic_id: String, ingredienti: Array) -> Dictionary:
	var gd: Node = get_node_or_null("/root/GameData")
	var formula: Dictionary = gd.call("get_formula", formula_id) if gd != null else {}
	if formula.is_empty():
		return {"ok": false, "reason": "formula_inesistente"}

	var seq_car: int = int(formula.get("characteristic_sequence", -1))
	var car: Dictionary = gd.call("get_characteristic", characteristic_id)
	if car.is_empty() or int(car.get("sequence", -99)) != seq_car:
		return {"ok": false, "reason": "caratteristica_incoerente"}

	var store: Node = get_node_or_null("/root/CharacteristicStore")
	if store == null or not store.call("possiede", characteristic_id):
		return {"ok": false, "reason": "caratteristica_mancante"}

	# Quanti ingredienti RICHIESTI sono fra quelli passati (distinti).
	var richiesti: Array = formula.get("ingredients", [])
	var presenti: Array = []
	for i in ingredienti:
		if richiesti.has(i) and not presenti.has(i):
			presenti.append(i)
	var soglia: int = int(formula.get("soglia_parziale", richiesti.size()))
	if presenti.size() < soglia:
		return {"ok": false, "reason": "ingredienti_insufficienti"}

	var parziale: bool = presenti.size() < richiesti.size()
	store.call("consuma", characteristic_id)

	_pozione = {
		"formula_id": formula_id,
		"da_sequenza": seq_car,   # si beve a questa Sequenza, porta a seq_car - 1
		"parziale": parziale,
		"penalita": formula.get("penalita_parziale", {}) if parziale else {},
	}
	pozione_creata.emit(seq_car, parziale)
	return {"ok": true, "reason": "ok", "pozione": _pozione.duplicate(true)}


func pozione_pronta() -> Dictionary:
	return _pozione.duplicate(true)


## true se c'e' una pozione per la Sequenza corrente e l'Acting e' completo:
## si puo' avanzare per via normale (US-212).
func avanzamento_disponibile() -> bool:
	if not _pozione_valida_per_ora():
		return false
	var acting: Node = get_node_or_null("/root/Acting")
	return acting != null and acting.call("e_completo")


## true se c'e' la pozione ma l'Acting non e' completo: si puo' solo FORZARE.
func avanzamento_forzabile() -> bool:
	if not _pozione_valida_per_ora():
		return false
	var acting: Node = get_node_or_null("/root/Acting")
	return acting == null or not acting.call("e_completo")


func _pozione_valida_per_ora() -> bool:
	if _pozione.is_empty():
		return false
	var prog: Node = get_node_or_null("/root/Progression")
	return prog != null and int(_pozione.get("da_sequenza", -1)) == int(prog.call("sequence"))


func scarta_pozione() -> void:
	_pozione = {}


# --- Bere -------------------------------------------------------------

## forza: se true e l'Acting non e' completo, avanza COMUNQUE con un malus
## pesante alle fondamenta (US-212). Se false, con Acting incompleto la
## pozione e' sprecata ("digerita male").
func bevi(forza: bool = false) -> Dictionary:
	if _pozione.is_empty():
		return {"ok": false, "reason": "nessuna_pozione"}

	var prog: Node = get_node_or_null("/root/Progression")
	if prog == null:
		return {"ok": false, "reason": "no_progression"}
	if int(_pozione.get("da_sequenza", -1)) != int(prog.call("sequence")):
		return {"ok": false, "reason": "pozione_per_un'altra_sequenza"}

	var acting: Node = get_node_or_null("/root/Acting")
	var completo: bool = acting != null and acting.call("e_completo")

	var found: Node = get_node_or_null("/root/Foundation")
	var madness: Node = get_node_or_null("/root/Madness")
	var seq_data: Dictionary = prog.call("sequence_data")
	var madness_on_force: float = float(seq_data.get("madness_on_force", 0.0))
	var mult: float = found.call("moltiplicatore_follia") if found != null else 1.0

	var esito: Dictionary = {"ok": true, "avanzato": false, "forzato": false, "follia": 0.0}

	# US-711: a un salto di fascia con una tribolazione aperta, l'avanzamento e'
	# rifiutato e la pozione NON si spreca (Progression.avanza gia' rifiuta;
	# qui non applichiamo malus ne' consumiamo la pozione).
	var trib: Node = get_node_or_null("/root/TribulationSystem")
	if (completo or forza) and trib != null and bool(trib.call("avanzamento_bloccato", int(prog.call("sequence")))):
		return {"ok": false, "reason": "tribolazione_in_corso"}

	if completo:
		prog.call("avanza")
		if found != null:
			found.call("applica", found.call("costante", "bonus_recitazione_completa"), "recitazione_completa")
		if _pozione.get("parziale", false) and madness != null:
			var pen: float = float((_pozione.get("penalita", {}) as Dictionary).get("follia_extra", 0.0)) * mult
			madness.call("add", pen, "pozione_parziale")
			esito["follia"] = pen
		esito["avanzato"] = true
	elif forza:
		prog.call("avanza")
		if found != null:
			# US-618: il malus e' attenuato dove la densita' mistica e' alta.
			found.call("applica", found.call("malus_forzatura"), "avanzamento_forzato")
		if madness != null:
			var f: float = madness_on_force * mult
			madness.call("add", f, "avanzamento_forzato")
			esito["follia"] = f
		esito["avanzato"] = true
		esito["forzato"] = true
	else:
		# Digerita male: niente avanzamento, penalita' contenuta.
		if found != null:
			found.call("applica", found.call("costante", "malus_digestione_difficile"), "pozione_digerita_male")
		if madness != null:
			var d: float = madness_on_force * mult
			madness.call("add", d, "pozione_digerita_male")
			esito["follia"] = d

	_pozione = {}
	pozione_bevuta.emit(esito["avanzato"], esito["forzato"])
	return esito


# --- Alchimia delle pozioni CONSUMABILI (US-310) --------------------------
# Percorso separato dalla concoction di avanzamento qui sopra: si prepara una
# ricetta di data/potions/recipes.json e si ottiene un item nell'inventario
# con una qualita'. La qualita' base della ricetta sale col laboratorio
# (US-326/327) e coi talenti di alchimia (US-329), scende con ingredienti
# scadenti; finche' quei sistemi non esistono il bonus e' 0.

signal pozione_preparata(recipe_id: String, item_id: String, qualita: String)


## true se la ricetta e' utilizzabile: tier 'base' (nota da subito) oppure
## un flag KnowledgeStore 'ricetta:<id>' (avanzata scoperta / leggendaria appresa).
func ricetta_nota(recipe_id: String) -> bool:
	var gd: Node = _gd()
	var r: Dictionary = gd.call("get_recipe", recipe_id) if gd != null else {}
	if r.is_empty():
		return false
	if bool(r.get("nota_da_subito", false)):
		return true
	var kn: Node = get_node_or_null("/root/KnowledgeStore")
	if kn != null and bool(kn.call("conosce", "ricetta:" + recipe_id)):
		return true
	# US-327: la biblioteca rende note le prime N ricette 'avanzata' (in ordine
	# stabile) senza doverle sperimentare. N = bonus 'ricette_avanzate_note'.
	if str(r.get("tier", "")) == "avanzata":
		var quante: int = _bonus_stanza("biblioteca", "ricette_avanzate_note")
		if quante > 0:
			var idx: int = (gd.call("recipes_per_tier", "avanzata") as Array).find(recipe_id)
			if idx >= 0 and idx < quante:
				return true
	return false


## Prepara una ricetta nota consumando gli ingredienti dall'inventario.
## ignora_scoperta (fase 11, US-1106): un NPC alchimista conosce la SUA
## ricetta a prescindere da cosa il giocatore ha scoperto - salta
## ricetta_nota(). Default false: nessuna regressione sull'alchimia del
## giocatore.
##   -> { ok, reason, item_id, qualita }
func prepara(recipe_id: String, ignora_scoperta: bool = false) -> Dictionary:
	var gd: Node = _gd()
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null:
		return {"ok": false, "reason": "sistema_assente"}
	var r: Dictionary = gd.call("get_recipe", recipe_id)
	if r.is_empty():
		return {"ok": false, "reason": "ricetta_inesistente"}
	if not ignora_scoperta and not ricetta_nota(recipe_id):
		return {"ok": false, "reason": "ricetta_ignota"}
	var ingr: Dictionary = r.get("ingredienti", {})
	for item_id in ingr:
		if inv.call("conta", item_id) < int(ingr[item_id]):
			return {"ok": false, "reason": "ingredienti_mancanti"}
	# tutto presente: consuma e produce
	for item_id in ingr:
		inv.call("rimuovi", item_id, int(ingr[item_id]))
	var qualita: String = _qualita_finale(r)
	var out_id: String = str(r.get("output", {}).get("item_id", ""))
	if not out_id.is_empty():
		inv.call("aggiungi", out_id, 1)
		_traccia_item_crafted(out_id, qualita)
	pozione_preparata.emit(recipe_id, out_id, qualita)
	return {"ok": true, "reason": "", "item_id": out_id, "qualita": qualita}


## US-804: un oggetto e' stato prodotto (tracked_events.json: categoria,
## qualita_min). "categoria" viene dai dati dell'item stesso, mai scritta
## qui. Condiviso da prepara() (questa) e Forge.forgia().
func _traccia_item_crafted(item_id: String, qualita: String) -> void:
	var et: Node = get_node_or_null("/root/EventTracker")
	if et == null:
		return
	var gd: Node = _gd()
	var item: Dictionary = gd.call("get_item", item_id) if gd != null else {}
	et.call("emit_event", "item_crafted",
		{"categoria": str(item.get("categoria", "")), "qualita": qualita})


signal esperimento_fallito(esito: String)

var _rng: RandomNumberGenerator = null


## Combina una manciata di ingredienti (Array di item_id, con ripetizioni)
## senza una ricetta. Se il multiset corrisponde esattamente a una ricetta
## 'avanzata' non ancora nota -> la si SCOPRE (flag KnowledgeStore) e la
## pozione e' prodotta. Altrimenti -> FALLIMENTO: esito pesato da
## data/potions/experiment_outcomes.json. Gli ingredienti si consumano SEMPRE
## (se li hai). RNG seedabile con imposta_seed().
##   -> { ok, esito, ... }   esito: "scoperta" | "ingredienti_mancanti" | <outcome>
func sperimenta(ingredienti: Array) -> Dictionary:
	var gd: Node = _gd()
	var inv: Node = get_node_or_null("/root/Inventory")
	if gd == null or inv == null or ingredienti.is_empty():
		return {"ok": false, "esito": "input_non_valido"}

	var richiesti: Dictionary = _multiset(ingredienti)
	for item_id in richiesti:
		if inv.call("conta", item_id) < int(richiesti[item_id]):
			return {"ok": false, "esito": "ingredienti_mancanti"}
	for item_id in richiesti:
		inv.call("rimuovi", item_id, int(richiesti[item_id]))

	# corrisponde a una ricetta avanzata non ancora nota?
	for rid in gd.call("recipes_per_tier", "avanzata"):
		if ricetta_nota(rid):
			continue
		if _multiset_eq(richiesti, gd.call("get_recipe", rid).get("ingredienti", {})):
			var kn: Node = get_node_or_null("/root/KnowledgeStore")
			if kn != null:
				kn.call("impara", "ricetta:" + rid)
			var r: Dictionary = gd.call("get_recipe", rid)
			var out_id: String = str(r.get("output", {}).get("item_id", ""))
			var q: String = _qualita_finale(r)
			if not out_id.is_empty():
				inv.call("aggiungi", out_id, 1)
			return {"ok": true, "esito": "scoperta", "recipe_id": rid, "item_id": out_id, "qualita": q}

	# nessuna corrispondenza: fallimento pesato
	return _fallimento(gd)


func imposta_seed(s: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = s


## Applica un esito di esperimento a comando (scena di debug, test).
func forza_esito(nome: String) -> void:
	var gd: Node = _gd()
	var o: Dictionary = gd.call("experiment_outcomes").get(nome, {}) if gd != null else {}
	_applica_esito(nome, o)
	esperimento_fallito.emit(nome)


func _fallimento(gd: Node) -> Dictionary:
	var outcomes: Dictionary = gd.call("experiment_outcomes")
	var mult: float = 1.0
	var found: Node = get_node_or_null("/root/Foundation")
	if found != null:
		mult = float(found.call("moltiplicatore_follia"))
	var riduzione: float = _riduzione_rischio()

	var pesi: Dictionary = {}
	var totale: float = 0.0
	for nome in outcomes:
		var o: Dictionary = outcomes[nome]
		var p: float = float(o.get("peso", 0))
		if bool(o.get("mostruoso", false)):
			p = p * mult * (1.0 - clampf(riduzione, 0.0, 0.95))
		pesi[nome] = maxf(0.0, p)
		totale += pesi[nome]

	if _rng == null:
		_rng = RandomNumberGenerator.new()
	var tiro: float = _rng.randf() * totale
	var scelto: String = "fumo"
	for nome in pesi:
		tiro -= pesi[nome]
		if tiro <= 0.0:
			scelto = nome
			break

	_applica_esito(scelto, outcomes.get(scelto, {}))
	esperimento_fallito.emit(scelto)
	return {"ok": true, "esito": scelto}


func _applica_esito(nome: String, o: Dictionary) -> void:
	var inv: Node = get_node_or_null("/root/Inventory")
	if o.has("produce") and inv != null:
		inv.call("aggiungi", str(o["produce"]), 1)
	if o.has("follia"):
		var m: Node = get_node_or_null("/root/Madness")
		if m != null:
			m.call("add", float(o["follia"]), "esperimento_alchemico")
	if o.has("danno"):
		var p: Node = get_tree().get_first_node_in_group("player")
		var st: Node = p.get_node_or_null("StatsComponent") if p != null else null
		if st != null:
			st.set("hp", maxf(0.0, float(st.get("hp")) - float(o["danno"])))
	# o.has("evoca") -> l'aberrazione la gestisce US-312 (_evoca_aberrazione)
	if o.has("evoca"):
		_evoca_aberrazione(str(o["evoca"]))


## US-312: l'esito peggiore di un esperimento. Evoca un'entita' ostile
## TEMPORANEA (non entra nel save), aggiunge follia e degrada le fondamenta.
## Numeri da balance.json.alchimia.
func _evoca_aberrazione(entita_id: String) -> void:
	var gd: Node = _gd()
	var b: Dictionary = gd.call("get_balance", "alchimia") if gd != null else {}
	var reg: Node = get_node_or_null("/root/SummonRegistry")
	if reg != null:
		reg.call("evoca_temporanea", entita_id, "ostile",
			float(b.get("aberrazione_durata_s", 25.0)), float(b.get("aberrazione_hp", 30.0)))
	var m: Node = get_node_or_null("/root/Madness")
	if m != null:
		m.call("add", float(b.get("follia_aberrazione", 12.0)), "aberrazione_alchemica")
	var found: Node = get_node_or_null("/root/Foundation")
	if found != null:
		found.call("applica", float(b.get("malus_fondamenta_aberrazione", -15.0)), "aberrazione_alchemica")


## rischio_esperimento (laboratorio) e alchimia_rischio (talento) sono NEGATIVI
## nei dati: -20 = "il rischio scende di 20 punti". Qui li si gira in una
## riduzione POSITIVA in [0, 1] che _fallimento sottrae dal peso mostruoso.
func _riduzione_rischio() -> float:
	return -(float(_bonus_stanza("laboratorio", "rischio_esperimento"))
		+ float(_bonus_talento("alchimia_rischio"))) / 100.0


func _multiset(a: Array) -> Dictionary:
	var m: Dictionary = {}
	for x in a:
		m[str(x)] = int(m.get(str(x), 0)) + 1
	return m


func _multiset_eq(a: Dictionary, b: Variant) -> bool:
	if typeof(b) != TYPE_DICTIONARY or a.size() != (b as Dictionary).size():
		return false
	for k in a:
		if int(a[k]) != int((b as Dictionary).get(k, -1)):
			return false
	return true


func _qualita_finale(r: Dictionary) -> String:
	var scala: Array = _gd().call("potion_quality")
	var base: int = maxi(0, scala.find(str(r.get("qualita_base", "pura"))))
	var bonus: int = _bonus_stanza("laboratorio", "qualita_pozione") \
		+ _bonus_talento("alchimia_qualita") + _bonus_sinergia("pozioni")
	return str(scala[clampi(base + bonus, 0, scala.size() - 1)])


## Passi di qualita' dalla sinergia attiva (US-404). 0 se SynergyEngine assente.
func _bonus_sinergia(categoria: String) -> int:
	var se: Node = get_node_or_null("/root/SynergyEngine")
	return int(se.call("bonus_qualita", categoria)) if se != null else 0


func _bonus_stanza(tipo: String, chiave: String) -> int:
	var bs: Node = get_node_or_null("/root/BaseSystem")
	if bs == null:
		return 0
	return int((bs.call("bonus", tipo) as Dictionary).get(chiave, 0))


func _bonus_talento(chiave: String) -> int:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	if ts == null or not ts.has_method("bonus_int"):
		return 0
	return int(ts.call("bonus_int", chiave))


func _gd() -> Node:
	return get_node_or_null("/root/GameData")
