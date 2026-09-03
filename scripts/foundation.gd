extends Node
## Fondamenta: qualita' della progressione 0-100. Avanzare in fretta la
## abbassa. Fondamenta basse = follia piu' rapida (moltiplicatore) e, in
## futuro, tetto di potenza piu' basso.
##
## Numeri da data/balance.json.foundation.
##
## NIENTE class_name: coerente col resto del progetto.

signal fondamenta_changed(valore: float)

const _FALLBACK := {
	"iniziale": 50.0, "minimo": 0.0,
	"bonus_recitazione_completa": 8.0,
	"malus_digestione_difficile": -10.0,
	"malus_avanzamento_forzato": -25.0,
	"moltiplicatore_follia_a_fondamenta_zero": 2.5,
}

var _valore: float = -1.0


func _ready() -> void:
	if _valore < 0.0:
		_valore = _num("iniziale")


func applica(delta: float, _sorgente: String) -> void:
	if delta == 0.0:
		return
	_valore = clampf(_valore + delta, _num("minimo"), 100.0)
	fondamenta_changed.emit(_valore)


func valore() -> float:
	return _valore


## Costante di bilanciamento per nome (bonus_recitazione_completa,
## malus_digestione_difficile, malus_avanzamento_forzato).
func costante(nome: String) -> float:
	return _num(nome)


## Moltiplicatore della follia: 1.0 a fondamenta piene, sale fino a
## moltiplicatore_follia_a_fondamenta_zero quando le fondamenta sono a 0.
func moltiplicatore_follia() -> float:
	var m0: float = _num("moltiplicatore_follia_a_fondamenta_zero")
	return lerpf(m0, 1.0, clampf(_valore / 100.0, 0.0, 1.0))


# --- Interno ----------------------------------------------------------

func _num(chiave: String) -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	var f: Dictionary = gd.call("get_balance", "foundation") if gd != null else {}
	var v: Variant = f.get(chiave, _FALLBACK.get(chiave, 0.0))
	return v if typeof(v) in [TYPE_FLOAT, TYPE_INT] else float(_FALLBACK.get(chiave, 0.0))


# --- Salvataggio -----------------------------------------------------

func per_salvataggio() -> Dictionary:
	return {"valore": _valore}


func da_salvataggio(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var v: Variant = d.get("valore", _num("iniziale"))
	_valore = clampf(float(v), _num("minimo"), 100.0) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else _num("iniziale")
	fondamenta_changed.emit(_valore)
