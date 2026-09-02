extends Area2D
## Zona vulnerabile di un'entita'. Ogni cosa che puo' subire danno (giocatore,
## nemici, manichino) ne ha una come figlia. Instrada il colpo sullo
## StatsComponent del genitore ed emette un segnale, cosi' chi anima o fa
## suonare le cose non deve sapere come sono fatte le statistiche.
##
## Layer di collisione: 3 (le hitbox degli attacchi montano la mask su 3).
##
## NIENTE class_name: coerente col progetto.

signal colpito(danno: float, stagger: float, da: Node)

## Se true, un colpo con da == proprietario viene ignorato (niente autodanno).
@export var ignora_proprietario: bool = true

var _invulnerabile: bool = false


## Chiamata dalle hitbox. Applica il danno allo StatsComponent del genitore.
func subisci(danno: float, stagger: float, da: Node) -> void:
	if _invulnerabile:
		return
	if ignora_proprietario and da != null and (da == owner or da == get_parent()):
		return
	var stats: Node = _stats()
	if stats != null and danno > 0.0:
		stats.set("hp", float(stats.get("hp")) - danno)
	colpito.emit(danno, stagger, da)


## Gli i-frame del dash (US-009) e la parata perfetta (US-010) la accendono.
func set_invulnerabile(v: bool) -> void:
	_invulnerabile = v


func e_invulnerabile() -> bool:
	return _invulnerabile


func _stats() -> Node:
	var p: Node = get_parent()
	if p == null:
		return null
	if p.has_method("spend_spiritualita"):
		return p
	for c in p.get_children():
		if c.has_method("spend_spiritualita"):
			return c
	return null
