extends Node
## Esegue un'abilita' letta dai dati.
##
## Il codice non sa nulla di quali abilita' esistano: legge l'array "primitive"
## dal JSON e chiama il gestore registrato per ogni "tipo". Aggiungere
## un'abilita' e' un dato; aggiungere una PRIMITIVA e' codice, e il registro
## in data/schema/primitives.json e' chiuso.
##
## Tre esiti distinti per una primitiva, e vanno tenuti separati:
##   - implementata      -> eseguita
##   - nel registro ma non ancora implementata -> avviso, l'abilita' prosegue
##   - fuori dal registro -> ERRORE: e' un bug nei dati, non un caso da gestire

signal ability_executed(ability_id: String, caster: Node, result: Dictionary)
## US-505: reveal_info ha rivelato qualcosa. Il consumatore (HUD/libro, world
## state) si aggancia in fase 6.
signal info_rivelata(categoria: String, raggio: float, origine: Vector2)
## US-608: illusion ha creato un inganno percettivo (esche, danno percepito,
## cancellazione). Il consumatore vero (IA che ci casca, tell visivo sulle
## esche) e' combat/fase 6.
signal illusione_creata(tipo_illusione: String, raggio: float, origine: Vector2)

## Motivi di rifiuto, come costanti: i test e la UI non devono confrontare
## stringhe scritte a mano.
const OK := "ok"
const ERR_SCONOSCIUTA := "abilita_sconosciuta"
const ERR_COOLDOWN := "in_cooldown"
const ERR_SPIRITUALITA := "spiritualita_insufficiente"
const ERR_NO_STATS := "caster_senza_stats"
const ERR_NON_POSSEDUTA := "abilita_non_posseduta"
## US-605: una condizione dell'abilita' (e_notte, fase_lunare, ...) non e'
## soddisfatta. Rifiuto SENZA pagare il costo, come spiritualita_insufficiente.
const ERR_CONDIZIONE := "condizione_non_soddisfatta"

const Conditions := preload("res://scripts/conditions.gd")

## Chiave "<instance_id>:<ability_id>" -> istante di fine in ms. Le voci dei
## caster non piu' validi o gia' scadute vengono rimosse da sweep_cooldowns():
## senza, una partita lunga accumulerebbe una voce per ogni entita' morta.
var _cooldowns: Dictionary = {}
const _SWEEP_OGNI_MS := 5000
var _prossimo_sweep_ms: int = 0

## Abilita' PRESTATE (US-204): "<instance_id>:<ability_id>" -> istante di fine
## in ms. Un caster puo' eseguire un'abilita' fuori dal suo Pathway finche' il
## prestito e' valido. Stress test: Error (Sequenza 6) usa abilita' altrui.
var _granted: Dictionary = {}
## Abilita' prestate a tempo INDETERMINATO (US-404: mentre una sinergia e'
## attiva). { "<instance_id>:<ability_id>": true }. Non scadono in _sweep.
var _permanenti: Dictionary = {}

var _handlers: Dictionary = {}
## Effetti a tempo in corso. Una lista processata in _process invece di
## await su SceneTreeTimer: gli await lasciano timer appesi se la partita
## finisce prima della scadenza, e non sono ispezionabili dai test.
var _pending: Array = []


func _ready() -> void:
	_handlers = {
		"projectile": _p_projectile,
		"melee_arc": _p_melee_arc,
		"buff_stat": _p_buff_stat,
		"heal": _p_heal,
		"dash": _p_dash,
		"shield": _p_shield,
		"aura": _p_aura,
		"dot": _p_dot,
		"decay": _p_decay,
		"debuff_stat": _p_debuff_stat,
		"light_purify": _p_light_purify,
		"transform": _p_transform,
		"terrain_modify": _p_terrain_modify,
		"curse": _p_curse,
		"summon": _p_summon,
		"fear": _p_fear,
		"reveal_info": _p_reveal_info,
		"teleport": _p_teleport,
		"soul_detach": _p_soul_detach,
		"resurrect": _p_resurrect,
		"plant_growth": _p_plant_growth,
		"mind_read": _p_mind_read,
		"shadow_meld": _p_shadow_meld,
		"illusion": _p_illusion,
		"steal": _p_steal,
		"possess": _p_possess,
	}


## I tipi di primitiva che il motore implementa davvero (hanno un handler).
## Le altre primitive del registro sono attive ma non ancora scritte (fase 5).
func tipi_primitiva_implementati() -> Array:
	return _handlers.keys()


## Esegue l'abilita' sul caster. Non solleva mai: l'esito sta nel Dictionary
##   { ok, reason, effects: Array, warnings: PackedStringArray }
func execute(ability_id: String, caster: Node) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason": "", "effects": [], "warnings": PackedStringArray(),
	}

	var ability: Dictionary = _game_data().call("get_ability", ability_id)
	if ability.is_empty():
		result["reason"] = ERR_SCONOSCIUTA
		push_error("[AbilityEngine] abilita' inesistente: %s" % ability_id)
		return result

	var stats: Node = find_stats(caster)
	if stats == null:
		result["reason"] = ERR_NO_STATS
		push_error("[AbilityEngine] %s non ha uno StatsComponent" % caster)
		return result

	# Il giocatore puo' lanciare solo le abilita' del suo Pathway o quelle
	# prestate e ancora valide (US-204). Ogni altro caster (nemici, manichini,
	# test) non ha un Pathway noto: nessuna restrizione.
	if not _puo_lanciare(caster, ability_id):
		result["reason"] = ERR_NON_POSSEDUTA
		return result

	if is_on_cooldown(caster, ability_id):
		result["reason"] = ERR_COOLDOWN
		return result

	# US-605: le condizioni (e_notte, fase_lunare, in_zona_tag, tier_min, ...)
	# valgono SOLO col giocatore in scena. Un caster senza contesto (nemici,
	# test isolati) non e' soggetto, come per l'ownership. Non soddisfatta ->
	# rifiuto SENZA pagare il costo. execute_stored NON passa di qui: l'oggetto
	# e' gia' il permesso.
	if caster != null and caster.is_in_group("player") \
			and not Conditions.tutte_soddisfatte(ability.get("condizioni", [])):
		result["reason"] = ERR_CONDIZIONE
		return result

	# Il costo si paga PRIMA di eseguire, e se non basta non si esegue niente:
	# meglio un'abilita' che non parte che una che parte a meta'.
	var cost: float = _num(ability.get("costo_spiritualita"), 0.0)
	if not stats.call("spend_spiritualita", cost):
		result["reason"] = ERR_SPIRITUALITA
		return result

	_start_cooldown(caster, ability_id, _num(ability.get("cooldown"), 0.0))

	_esegui_primitive(ability, caster, stats, ability_id, result)

	result["ok"] = true
	result["reason"] = OK
	# US-210B: un'abilita' eseguita con successo e' un evento tracciato.
	var et: Node = get_tree().root.get_node_or_null("EventTracker")
	if et != null:
		et.call("emit_event", "ability_used", {"ability_id": ability_id})
	ability_executed.emit(ability_id, caster, result)
	return result


