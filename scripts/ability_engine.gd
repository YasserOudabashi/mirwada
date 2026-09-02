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

var _cooldowns: Dictionary = {}
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
	var cost: float = float(ability.get("costo_spiritualita", 0.0))
	if not stats.call("spend_spiritualita", cost):
		result["reason"] = ERR_SPIRITUALITA
		return result

	_start_cooldown(caster, ability_id, float(ability.get("cooldown", 0.0)))

	for entry in (ability.get("primitive", []) as Array):
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


func _start_cooldown(caster: Node, ability_id: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_cooldowns[_key(caster, ability_id)] = Time.get_ticks_msec() + int(seconds * 1000.0)


func _key(caster: Node, ability_id: String) -> String:
	return "%d:%s" % [caster.get_instance_id(), ability_id]


# --- Primitive ---------------------------------------------------------------
# Ogni gestore riceve i parametri grezzi dal JSON e restituisce un record di
# cio' che ha fatto. I default servono a non esplodere su un dato incompleto.

func _p_buff_stat(prim: Dictionary, _caster: Node, stats: Node, ability_id: String) -> Dictionary:
	var stat: String = str(prim.get("stat", ""))
	var valore: float = float(prim.get("valore", 0.0))
	var durata: float = float(prim.get("durata", 0.0))
	var moltiplicativo: bool = bool(prim.get("moltiplicativo", false))

	# I modificatori sono additivi: un moltiplicativo diventa il delta
	# equivalente sulla base, cosi' resta rimovibile per id come gli altri.
	var delta: float = valore
	if moltiplicativo:
		delta = float(stats.call("get_base", stat)) * valore

	# id derivato da abilita' + stat: riapplicare rinfresca invece di impilare.
	var mod_id: String = "%s:%s" % [ability_id, stat]
	stats.call("apply_modifier", mod_id, {stat: delta})

	if durata > 0.0:
		_pending.append({
			"kind": "expire", "stats": stats, "mod_id": mod_id, "left": durata,
		})

	return {"tipo": "buff_stat", "stat": stat, "delta": delta,
			"durata": durata, "modifier_id": mod_id}


func _p_heal(prim: Dictionary, _caster: Node, stats: Node, _ability_id: String) -> Dictionary:
	var quantita: float = float(prim.get("quantita", 0.0))
	var istantaneo: bool = bool(prim.get("istantaneo", true))
	var durata: float = float(prim.get("durata", 0.0))
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
		"danno": float(prim.get("danno", 0.0)),
		"velocita": float(prim.get("velocita", 200.0)),
		"gittata": float(prim.get("gittata", 100.0)),
		"pierce": int(prim.get("pierce", 0)),
		"tag_danno": prim.get("tag_danno", []),
		"origine": ability_id,
	}
	spec["spawned"] = _spawn_projectile(caster, spec)
	return spec


func _p_melee_arc(prim: Dictionary, caster: Node, _stats: Node, ability_id: String) -> Dictionary:
	var spec: Dictionary = {
		"tipo": "melee_arc",
		"danno": float(prim.get("danno", 0.0)),
		"angolo": float(prim.get("angolo", 90.0)),
		"raggio": float(prim.get("raggio", 32.0)),
		"stagger": float(prim.get("stagger", 0.0)),
		"tag_danno": prim.get("tag_danno", []),
		"origine": ability_id,
	}
	spec["spawned"] = _spawn_melee_arc(caster, spec)
	return spec


func _p_dash(prim: Dictionary, caster: Node, _stats: Node, _ability_id: String) -> Dictionary:
	var spec: Dictionary = {
		"tipo": "dash",
		"distanza": float(prim.get("distanza", 64.0)),
		"durata": float(prim.get("durata", 0.2)),
		"invulnerabile": bool(prim.get("invulnerabile", false)),
		"attraversa_nemici": bool(prim.get("attraversa_nemici", false)),
	}
	# Il movimento vero appartiene al controller del personaggio (US-004/009):
	# qui si consegna l'ordine, chi sa muoversi lo esegue.
	spec["applied"] = caster != null and caster.has_method("start_dash")
	if spec["applied"]:
		caster.call("start_dash", spec)
	return spec


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


## Avanza gli effetti a tempo. Pubblica di proposito: i test la chiamano con
## un delta scelto invece di aspettare secondi veri.
func tick_effects(delta: float) -> void:
	var superstiti: Array = []
	for entry in _pending:
		var e: Dictionary = entry
		# Va letto come Variant e validato PRIMA di tipare: assegnare
		# un'istanza gia' liberata a una variabile Node e' un errore che
		# interrompe il ciclo a meta' e lascia la coda sporca.
		var raw: Variant = e["stats"]
		if not is_instance_valid(raw):
			continue  # il bersaglio non c'e' piu': l'effetto muore con lui
		var stats: Node = raw

		var left: float = float(e["left"]) - delta
		if str(e["kind"]) == "heal":
			var quota: float = float(e["rate"]) * minf(delta, float(e["left"]))
			stats.set("hp", float(stats.get("hp")) + quota)

		if left <= 0.0:
			if str(e["kind"]) == "expire":
				stats.call("remove_modifier", str(e["mod_id"]))
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
		var raw: Variant = e["stats"]
		if is_instance_valid(raw) and str(e["kind"]) == "expire":
			(raw as Node).call("remove_modifier", str(e["mod_id"]))
	_pending.clear()


func _game_data() -> Node:
	return get_tree().root.get_node("GameData")
