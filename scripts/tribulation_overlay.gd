extends CanvasLayer
## Overlay della tribolazione in corso (fase 7, US-713). Vive fuori dal libro,
## sotto l'overlay della follia. Mostra: nome e descrizione della prova,
## l'handicap 'mentre_in_corso' attivo, il progresso verso il superamento.
##
## Reattivo dal vivo: ascolta i segnali di TribulationSystem. Nessun testo
## hardcoded - nomi/descrizioni da GameData.tr_data, chrome da tr().
##
## NIENTE class_name: coerente col progetto.

@onready var _pannello: Panel = $Pannello
@onready var _v: VBoxContainer = $Pannello/V
@onready var _nome: Label = $Pannello/V/Nome
@onready var _descrizione: Label = $Pannello/V/Descrizione
@onready var _effetto: Label = $Pannello/V/Effetto
@onready var _progresso: Label = $Pannello/V/Progresso

## Altezza minima del pannello (design originale, US-713): sotto questa
## soglia non si restringe mai, anche con descrizioni corte.
const _ALTEZZA_MIN := 84.0
## Margine verticale della VBoxContainer dentro il Pannello (offset_top 6 +
## offset_bottom 6 nella scena): va sommato all'altezza del contenuto.
const _MARGINE_V := 12.0

var _ts: Node = null
var _da: int = -1
var _prog: float = 0.0


func _ready() -> void:
	_ts = get_node_or_null("/root/TribulationSystem")
	if _ts != null:
		_ts.connect("tribolazione_attivata", _on_attivata)
		_ts.connect("progresso_cambiato", _on_progresso)
		_ts.connect("tribolazione_superata", _on_superata)
	_sincronizza()


## Riallinea l'overlay allo stato corrente (partenza, load).
func _sincronizza() -> void:
	if _ts == null:
		_pannello.visible = false
		return
	var s: Dictionary = _ts.call("stato")
	if bool(s.get("in_corso", false)):
		_da = int(s.get("da", -1))
		_prog = float(s.get("progresso", 0.0))
	else:
		_da = -1
	_ridisegna()


func _on_attivata(da: int) -> void:
	_da = da
	_prog = 0.0
	_ridisegna()


func _on_progresso(da: int, progresso: float) -> void:
	if da == _da:
		_prog = progresso
		_ridisegna()


func _on_superata(_salto: int) -> void:
	_da = -1
	_ridisegna()


func _ridisegna() -> void:
	_pannello.visible = _da != -1
	if _da == -1:
		return
	var gd: Node = get_node_or_null("/root/GameData")
	if gd == null:
		return
	var t: Dictionary = gd.call("tribulation_per_salto", _da)
	_nome.text = str(gd.call("tr_data", t.get("name_i18n", "")))
	_descrizione.text = str(gd.call("tr_data", t.get("descrizione_i18n", "")))
	_effetto.text = tr("TRIB_OVERLAY_EFFETTO") + " " + tr("TRIB_EFFETTO_" + str(t.get("mentre_in_corso", "")).to_upper())
	_progresso.text = "%s %d%%" % [tr("TRIB_OVERLAY_PROGRESSO"), int(round(_prog * 100.0))]
	_adatta_altezza()


## US-post-9 (bug report utente): la descrizione puo' andare a capo su piu'
## righe di quanto l'altezza fissa del pannello prevedesse, e il testo
## sfondava sopra la hotbar dell'HUD sotto. Il pannello ora cresce con la
## VBoxContainer che lo contiene, senza mai scendere sotto l'altezza
## originale. get_combined_minimum_size() e' sincrono: il testo dei Label
## e' gia' aggiornato qui sopra, la larghezza del Pannello e' fissa
## (offset_left/right), quindi l'autowrap risulta corretto senza aspettare
## un frame - i test leggono stato_mostrato() subito dopo un segnale.
func _adatta_altezza() -> void:
	var contenuto: float = _v.get_combined_minimum_size().y + _MARGINE_V
	var altezza: float = maxf(contenuto, _ALTEZZA_MIN)
	_pannello.offset_bottom = _pannello.offset_top + altezza


# --- Interrogabile dai test -------------------------------------------

func visibile() -> bool:
	return _pannello.visible


func stato_mostrato() -> Dictionary:
	return {"da": _da, "nome": _nome.text, "descrizione": _descrizione.text,
		"effetto": _effetto.text, "progresso": _prog}