## Esegue l'abilita' "portata da un oggetto" al consumo (US-206): come se il
## consumer la possedesse, UNA volta, SENZA costo di spiritualita' ne'
## cooldown (l'oggetto e' gia' il costo, e il sistema inventario di fase 3
## garantisce il singolo uso consumando l'oggetto). Nessun controllo di
## ownership: l'abilita' e' dell'oggetto, non del consumer. Percorso parallelo
## a execute(), condivide solo il motore delle primitive.
func execute_stored(stored_ability_id: String, consumer: Node) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason": "", "effects": [], "warnings": PackedStringArray(),
	}

	var ability: Dictionary = _game_data().call("get_ability", stored_ability_id)
	if ability.is_empty():
		result["reason"] = ERR_SCONOSCIUTA
		push_error("[AbilityEngine] execute_stored: abilita' inesistente '%s'" % stored_ability_id)
		return result

	var stats: Node = find_stats(consumer)
	if stats == null:
		result["reason"] = ERR_NO_STATS
		push_error("[AbilityEngine] execute_stored: %s non ha uno StatsComponent" % consumer)
		return result

	_esegui_primitive(ability, consumer, stats, stored_ability_id, result)
	result["ok"] = true
	result["reason"] = OK
	var tt: Node = get_node_or_null("/root/TalentTracker")
	if tt != null:
		tt.call("registra", "abilita_prestate_usate", 1.0)  # emettitore US-331
	ability_executed.emit(stored_ability_id, consumer, result)
	return result


## Il motore delle primitive, condiviso da execute() e execute_stored():
## itera l'array "primitive", dispaccia sulla tabella tipo->handler, e
## distingue i TRE esiti (implementata / nel registro ma non scritta / fuori
## registro). Riempie result["effects"] e result["warnings"].
func _esegui_primitive(ability: Dictionary, caster: Node, stats: Node, ability_id: String, result: Dictionary) -> void:
	var prim_list: Variant = ability.get("primitive", [])
	if typeof(prim_list) != TYPE_ARRAY:
		push_error("[AbilityEngine] %s: 'primitive' non e' una lista, abilita' senza effetti" % ability_id)
		result["warnings"].append("'primitive' non e' una lista")
		prim_list = []

	for entry in prim_list:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("[AbilityEngine] %s: primitiva non-oggetto scartata (%s)" % [ability_id, entry])
			result["warnings"].append("primitiva non-oggetto scartata")
			continue
		# COPIA: le sinergie modifica_primitiva (US-405) alterano i parametri
		# prima dell'handler, ma i dati dell'abilita' non si toccano mai.
		var prim: Dictionary = (entry as Dictionary).duplicate(true)
		var tipo: String = str(prim.get("tipo", ""))
		var se: Node = get_tree().root.get_node_or_null("SynergyEngine")
		if se != null:
			se.call("applica_modifiche_primitiva", tipo, prim)

		if not _handlers.has(tipo):
			if (_game_data().call("get_primitive", tipo) as Dictionary).is_empty():
				# Fuori dal registro chiuso: i dati sono rotti.
				push_error("[AbilityEngine] %s: primitiva FUORI REGISTRO '%s'" % [ability_id, tipo])
				result["warnings"].append("primitiva fuori registro: %s" % tipo)
			else:
				# Nel registro ma non ancora scritta: previsto, l'abilita' prosegue.
				push_warning("[AbilityEngine] %s: primitiva '%s' non ancora implementata" % [ability_id, tipo])
				result["warnings"].append("non implementata: %s" % tipo)
			continue

		var handler: Callable = _handlers[tipo]
		var effect: Dictionary = handler.call(prim, caster, stats, ability_id)
		(result["effects"] as Array).append(effect)


## Esegue UNA primitiva isolata, saltando costo e cooldown. Per la scena di
## debug (US-018) e i test: NON e' un'abilita', l'origine e' "debug:<tipo>".
func esegui_primitiva(tipo: String, prim: Dictionary, caster: Node) -> Dictionary:
	if not _handlers.has(tipo):
		return {"ok": false, "tipo": tipo, "reason": "primitiva non gestita"}
	var stats: Node = find_stats(caster)
	var effetto: Dictionary = (_handlers[tipo] as Callable).call(prim, caster, stats, "debug:" + tipo)
	effetto["ok"] = true
	return effetto


## Lo StatsComponent del caster: il nodo stesso se lo e', altrimenti un figlio.
func find_stats(caster: Node) -> Node:
	if caster == null:
		return null
	if caster.has_method("spend_spiritualita"):
		return caster
	for child in caster.get_children():
		if child.has_method("spend_spiritualita"):
			return child
	return null


# --- Cooldown ----------------------------------------------------------------

func is_on_cooldown(caster: Node, ability_id: String) -> bool:
	var key: String = _key(caster, ability_id)
	if not _cooldowns.has(key):
		return false
	return Time.get_ticks_msec() < int(_cooldowns[key])


func cooldown_left(caster: Node, ability_id: String) -> float:
	var key: String = _key(caster, ability_id)
	if not _cooldowns.has(key):
		return 0.0
	var left: float = (float(_cooldowns[key]) - float(Time.get_ticks_msec())) / 1000.0
	return maxf(left, 0.0)


func clear_cooldowns() -> void:
	_cooldowns.clear()


func cooldown_entries() -> int:
	return _cooldowns.size()


## Rimuove le voci scadute e quelle dei caster non piu' esistenti. Pubblica:
## i test la chiamano invece di aspettare l'intervallo di _process.
func sweep_cooldowns() -> void:
	_sweep(_cooldowns)
	_sweep(_granted)


