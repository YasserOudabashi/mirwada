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

## Motivi di rifiuto, come costanti: i test e la UI non devono confrontare
## stringhe scritte a mano.
const OK := "ok"
const ERR_SCONOSCIUTA := "abilita_sconosciuta"
const ERR_COOLDOWN := "in_cooldown"
const ERR_SPIRITUALITA := "spiritualita_insufficiente"
const ERR_NO_STATS := "caster_senza_stats"

## Chiave "<instance_id>:<ability_id>" -> istante di fine in ms. Le voci dei
## caster non piu' validi o gia' scadute vengono rimosse da sweep_cooldowns():
## senza, una partita lunga accumulerebbe una voce per ogni entita' morta.
var _cooldowns: Dictionary = {}
const _SWEEP_OGNI_MS := 5000
var _prossimo_sweep_ms: int = 0

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
	}


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

	if is_on_cooldown(caster, ability_id):
		result["reason"] = ERR_COOLDOWN
		return result

	# Il costo si paga PRIMA di eseguire, e se non basta non si esegue niente:
	# meglio un'abilita' che non parte che una che parte a meta'.
	var cost: float = _num(ability.get("costo_spiritualita"), 0.0)
	if not stats.call("spend_spiritualita", cost):
		result["reason"] = ERR_SPIRITUALITA
		return result

	_start_cooldown(caster, ability_id, _num(ability.get("cooldown"), 0.0))

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
		var prim: Dictionary = entry
		var tipo: String = str(prim.get("tipo", ""))

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

	result["ok"] = true
	result["reason"] = OK
	ability_executed.emit(ability_id, caster, result)
	return result


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
	var now: int = Time.get_ticks_msec()
	for key in _cooldowns.keys():
		var scaduta: bool = now >= int(_cooldowns[key])
		var iid: int = str(key).get_slice(":", 0).to_int()
		if scaduta or not is_instance_id_valid(iid):
			_cooldowns.erase(key)


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

	return {"tipo": "light_purify", "raggio": raggio, "potenza": potenza,
			"riduce_sequenza": riduce_sequenza, "rimossi": rimossi}


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


## decay: danno d'area continuo per una durata. Il danno dichiarato e' il
## totale, spalmato sulla durata (come _p_heal nel tempo, di segno opposto).
## raggio e colpisce_oggetti sono registrati; la query d'area sulle entita'
## arriva con l'integrazione combat delle abilita'.
func _p_decay(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var danno: float = _num(prim.get("danno"), 0.0)
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var colpisce_oggetti: bool = _flag(prim.get("colpisce_oggetti"), false)
	var durata: float = _num(prim.get("durata"), 0.0)

	if durata > 0.0 and stats != null:
		_pending.append({"kind": "decay", "stats": stats, "rate": danno / durata,
				"left": durata})
	return {"tipo": "decay", "danno": danno, "raggio": raggio,
			"colpisce_oggetti": colpisce_oggetti, "durata": durata}


## aura: effetto persistente ancorato al caster, rimosso quando il caster non
## e' piu' valido. durata -1 = permanente (sopravvive al combattimento). Il
## tick dell'effetto (taunt, decadimento...) e' registrato ma non applicato:
## non c'e' ancora un sistema di status sulle entita'.
func _p_aura(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var raggio: float = _num(prim.get("raggio"), 0.0)
	var durata: float = _num(prim.get("durata"), 0.0)
	var effetto: String = str(prim.get("effetto", ""))
	var tick_rate: float = _num(prim.get("tick_rate"), 1.0)
	var bersagli: String = str(prim.get("bersagli", ""))
	var persistente: bool = durata < 0.0

	if caster != null and (persistente or durata > 0.0):
		_pending.append({"kind": "aura", "caster": caster, "left": maxf(durata, 0.0),
				"persistente": persistente, "raggio": raggio, "effetto": effetto,
				"tick_rate": tick_rate, "bersagli": bersagli})
	return {"tipo": "aura", "raggio": raggio, "durata": durata, "effetto": effetto,
			"tick_rate": tick_rate, "bersagli": bersagli, "persistente": persistente}


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
		var raw: Variant = e["caster"] if kind == "aura" else e["stats"]
		if not is_instance_valid(raw):
			continue  # il bersaglio/caster non c'e' piu': l'effetto muore con lui
		var anchor: Node = raw

		var persistente: bool = e.get("persistente", false)
		var left: float = float(e["left"])
		if not persistente:
			left -= delta

		var span: float = minf(delta, float(e["left"]))
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

		if not persistente and left <= 0.0:
			match kind:
				"expire":
					anchor.call("remove_modifier", str(e["mod_id"]))
				"scudo_expire":
					anchor.call("azzera_scudo")
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
		if str(e["kind"]) == "aura":
			continue
		var raw: Variant = e["stats"]
		if not is_instance_valid(raw):
			continue
		if str(e["kind"]) == "expire":
			(raw as Node).call("remove_modifier", str(e["mod_id"]))
		elif str(e["kind"]) == "scudo_expire":
			(raw as Node).call("azzera_scudo")
	_pending.clear()


func _game_data() -> Node:
	return get_tree().root.get_node("GameData")
