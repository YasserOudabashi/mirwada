extends Node
## Stato di partita corrente: il minimo che va nel save. Tiene il tempo di
## gioco e il nome del personaggio (default da design-lore.md, cambiabile
## alla creazione personaggio quando esistera'), e sa assemblare/riapplicare
## uno snapshot per SaveSystem.
##
## F9 salva, F10 carica lo slot 0 — solo in debug, finche' non c'e' la UI a
## libro (design-ui-libro.md).
##
## NIENTE class_name: coerente col progetto.

const SLOT_RAPIDO := 0
const NOME_DEFAULT := "Enel"

var nome_personaggio: String = NOME_DEFAULT
var tempo_gioco: float = 0.0


func _process(delta: float) -> void:
	tempo_gioco += delta


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F9:
		var r: Dictionary = salva_rapido()
		print("[GameState] salvataggio rapido: ", "ok" if r.get("ok") else r.get("reason"))
	elif key.keycode == KEY_F10:
		var r: Dictionary = carica_rapido()
		print("[GameState] caricamento rapido: ", "ok" if r.get("ok") else r.get("reason"))


func _progression() -> Node:
	return get_node_or_null("/root/Progression")


func _world() -> Node:
	return get_node_or_null("/root/WorldState")


func _summons() -> Node:
	return get_node_or_null("/root/SummonRegistry")


func _eventi() -> Node:
	return get_node_or_null("/root/EventTracker")


func salva_rapido() -> Dictionary:
	return get_node("/root/SaveSystem").call("salva", SLOT_RAPIDO, snapshot())


func carica_rapido() -> Dictionary:
	var r: Dictionary = get_node("/root/SaveSystem").call("carica", SLOT_RAPIDO)
	if r.get("ok", false):
		applica(r["dati"])
	return r


## Raccoglie lo stato dal giocatore vivo. Se non c'e' un giocatore in scena,
## salva comunque nome e tempo.
func snapshot() -> Dictionary:
	var dati: Dictionary = {
		"nome_personaggio": nome_personaggio,
		"tempo_gioco": tempo_gioco,
		"posizione": Vector2.ZERO,
		"statistiche": {},
		"evocazioni": _summons().per_salvataggio() if _summons() != null else [],
		"progressione": _progression().per_salvataggio() if _progression() != null else {},
		"mondo": _world().per_salvataggio() if _world() != null else {},
		"eventi": _eventi().per_salvataggio() if _eventi() != null else {},
	}
	var p: Node = get_tree().get_first_node_in_group("player")
	if p is Node2D:
		dati["posizione"] = (p as Node2D).global_position
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	if stats != null:
		dati["statistiche"] = {
			"hp": float(stats.get("hp")),
			"spiritualita": float(stats.get("spiritualita")),
		}
	return dati


func applica(dati: Dictionary) -> void:
	nome_personaggio = str(dati.get("nome_personaggio", NOME_DEFAULT))
	tempo_gioco = float(dati.get("tempo_gioco", 0.0))
	if _progression() != null:
		_progression().da_salvataggio(dati.get("progressione", {}))
	if _world() != null:
		_world().da_salvataggio(dati.get("mondo", {}))
	if _summons() != null:
		_summons().da_salvataggio(dati.get("evocazioni", []))
	if _eventi() != null:
		_eventi().da_salvataggio(dati.get("eventi", {}))
	var p: Node = get_tree().get_first_node_in_group("player")
	if p is Node2D and dati.has("posizione"):
		(p as Node2D).global_position = dati["posizione"]
	var stats: Node = p.get_node_or_null("StatsComponent") if p != null else null
	var s: Dictionary = dati.get("statistiche", {})
	if stats != null and s.has("hp"):
		stats.set("hp", float(s["hp"]))
