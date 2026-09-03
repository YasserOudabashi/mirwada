extends Area2D
## Zona vulnerabile di un'entita'. Ogni cosa che puo' subire danno (giocatore,
## nemici, manichino) ne ha una come figlia. Instrada il colpo sullo
## StatsComponent del genitore e lo stagger sulla sua PosturaComponent, ed
## emette un segnale, cosi' chi anima o fa suonare le cose non deve sapere
## come sono fatte le statistiche.
##
## Layer di collisione: 3 (le hitbox degli attacchi montano la mask su 3).
##
## NIENTE class_name: coerente col progetto.

signal colpito(danno: float, stagger: float, da: Node, tag_danno: String)
## Emesso quando una parata intercetta un colpo. perfetta=true -> danno
## annullato; false -> danno ridotto. attaccante e' l'origine del colpo.
signal parata_riuscita(perfetta: bool, attaccante: Node)
## Emesso quando l'evasione fa mancare del tutto un colpo (US-218B).
signal schivato(da: Node)

enum Parata { NESSUNA, BLOCCO, PERFETTA }

## Se true, un colpo con da == proprietario viene ignorato (niente autodanno).
@export var ignora_proprietario: bool = true

var _invulnerabile: bool = false
var _parata: int = Parata.NESSUNA
var _riduzione_blocco: float = 0.5
## RNG del tiro di schivata. Seedabile per test/replay deterministici.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func configura_blocco(riduzione: float) -> void:
	_riduzione_blocco = clampf(riduzione, 0.0, 1.0)


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Chiamata dalle hitbox. Applica danno e stagger, passando per parata e
## schivata. extra: { tag_danno: String } (US-218B), retrocompatibile.
func subisci(danno: float, stagger: float, da: Node, extra: Dictionary = {}) -> void:
	if _invulnerabile:
		return
	if ignora_proprietario and da != null and (da == owner or da == get_parent()):
		return

	var tag: String = str(extra.get("tag_danno", ""))
	var d: float = danno
	var s: float = stagger
	if _parata == Parata.PERFETTA:
		d = 0.0
		s = 0.0
		parata_riuscita.emit(true, da)
	elif _parata == Parata.BLOCCO:
		d *= (1.0 - _riduzione_blocco)
		parata_riuscita.emit(false, da)

	var stats: Node = _cerca("spend_spiritualita")

	# Tiro di schivata: prob = clamp(evasione_bersaglio - precisione_attaccante,
	# 0, cap). Solo se c'e' ancora danno da subire.
	if d > 0.0 and stats != null and stats.has_method("get_stat"):
		var evasione: float = float(stats.call("get_stat", "evasione"))
		var prob: float = clampf(evasione - _precisione(da), 0.0, _cap_schivata())
		if prob > 0.0 and _rng.randf() < prob:
			schivato.emit(da)
			return

	if stats != null and d > 0.0:
		# Lo scudo (primitiva shield) assorbe prima degli hp — ora col tag.
		if stats.has_method("assorbi_danno"):
			d = stats.call("assorbi_danno", d, tag)
		if d > 0.0:
			stats.set("hp", float(stats.get("hp")) - d)

	var postura: Node = _cerca("erodi")
	if postura != null and s > 0.0:
		postura.call("erodi", s)

	colpito.emit(d, s, da, tag)


func _precisione(da: Node) -> float:
	if da == null:
		return 0.0
	if da.has_method("get_stat"):
		return float(da.call("get_stat", "precisione"))
	var sc: Node = da.get_node_or_null("StatsComponent")
	if sc == null:
		for c in da.get_children():
			if c.has_method("get_stat"):
				sc = c
				break
	return float(sc.call("get_stat", "precisione")) if sc != null else 0.0


func _cap_schivata() -> float:
	var gd: Node = Engine.get_main_loop().root.get_node_or_null("GameData")
	var c: Dictionary = gd.call("get_balance", "combattimento") if gd != null else {}
	var v: Variant = c.get("cap_schivata", 0.85)
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0.85


## Gli i-frame del dash (US-009) la accendono.
func set_invulnerabile(v: bool) -> void:
	_invulnerabile = v


func e_invulnerabile() -> bool:
	return _invulnerabile


func set_parata(stato: int) -> void:
	_parata = stato


func stato_parata() -> int:
	return _parata


func _cerca(metodo: String) -> Node:
	var p: Node = get_parent()
	if p == null:
		return null
	if p.has_method(metodo):
		return p
	for c in p.get_children():
		if c.has_method(metodo):
			return c
	return null
