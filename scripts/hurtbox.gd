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

signal colpito(danno: float, stagger: float, da: Node)
## Emesso quando una parata intercetta un colpo. perfetta=true -> danno
## annullato; false -> danno ridotto. attaccante e' l'origine del colpo.
signal parata_riuscita(perfetta: bool, attaccante: Node)

enum Parata { NESSUNA, BLOCCO, PERFETTA }

## Se true, un colpo con da == proprietario viene ignorato (niente autodanno).
@export var ignora_proprietario: bool = true

var _invulnerabile: bool = false
var _parata: int = Parata.NESSUNA
var _riduzione_blocco: float = 0.5


func configura_blocco(riduzione: float) -> void:
	_riduzione_blocco = clampf(riduzione, 0.0, 1.0)


## Chiamata dalle hitbox. Applica danno e stagger, passando per la parata.
func subisci(danno: float, stagger: float, da: Node) -> void:
	if _invulnerabile:
		return
	if ignora_proprietario and da != null and (da == owner or da == get_parent()):
		return

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
	if stats != null and d > 0.0:
		stats.set("hp", float(stats.get("hp")) - d)

	var postura: Node = _cerca("erodi")
	if postura != null and s > 0.0:
		postura.call("erodi", s)

	colpito.emit(d, s, da)


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