func _sweep(index: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	for key in index.keys():
		var scaduta: bool = now >= int(index[key])
		var iid: int = str(key).get_slice(":", 0).to_int()
		if scaduta or not is_instance_id_valid(iid):
			index.erase(key)


# --- Abilita' prestate (US-204) --------------------------------------------

## Presta un'abilita' al caster per "durata" secondi: execute() la accettera'
## anche se non e' nel suo Pathway. false se l'ability_id non esiste.
func grant_temporary(ability_id: String, caster: Node, durata: float) -> bool:
	if caster == null or (_game_data().call("get_ability", ability_id) as Dictionary).is_empty():
		push_error("[AbilityEngine] grant_temporary: abilita' inesistente '%s'" % ability_id)
		return false
	var key: String = _key(caster, ability_id)
	_granted[key] = Time.get_ticks_msec() + int(maxf(durata, 0.0) * 1000.0)
	_pending.append({"kind": "grant_expire", "caster": caster, "key": key,
			"left": maxf(durata, 0.001)})
	return true


func is_granted(caster: Node, ability_id: String) -> bool:
	var key: String = _key(caster, ability_id)
	if _permanenti.has(key):
		return true
	return _granted.has(key) and Time.get_ticks_msec() < int(_granted[key])


## Presta un'abilita' al GIOCATORE a tempo indeterminato (US-404: finche' una
## sinergia resta attiva). Nessuna scadenza a tempo: si toglie con
## revoca_permanente(). false se l'ability_id non esiste o non c'e' un player.
func grant_permanente(ability_id: String) -> bool:
	if (_game_data().call("get_ability", ability_id) as Dictionary).is_empty():
		push_error("[AbilityEngine] grant_permanente: abilita' inesistente '%s'" % ability_id)
		return false
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	_permanenti[_key(p, ability_id)] = true
	return true


func revoca_permanente(ability_id: String) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null:
		_permanenti.erase(_key(p, ability_id))


## Gli id delle abilita' ancora prestate a questo caster.
func granted_abilities(caster: Node) -> Array:
	var out: Array = []
	if caster == null:
		return out
	var prefisso: String = "%d:" % caster.get_instance_id()
	var now: int = Time.get_ticks_msec()
	for key in _granted:
		var k: String = key
		if k.begins_with(prefisso) and now < int(_granted[key]):
			out.append(k.substr(prefisso.length()))
	for key in _permanenti:
		if str(key).begins_with(prefisso):
			out.append(str(key).substr(prefisso.length()))
	return out


func clear_granted() -> void:
	_granted.clear()
	_permanenti.clear()


## Abilita' che il caster POSSIEDE: solo per il giocatore con un Pathway
## attivo (le abilita' delle Sequenze da 9 fino alla corrente). Per ogni
## altro caster e' [] = "non lo so", e allora execute() non pone limiti.
func owned_abilities(caster: Node) -> Array:
	if caster == null or not caster.is_in_group("player"):
		return []
	var prog: Node = get_tree().root.get_node_or_null("Progression")
	if prog == null:
		return []
	var pid: String = prog.call("pathway")
	if pid.is_empty():
		return []
	var seq_corrente: int = prog.call("sequence")
	var out: Array = []
	for s in range(9, seq_corrente - 1, -1):
		var sd: Dictionary = _game_data().call("get_sequence", "%s_%d" % [pid, s])
		for a in sd.get("abilities", []):
			out.append(str(a))
	return out


func _puo_lanciare(caster: Node, ability_id: String) -> bool:
	var posseduto: Array = owned_abilities(caster)
	if posseduto.is_empty():
		return true  # ownership sconosciuta: nessuna restrizione
	return ability_id in posseduto or is_granted(caster, ability_id)


func _start_cooldown(caster: Node, ability_id: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_cooldowns[_key(caster, ability_id)] = Time.get_ticks_msec() + int(seconds * 1000.0)


func _key(caster: Node, ability_id: String) -> String:
	return "%d:%s" % [caster.get_instance_id(), ability_id]


# --- Primitive ---------------------------------------------------------------
# Ogni gestore riceve i parametri grezzi dal JSON e restituisce un record di
# cio' che ha fatto. I default servono a non esplodere su un dato incompleto.
#
# I parametri arrivano da JSON in chiaro: un valore del tipo sbagliato non deve
# arrivare a float()/int() (che sollevano "Nonexistent constructor" su un
# Dictionary/Array). _num e _flag coercono con un default sano.

static func _num(v: Variant, fallback: float) -> float:
	var t: int = typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return v
	if t == TYPE_STRING and (v as String).is_valid_float():
		return float(v)
	return fallback


static func _flag(v: Variant, fallback: bool) -> bool:
	return v if typeof(v) == TYPE_BOOL else fallback

func _p_buff_stat(prim: Dictionary, _caster: Node, stats: Node, ability_id: String) -> Dictionary:
	return _mod_stat(prim, stats, ability_id, "buff_stat", false)


## debuff_stat: speculare a buff_stat (US-013). Stesso motore di modificatori
## per id; il valore dei dati e' gia' negativo, non lo si forza qui. id
## separato ("<abilita>:debuff:<stat>") cosi' un'abilita' che buffa e debuffa
## la stessa stat non si sovrascrive; l'effetto e' marcato debuff cosi'
## light_purify lo riconosce.
func _p_debuff_stat(prim: Dictionary, _caster: Node, stats: Node, ability_id: String) -> Dictionary:
	return _mod_stat(prim, stats, ability_id, "debuff_stat", true)


func _mod_stat(prim: Dictionary, stats: Node, ability_id: String, tipo: String, debuff: bool) -> Dictionary:
	var stat: String = str(prim.get("stat", ""))
	var valore: float = _num(prim.get("valore"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var moltiplicativo: bool = _flag(prim.get("moltiplicativo"), false)

	# I modificatori sono additivi: un moltiplicativo diventa il delta
	# equivalente sulla base, cosi' resta rimovibile per id come gli altri.
	var delta: float = valore
	if moltiplicativo:
		delta = float(stats.call("get_base", stat)) * valore

	# id derivato da abilita' + stat: riapplicare rinfresca invece di impilare.
	var mod_id: String = "%s:debuff:%s" % [ability_id, stat] if debuff else "%s:%s" % [ability_id, stat]
	stats.call("apply_modifier", mod_id, {stat: delta})

	if durata > 0.0:
		_pending.append({
			"kind": "expire", "stats": stats, "mod_id": mod_id, "left": durata,
			"debuff": debuff,
		})

	return {"tipo": tipo, "stat": stat, "delta": delta,
			"durata": durata, "modifier_id": mod_id, "debuff": debuff}


## light_purify: toglie gli effetti negativi a tempo (dot, decay, debuff_stat)
## dal bersaglio, fino a "potenza" effetti. "per tag" del PRD non ha un
## parametro nel registro (params: raggio, potenza, riduce_sequenza): la
## purifica va per numero, non per tag. raggio e riduce_sequenza sono
## registrati; la purifica d'area su piu' entita' arriva con l'integrazione
## combat.
func _p_light_purify(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var potenza: int = int(_num(prim.get("potenza"), 1.0))
	var riduce_sequenza: bool = _flag(prim.get("riduce_sequenza"), false)

	var rimossi: int = 0
	var superstiti: Array = []
	for entry in _pending:
		var e: Dictionary = entry
		var negativo: bool = str(e["kind"]) in ["dot", "decay"] or e.get("debuff", false)
		var mio: bool = e.get("stats", null) == stats
		if negativo and mio and rimossi < potenza:
			if str(e["kind"]) == "expire":
				stats.call("remove_modifier", str(e["mod_id"]))
			rimossi += 1
			continue
		superstiti.append(e)
	_pending = superstiti

	# US-218C: rimuove anche gli status negativi, PER TAG (come dice il PRD).
	if stats != null and stats.has_method("status_attivi"):
		var gd: Node = _game_data()
		for sid in (stats.call("status_attivi") as Array).duplicate():
			if rimossi >= potenza:
				break
			if bool((gd.call("get_status_effect", sid) as Dictionary).get("negativo", false)):
				stats.call("rimuovi_status", sid)
				rimossi += 1

	return {"tipo": "light_purify", "raggio": raggio, "potenza": potenza,
			"riduce_sequenza": riduce_sequenza, "rimossi": rimossi}


## transform: cambia forma applicando gli stat_modifiers di una forma definita
## in data/forms.json (get_form). id del modificatore "transform:<ability_id>",
## rimosso alla scadenza (durata), su richiesta (annulla_transform) o quando
## costo_al_secondo esaurisce la spiritualita'. Reversibile: e' un modificatore
## per id come un buff.
func _p_transform(prim: Dictionary, _caster: Node, stats: Node, ability_id: String) -> Dictionary:
	var forma_id: String = str(prim.get("forma_id", ""))
	var durata: float = _num(prim.get("durata"), 0.0)
	var costo_al_secondo: float = _num(prim.get("costo_al_secondo"), 0.0)

	var rec: Dictionary = {"tipo": "transform", "forma_id": forma_id,
			"durata": durata, "costo_al_secondo": costo_al_secondo}

	var forma: Dictionary = _game_data().call("get_form", forma_id)
	if forma.is_empty():
		push_error("[AbilityEngine] transform: forma inesistente '%s' (il validator deve intercettarlo)" % forma_id)
		rec["applied"] = false
		return rec

	var mods_raw: Variant = forma.get("stat_modifiers")
	var mods: Dictionary = mods_raw if typeof(mods_raw) == TYPE_DICTIONARY else {}
	var mod_id: String = "transform:%s" % ability_id
	stats.call("apply_modifier", mod_id, mods)
	rec["applied"] = true
	rec["modifier_id"] = mod_id
	rec["stat_modifiers"] = mods

	# Con durata > 0 scade a tempo. Con solo costo_al_secondo dura finche' c'e'
	# spiritualita': entry persistente col drenaggio che la conclude.
	if durata > 0.0 or costo_al_secondo > 0.0:
		_pending.append({
			"kind": "transform", "stats": stats, "mod_id": mod_id,
			"left": maxf(durata, 0.0), "persistente": durata <= 0.0,
			"costo_al_secondo": costo_al_secondo,
		})
	return rec


## terrain_modify: con permanente:true incide la modifica nello stato del
## mondo (WorldState), che la serializza nel save — un varco aperto resta
## aperto (design-world.md cap. 4). Con permanente:false e' un effetto a
## tempo sulla coda _pending. La modifica vera al tilemap la applichera' il
## sistema del mondo di fase 6 leggendo WorldState.
func _p_terrain_modify(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var tipo_modifica: String = str(prim.get("tipo_modifica", ""))
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var permanente: bool = _flag(prim.get("permanente"), false)

	var pos: Vector2 = Vector2.ZERO
	if caster is Node2D and (caster as Node2D).is_inside_tree():
		pos = (caster as Node2D).global_position

	var rec: Dictionary = {"tipo": "terrain_modify", "tipo_modifica": tipo_modifica,
			"raggio": raggio, "durata": durata, "permanente": permanente,
			"posizione": [pos.x, pos.y]}

	if permanente:
		var ws: Node = get_tree().root.get_node_or_null("WorldState")
		if ws != null:
			ws.call("registra_terreno", tipo_modifica, pos, raggio)
			rec["applied"] = true
		else:
			rec["applied"] = false
	else:
		rec["applied"] = true
		if durata > 0.0:
			_pending.append({"kind": "terrain_temp", "caster": caster, "left": durata,
					"tipo_modifica": tipo_modifica, "raggio": raggio})
		# US-607: 'oscurita' e' un tipo_modifica che il ciclo del tempo legge
		# come notte LOCALE - come 'permanente:true' instrada a WorldState,
		# non e' un caso speciale per un Pathway. Il Nightwatcher del Darkness
		# accende cosi' i suoi poteri notturni anche di giorno.
		if tipo_modifica == "oscurita" and durata > 0.0:
			var ts: Node = get_tree().root.get_node_or_null("TimeSystem")
			if ts != null and ts.has_method("crea_oscurita"):
				ts.call("crea_oscurita", pos, raggio, durata)
	return rec


## curse: applica una maledizione al bersaglio. Non c'e' ancora un sistema di
## status, quindi la maledizione e' un marcatore (modificatore per id
## "curse:<ability_id>", senza delta) che scade a tempo ed e' tolto da
## light_purify (marcato debuff). effetto e condizione_rimozione sono
## registrati per quando ci sara' un sistema di cleanse per condizione.
## Il "danno" della sfortuna lo fanno le altre primitive dell'abilita'
## (debuff_stat, dot), non questa: curse e' il contenitore concettuale.
func _p_curse(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var effetto: String = str(prim.get("effetto", ""))
	var durata: float = _num(prim.get("durata"), 0.0)
	var condizione_rimozione: String = str(prim.get("condizione_rimozione", ""))

	# US-218C: la maledizione e' uno status nominato (data/status_effects.json),
	# non piu' un marcatore vuoto. StatsComponent lo scade da solo; light_purify
	# lo toglie per tag.
	var applicato: bool = false
	if not effetto.is_empty() and stats != null and stats.has_method("applica_status"):
		stats.call("applica_status", effetto, durata if durata > 0.0 else -1.0)
		applicato = true

	return {"tipo": "curse", "effetto": effetto, "durata": durata,
			"condizione_rimozione": condizione_rimozione, "applied": applicato}


## mind_read (US-520): il Clairvoyant/Knowledge Emperor legge la mente di un
## bersaglio nel raggio. Riusa il segnale info_rivelata (canale reveal) con
## categoria "mente:<rivela>". Il consumatore (HUD/UI del bersaglio, IA che
## reagisce) e' fase 6.
func _p_mind_read(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var profondita: float = _num(prim.get("profondita"), 1.0)
	var rivela: String = str(prim.get("rivela", ""))
	var origine: Vector2 = (caster as Node2D).global_position if caster is Node2D and (caster as Node2D).is_inside_tree() else Vector2.ZERO
	info_rivelata.emit("mente:" + rivela, raggio, origine)
	return {"tipo": "mind_read", "raggio": raggio, "profondita": profondita, "rivela": rivela}


## plant_growth (US-512): fa crescere vegetazione di 'specie' in un raggio.
## persistente:true -> la vegetazione resta ed entra nel WorldState (come
## terrain_modify permanente, riuso); altrimenti e' un campo che il combat/
## mondo consumera' (fase 6). velocita e' registrata per la resa a schermo.
func _p_plant_growth(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var specie: String = str(prim.get("specie", ""))
	var velocita: float = _num(prim.get("velocita"), 1.0)
	var persistente: bool = _flag(prim.get("persistente"), false)
	var pos: Vector2 = Vector2.ZERO
	if caster is Node2D and (caster as Node2D).is_inside_tree():
		pos = (caster as Node2D).global_position
	var rec: Dictionary = {"tipo": "plant_growth", "raggio": raggio, "specie": specie,
			"velocita": velocita, "persistente": persistente,
			"posizione": [pos.x, pos.y], "applied": not persistente}
	if persistente:
		var ws: Node = get_tree().root.get_node_or_null("WorldState")
		if ws != null:
			ws.call("registra_terreno", "vegetazione:" + specie, pos, raggio)
			rec["applied"] = true
	return rec


## illusion (US-608, primitiva della fase 5b portata qui dal Servant of
## Concealment del Darkness - fool_velo_illusorio e darkness_cancellazione la
## usano). Crea un inganno percettivo di 'tipo_illusione' nel raggio per
## 'durata'. 'potenza' = quante esche / quanto e' convincente. Il consumatore
## vero (IA, tell visivo) e' combat/fase 6: qui l'abilita' emette il fatto e,
## per 'danno_percepito', un dot a tag follia che sparisce se il bersaglio
## "capisce" (rimovibile da light_purify come ogni dot).
func _p_illusion(prim: Dictionary, caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var potenza: int = int(_num(prim.get("potenza"), 1.0))
	var tipo_illusione: String = str(prim.get("tipo_illusione", ""))
	var origine: Vector2 = (caster as Node2D).global_position if caster is Node2D and (caster as Node2D).is_inside_tree() else Vector2.ZERO

	if tipo_illusione == "danno_percepito" and durata > 0.0 and stats != null:
		_pending.append({"kind": "dot", "stats": stats, "danno_tick": float(potenza),
				"tick_rate": 1.0, "left": durata, "acc": 0.0})

	illusione_creata.emit(tipo_illusione, raggio, origine)
	return {"tipo": "illusion", "raggio": raggio, "durata": durata, "potenza": potenza,
			"tipo_illusione": tipo_illusione, "applied": true}


## steal (US-5B01, primitiva-firma del gruppo Lord of Mysteries): sottrae
## qualcosa a un bersaglio. 'categoria' decide COSA:
##   "oggetto"    -> registra il furto di un item. L'aggancio a Inventory con un
##                   bersaglio reale e' combat/fase 6 (prd-fase-5b, OQ 2): qui
##                   si registra il fatto.
##   "abilita"    -> presta al caster l'ability_id indicato via grant_temporary
##                   (US-204) per 'durata_prestito' secondi. Il bersaglio da cui
##                   si ruba lo sceglie il combat (fase 6); l'ability_id nei dati
##                   dice quale potere questo Beyonder e' capace di copiare.
##   "conoscenza" -> KnowledgeStore.impara un flag "rubata:<ability_id>".
## 'probabilita' < 1.0 = non sempre riesce (registrato; il tiro vero e' combat).
## 'non_sottrae' true (Door, fotocopia): il record segna sottratto:false, cioe'
##   il bersaglio NON resta privo di cio' che gli e' stato copiato.
func _p_steal(prim: Dictionary, caster: Node, _stats: Node, ability_id: String) -> Dictionary:
	var categoria: String = str(prim.get("categoria", ""))
	var durata_prestito: float = _num(prim.get("durata_prestito"), 0.0)
	var probabilita: float = _num(prim.get("probabilita"), 1.0)
	var non_sottrae: bool = _flag(prim.get("non_sottrae"), false)

	var rec: Dictionary = {"tipo": "steal", "categoria": categoria,
			"durata_prestito": durata_prestito, "probabilita": probabilita,
			"sottratto": not non_sottrae, "applied": false}

	match categoria:
		"abilita":
			var target_id: String = str(prim.get("ability_id", ""))
			rec["ability_id"] = target_id
			if not target_id.is_empty() and caster != null:
				rec["applied"] = grant_temporary(target_id, caster, durata_prestito)
		"conoscenza":
			var flag: String = "rubata:" + ability_id
			rec["flag"] = flag
			var ks: Node = get_tree().root.get_node_or_null("KnowledgeStore")
			if ks != null:
				ks.call("impara", flag)
				rec["applied"] = true
		"oggetto":
			rec["applied"] = true

	return rec


## possess (US-5B02): il caster prende il controllo di un ospite. Applica lo
## status 'posseduto' al bersaglio (lo stats risolto, come soul_detach) per
## 'durata' e registra 'controllo' (sensi | parziale | totale). Come
## soul_detach di Death: il CORPO del caster resta a terra vulnerabile durante
## la possessione - il record lo dichiara ({ corpo_a_terra, vulnerabilita_corpo });
## la resa combat (il corpo bersagliabile, l'ospite che attacca per te) e'
## fase 6. Anche il Fool (Marionettist) la usera'.
func _p_possess(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var durata: float = _num(prim.get("durata"), 0.0)
	var controllo: String = str(prim.get("controllo", ""))
	var applicato: bool = false
	if stats != null and stats.has_method("applica_status"):
		stats.call("applica_status", "posseduto", durata if durata > 0.0 else -1.0)
		applicato = true
	return {"tipo": "possess", "durata": durata, "controllo": controllo,
			"soglia_resistenza": _num(prim.get("soglia_resistenza"), 0.0),
			"corpo_a_terra": true,
			"vulnerabilita_corpo": _num(prim.get("vulnerabilita_corpo"), 0.6),
			"applied": applicato}


## shadow_meld (US-607, primitiva della fase 5b portata qui dal Nightwatcher
## del Darkness - la prima Sequenza attiva che la usa): il caster si fonde con
## l'ombra. Applica lo status 'occultato' (sfugge al rilevamento) per 'durata'.
## 'velocita' e 'richiede_ombra' sono registrati: il bonus di movimento e il
## gate "solo in ombra" sono combat/mondo (fase 6). Anche Door (Secrets
## Sorcerer) la usera'.
func _p_shadow_meld(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var durata: float = _num(prim.get("durata"), 0.0)
	var applicato: bool = false
	if stats != null and stats.has_method("applica_status"):
		stats.call("applica_status", "occultato", durata if durata > 0.0 else -1.0)
		applicato = true
	return {"tipo": "shadow_meld", "durata": durata,
			"velocita": _num(prim.get("velocita"), 0.0),
			"richiede_ombra": _flag(prim.get("richiede_ombra"), false),
			"applied": applicato}


## soul_detach (US-507): il Ferryman uccide separando anima e corpo. Applica
## lo status 'anima_recisa' al bersaglio (crollo di difesa/precisione/velocita)
## per 'durata'. vulnerabilita_corpo e velocita restano registrati per quando
## il combat leggera' il corpo separato (fase 6).
func _p_soul_detach(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var durata: float = _num(prim.get("durata"), 0.0)
	var applicato: bool = false
	if stats != null and stats.has_method("applica_status"):
		stats.call("applica_status", "anima_recisa", durata if durata > 0.0 else -1.0)
		applicato = true
	return {"tipo": "soul_detach", "durata": durata,
			"vulnerabilita_corpo": _num(prim.get("vulnerabilita_corpo"), 0.0),
			"velocita": _num(prim.get("velocita"), 0.0), "applied": applicato}


## resurrect (US-507): riporta in piedi un bersaglio caduto ripristinando
## 'hp_ripristinati' hp (anche da hp <= 0), al prezzo di 'costo_follia' in
## Madness. Il targeting di un alleato/evocazione specifico e' fase 6: qui
## agisce sullo stats risolto (self).
func _p_resurrect(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var hp_rip: float = _num(prim.get("hp_ripristinati"), 0.0)
	var costo_follia: float = _num(prim.get("costo_follia"), 0.0)
	var bersaglio: String = str(prim.get("bersaglio", "self"))
	var applicato: bool = false
	if stats != null and stats.get("hp") != null and (bersaglio == "self" or bersaglio == ""):
		stats.set("hp", maxf(float(stats.get("hp")), 0.0) + hp_rip)
		applicato = true
	if costo_follia > 0.0:
		var m: Node = get_tree().root.get_node_or_null("Madness")
		if m != null:
			m.call("add", costo_follia, "ability:resurrect", false)
	return {"tipo": "resurrect", "bersaglio": bersaglio, "hp_ripristinati": hp_rip,
			"costo_follia": costo_follia, "applied": applicato}


## teleport (US-506): consegna al caster l'ordine di saltare di 'distanza'.
## Come _p_dash: il movimento vero e' del controller. La "porta permanente
## verso il mondo spirituale" (esplorazione) e' fase 6; qui c'e' il salto.
func _p_teleport(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var spec: Dictionary = {
		"tipo": "teleport",
		"distanza": _num(prim.get("distanza"), 160.0),
		"richiede_visuale": _flag(prim.get("richiede_visuale"), true),
		"porta_alleati": _flag(prim.get("porta_alleati"), false),
	}
	spec["applied"] = caster != null and caster.has_method("teleport_verso")
	if spec["applied"]:
		caster.call("teleport_verso", spec)
	return spec


## fear (US-505): applica lo status 'paura' al bersaglio. Con un caster in
## scena e raggio > 0 accende un field d'area che lo propaga alle hurtbox nel
## raggio. 'soglia_resistenza' e' registrata ma il confronto con la resistenza
## del bersaglio e' comportamento IA (fase 6): qui l'effetto e' lo status,
## come per curse/dot (stat forward-looking).
func _p_fear(prim: Dictionary, caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var soglia: float = _num(prim.get("soglia_resistenza"), 0.0)

	var applicato: bool = false
	if stats != null and stats.has_method("applica_status"):
		stats.call("applica_status", "paura", durata if durata > 0.0 else -1.0)
		applicato = true

	var campo: bool = false
	if caster != null and raggio > 0.0 and durata > 0.0:
		campo = _spawn_field(caster, {"tipo": "aura", "raggio": raggio,
				"durata": durata, "tick_rate": 1.0, "effetto": "paura"})

	return {"tipo": "fear", "raggio": raggio, "durata": durata,
			"soglia_resistenza": soglia, "applied": applicato, "campo": campo}


## reveal_info (US-505): rivela informazioni di una 'categoria' in un raggio
## per una durata. Fuori da Hermit la categoria e' obbligatoria (matrice di
## proprieta', US-502) e limita cosa si vede. Il consumatore vero (HUD/libro,
## world state) arriva con fase 6: qui l'abilita' emette il fatto, come reveal
## degli altri sistemi.
func _p_reveal_info(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var categoria: String = str(prim.get("categoria", ""))
	var durata: float = _num(prim.get("durata"), 0.0)
	var origine: Vector2 = (caster as Node2D).global_position if caster is Node2D and (caster as Node2D).is_inside_tree() else Vector2.ZERO
	info_rivelata.emit(categoria, raggio, origine)
	return {"tipo": "reveal_info", "raggio": raggio, "categoria": categoria,
			"durata": durata, "origine": origine}


## summon: evoca "quantita" entita' di tipo entita_id. durata: -1 ->
## PERSISTENTI, registrate in SummonRegistry (sopravvivono al combattimento e
## al save); durata > 0 -> temporanee, un'entry _pending che scade. Lo spawn
## del Node vero lo fara' il sistema del mondo/combat leggendo il registro:
## qui si registra il fatto.
func _p_summon(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var entita_id: String = str(prim.get("entita_id", ""))
	var quantita: int = maxi(1, int(_num(prim.get("quantita"), 1.0)))
	var durata: float = _num(prim.get("durata"), 0.0)
	var comportamento: String = str(prim.get("comportamento", ""))

	var pos: Vector2 = Vector2.ZERO
	if caster is Node2D and (caster as Node2D).is_inside_tree():
		pos = (caster as Node2D).global_position

	var rec: Dictionary = {"tipo": "summon", "entita_id": entita_id, "quantita": quantita,
			"durata": durata, "comportamento": comportamento, "persistenti": [], "applied": true}

	if entita_id.is_empty():
		rec["applied"] = false
		return rec

	if durata < 0.0:
		var reg: Node = get_tree().root.get_node_or_null("SummonRegistry")
		if reg == null:
			rec["applied"] = false
			return rec
		for i in quantita:
			rec["persistenti"].append(reg.call("evoca", entita_id, comportamento, pos, 10.0))
	elif durata > 0.0:
		_pending.append({"kind": "summon_temp", "caster": caster, "left": durata,
				"entita_id": entita_id, "quantita": quantita})
	return rec


## Annulla una trasformazione in corso "su richiesta". true se ce n'era una.
func annulla_transform(ability_id: String) -> bool:
	var mod_id: String = "transform:%s" % ability_id
	var trovata: bool = false
	var superstiti: Array = []
	for entry in _pending:
		var e: Dictionary = entry
		if str(e["kind"]) == "transform" and str(e.get("mod_id", "")) == mod_id:
			var raw: Variant = e["stats"]
			if is_instance_valid(raw):
				(raw as Node).call("remove_modifier", mod_id)
			trovata = true
			continue
		superstiti.append(e)
	_pending = superstiti
	return trovata


func _p_heal(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var quantita: float = _num(prim.get("quantita"), 0.0)
	var istantaneo: bool = _flag(prim.get("istantaneo"), true)
	var durata: float = _num(prim.get("durata"), 0.0)
	var bersaglio: String = str(prim.get("bersaglio", "self"))

	# Oggi e' risolvibile solo "self": il targeting di alleati e pet arriva
	# con i loro sistemi. Un bersaglio diverso NON deve curare il caster per
	# sbaglio: si registra l'esito e non si tocca nessuno.
	if bersaglio != "self" and bersaglio != "":
		return {"tipo": "heal", "quantita": quantita, "bersaglio": bersaglio,
				"applied": false}

	if istantaneo or durata <= 0.0:
		stats.set("hp", float(stats.get("hp")) + quantita)
		return {"tipo": "heal", "quantita": quantita, "istantaneo": true}

	_pending.append({
		"kind": "heal", "stats": stats, "rate": quantita / durata, "left": durata,
	})
	return {"tipo": "heal", "quantita": quantita, "istantaneo": false, "durata": durata}


func _p_projectile(prim: Dictionary, caster: Node, _stats: Node, ability_id: String) -> Dictionary:
	var spec: Dictionary = {
		"tipo": "projectile",
		"danno": _num(prim.get("danno"), 0.0),
		"velocita": _num(prim.get("velocita"), 200.0),
		"gittata": _num(prim.get("gittata"), 100.0),
		"pierce": int(_num(prim.get("pierce"), 0.0)),
		"tag_danno": prim.get("tag_danno", []),
		"origine": ability_id,
	}
	spec["spawned"] = _spawn_projectile(caster, spec)
	return spec


func _p_melee_arc(prim: Dictionary, caster: Node, _stats: Node, ability_id: String) -> Dictionary:
	var spec: Dictionary = {
		"tipo": "melee_arc",
		"danno": _num(prim.get("danno"), 0.0),
		"angolo": _num(prim.get("angolo"), 90.0),
		"raggio": _num(prim.get("raggio"), 32.0),
		"stagger": _num(prim.get("stagger"), 0.0),
		"tag_danno": prim.get("tag_danno", []),
		"origine": ability_id,
	}
	spec["spawned"] = _spawn_melee_arc(caster, spec)
	return spec


func _p_dash(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var spec: Dictionary = {
		"tipo": "dash",
		"distanza": _num(prim.get("distanza"), 64.0),
		"durata": _num(prim.get("durata"), 0.2),
		"invulnerabile": _flag(prim.get("invulnerabile"), false),
		"attraversa_nemici": _flag(prim.get("attraversa_nemici"), false),
	}
	# Il movimento vero appartiene al controller del personaggio (US-004/009):
	# qui si consegna l'ordine, chi sa muoversi lo esegue.
	spec["applied"] = caster != null and caster.has_method("start_dash")
	if spec["applied"]:
		caster.call("start_dash", spec)
	return spec


## shield: una riserva che assorbe danno prima degli hp e poi scade
## (StatsComponent.aggiungi_scudo + hurtbox.gd). riflette e tag_bloccati sono
## letti e registrati; riflette applicato da chi conosce il mittente, il
## filtro per tag scatta quando la pipeline di danno portera' il tag.
func _p_shield(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var assorbimento: float = _num(prim.get("assorbimento"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var riflette: float = _num(prim.get("riflette"), 0.0)
	var tag_bloccati: Array = prim.get("tag_bloccati", []) if typeof(prim.get("tag_bloccati")) == TYPE_ARRAY else []
	var bersaglio: String = str(prim.get("bersaglio", "self"))

	var rec: Dictionary = {"tipo": "shield", "assorbimento": assorbimento, "durata": durata,
			"riflette": riflette, "tag_bloccati": tag_bloccati, "bersaglio": bersaglio}

	# Come _p_heal: solo "self" e' risolvibile oggi. Un bersaglio diverso non
	# deve scudare il caster per sbaglio.
	if bersaglio != "self" and bersaglio != "":
		rec["applied"] = false
		return rec

	stats.call("aggiungi_scudo", assorbimento, riflette, tag_bloccati)
	rec["applied"] = true
	if durata > 0.0:
		_pending.append({"kind": "scudo_expire", "stats": stats, "left": durata})
	return rec


## dot: danno periodico su un bersaglio nel tempo. Usa la coda _pending, non
## await (criterio). Bersaglio = lo stats risolto dal caster: l'abilita' che
## porta il dot e' lanciata "su" quell'entita', come _p_heal/_p_buff_stat.
func _p_dot(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var danno_tick: float = _num(prim.get("danno_tick"), 0.0)
	var tick_rate: float = _num(prim.get("tick_rate"), 1.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var tag_danno: Variant = prim.get("tag_danno", "")

	if durata > 0.0 and tick_rate > 0.0 and stats != null:
		_pending.append({"kind": "dot", "stats": stats, "danno_tick": danno_tick,
				"tick_rate": tick_rate, "left": durata, "acc": 0.0})
	return {"tipo": "dot", "danno_tick": danno_tick, "tick_rate": tick_rate,
			"durata": durata, "tag_danno": tag_danno}


## decay: danno d'area continuo per una durata. Con raggio > 0 e un caster in
## scena genera un field (scripts/field.gd) che colpisce le hurtbox nel
## raggio; altrimenti ripiega sulla coda _pending (danno totale spalmato sul
## caster stesso, come prima).
func _p_decay(prim: Dictionary, caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var danno: float = _num(prim.get("danno"), 0.0)
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var colpisce_oggetti: bool = _flag(prim.get("colpisce_oggetti"), false)
	var durata: float = _num(prim.get("durata"), 0.0)

	var rec: Dictionary = {"tipo": "decay", "danno": danno, "raggio": raggio,
			"colpisce_oggetti": colpisce_oggetti, "durata": durata, "campo": false,
			"strutture_colpite": []}

	# colpisce_oggetti (US-320): le strutture non hanno un Node in scena, vivono
	# solo in StructureRegistry. Le colpiamo qui, al lancio, con il danno TOTALE
	# del decay in un colpo: sono bersagli grossolani (hp 25-60), spalmare il
	# tick su di loro non aggiunge nulla. Colpisce OGNI struttura in raggio,
	# comprese quelle del giocatore (data/abilities/twilight_giant.json: tg_2
	# "deve poter danneggiare la propria base"). La crollo che ne deriva NON e'
	# volontario: la scelta deliberata di lasciar decadere una struttura e'
	# StructureRegistry.distruggi(iid, true), un'altra strada.
	if colpisce_oggetti and raggio > 0.0 and caster is Node2D and (caster as Node2D).is_inside_tree():
		var sr: Node = get_tree().root.get_node_or_null("StructureRegistry")
		if sr != null:
			var centro: Vector2 = (caster as Node2D).global_position
			for iid in sr.call("in_raggio", centro, raggio):
				sr.call("danneggia", iid, danno)
				(rec["strutture_colpite"] as Array).append(iid)

	if durata <= 0.0:
		return rec

	var tick_rate: float = _num(prim.get("tick_rate"), 1.0)
	if raggio > 0.0 and _spawn_field(caster, {
			"tipo": "decay", "raggio": raggio, "durata": durata,
			"tick_rate": tick_rate, "danno_tick": danno / durata * tick_rate}):
		rec["campo"] = true
	elif stats != null:
		_pending.append({"kind": "decay", "stats": stats, "rate": danno / durata,
				"left": durata})
	return rec


## aura: effetto persistente ancorato al caster. durata -1 = permanente. Con
## raggio > 0 e un caster in scena genera un field (scripts/field.gd) che
## applica lo status 'effetto' alle hurtbox nel raggio; l'entry _pending
## resta come traccia ispezionabile e per il caso senza scena.
func _p_aura(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var effetto: String = str(prim.get("effetto", ""))
	var tick_rate: float = _num(prim.get("tick_rate"), 1.0)
	var bersagli: String = str(prim.get("bersagli", ""))
	var persistente: bool = durata < 0.0

	var campo: bool = false
	if caster != null and (persistente or durata > 0.0):
		_pending.append({"kind": "aura", "caster": caster, "left": maxf(durata, 0.0),
				"persistente": persistente, "raggio": raggio, "effetto": effetto,
				"tick_rate": tick_rate, "bersagli": bersagli})
		if raggio > 0.0 and not effetto.is_empty():
			campo = _spawn_field(caster, {"tipo": "aura", "raggio": raggio,
					"durata": durata, "tick_rate": tick_rate, "effetto": effetto})
	return {"tipo": "aura", "raggio": raggio, "durata": durata, "effetto": effetto,
			"tick_rate": tick_rate, "bersagli": bersagli, "persistente": persistente,
			"campo": campo}


func _spawn_field(caster: Node, spec: Dictionary) -> bool:
	var origin := caster as Node2D
	if origin == null or not origin.is_inside_tree():
		return false
	var node := preload("res://scripts/field.gd").new()
	origin.add_child(node)
	node.setup(spec, caster)
	return true


# --- Spawn -------------------------------------------------------------------

func _spawn_projectile(caster: Node, spec: Dictionary) -> bool:
	var origin := caster as Node2D
	if origin == null or not origin.is_inside_tree():
		return false
	var node := preload("res://scripts/projectile.gd").new()
	node.setup(spec, origin.global_position, _facing(origin))
	origin.get_parent().add_child(node)
	return true


func _spawn_melee_arc(caster: Node, spec: Dictionary) -> bool:
	var origin := caster as Node2D
	if origin == null or not origin.is_inside_tree():
		return false
	var node := preload("res://scripts/melee_arc.gd").new()
	node.setup(spec, _facing(origin))
	origin.add_child(node)
	return true


## Direzione di tiro: quella dichiarata dal caster, altrimenti destra.
func _facing(origin: Node2D) -> Vector2:
	if origin.has_method("get_facing"):
		return origin.call("get_facing")
	return Vector2.RIGHT


# --- Effetti a tempo ---------------------------------------------------------

func _process(delta: float) -> void:
	if not _pending.is_empty():
		tick_effects(delta)
	var now: int = Time.get_ticks_msec()
	if now >= _prossimo_sweep_ms:
		_prossimo_sweep_ms = now + _SWEEP_OGNI_MS
		sweep_cooldowns()


## Avanza gli effetti a tempo. Pubblica di proposito: i test la chiamano con
## un delta scelto invece di aspettare secondi veri.
func tick_effects(delta: float) -> void:
	var superstiti: Array = []
	for entry in _pending:
		var e: Dictionary = entry
		var kind: String = str(e["kind"])
		# Va letto come Variant e validato PRIMA di tipare: assegnare
		# un'istanza gia' liberata a una variabile Node e' un errore che
		# interrompe il ciclo a meta' e lascia la coda sporca. L'ancora e' lo
		# stats del bersaglio, o il caster per un'aura.
		var raw: Variant = e["caster"] if e.has("caster") else e["stats"]
		if not is_instance_valid(raw):
			continue  # il bersaglio/caster non c'e' piu': l'effetto muore con lui
		var anchor: Node = raw

		var persistente: bool = e.get("persistente", false)
		var left: float = float(e["left"])
		if not persistente:
			left -= delta

		# Una entry persistente (aura -1, transform a solo costo) non ha "left"
		# significativo: lo span del tick e' l'intero delta.
		var span: float = delta if persistente else minf(delta, float(e["left"]))
		var esaurita: bool = false
		match kind:
			"heal":
				anchor.set("hp", float(anchor.get("hp")) + float(e["rate"]) * span)
			"decay":
				anchor.set("hp", float(anchor.get("hp")) - float(e["rate"]) * span)
			"dot":
				e["acc"] = float(e["acc"]) + span
				while float(e["tick_rate"]) > 0.0 and float(e["acc"]) >= float(e["tick_rate"]):
					e["acc"] = float(e["acc"]) - float(e["tick_rate"])
					anchor.set("hp", float(anchor.get("hp")) - float(e["danno_tick"]))
			"transform":
				var costo: float = float(e["costo_al_secondo"])
				if costo > 0.0:
					anchor.set("spiritualita", maxf(0.0, float(anchor.get("spiritualita")) - costo * span))
					esaurita = float(anchor.get("spiritualita")) <= 0.0

		if esaurita or (not persistente and left <= 0.0):
			match kind:
				"expire":
					anchor.call("remove_modifier", str(e["mod_id"]))
				"scudo_expire":
					anchor.call("azzera_scudo")
				"transform":
					anchor.call("remove_modifier", str(e["mod_id"]))
				"grant_expire":
					_granted.erase(str(e["key"]))
			continue

		e["left"] = left
		superstiti.append(e)
	_pending = superstiti


func pending_count() -> int:
	return _pending.size()


## Applica subito ogni effetto residuo e svuota la coda. Serve ai test e a
## una transizione di scena, per non lasciare buff appesi.
func flush_effects() -> void:
	for entry in _pending:
		var e: Dictionary = entry
		if str(e["kind"]) == "grant_expire":
			_granted.erase(str(e["key"]))
			continue
		# Le entry ancorate al caster (aura, terrain_temp) non hanno un
		# modificatore da togliere: si scartano e basta.
		if not e.has("stats"):
			continue
		var raw: Variant = e["stats"]
		if not is_instance_valid(raw):
			continue
		if str(e["kind"]) == "expire" or str(e["kind"]) == "transform":
			(raw as Node).call("remove_modifier", str(e["mod_id"]))
		elif str(e["kind"]) == "scudo_expire":
			(raw as Node).call("azzera_scudo")
	_pending.clear()


func _game_data() -> Node:
	return get_tree().root.get_node("GameData")
