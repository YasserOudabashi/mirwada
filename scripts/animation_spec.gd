extends RefCounted
## Vista tipata e di sola lettura su una voce di data/animations.json.
##
## Tutto cio' che serve alla macchina di animazione (US-021b) e al
## combattimento (US-008/009/010) per leggere il timing DAI DATI:
##   - la fase di un frame (anticipo / attivi / recupero)
##   - gli eventi dichiarati su un frame (hitbox_on, tell_audio, footstep...)
##   - la finestra di invulnerabilita' del dash (iframe_da/a)
##   - la finestra di parata perfetta
##   - durata reale in secondi (frames / fps)
##
## Cambiare un fps o un indice nel JSON cambia il comportamento senza
## toccare il codice: e' l'obiettivo di US-021.
##
## NIENTE class_name: coerente col progetto, i test fanno preload.

var _a: Dictionary


func _init(anim: Dictionary) -> void:
	_a = anim


func is_valid() -> bool:
	return not _a.is_empty() and frame_count() > 0


func frame_count() -> int:
	return int(_a.get("frames", 0))


func fps() -> float:
	return float(_a.get("fps", 12.0))


func loops() -> bool:
	return bool(_a.get("loop", false))


func is_directional() -> bool:
	return bool(_a.get("direzionale", false))


## Durata di un ciclo in secondi. 0 se fps non valido.
func duration_sec() -> float:
	var f: float = fps()
	return 0.0 if f <= 0.0 else float(frame_count()) / f


## "anticipo" | "attivi" | "recupero" | "". La hitbox di US-008 e' aperta
## nei frame "attivi"; il tell di US-011 parte nell'"anticipo".
func phase_of(frame: int) -> String:
	for fase in ["anticipo", "attivi", "recupero"]:
		if frames_in_phase(fase).has(frame):
			return fase
	return ""


## Indici (int) dei frame di una fase. JSON legge i numeri come float:
## la conversione qui evita che Array.has(int) fallisca a valle.
func frames_in_phase(fase: String) -> Array:
	var out: Array = []
	for idx in (_a.get(fase, []) as Array):
		out.append(int(idx))
	return out


## Nomi degli eventi dichiarati su quel frame. Piu' eventi sullo stesso
## frame sono ammessi (nemico_base.anticipo: tell_audio + tell_visivo).
func events_at(frame: int) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in (_a.get("eventi", []) as Array):
		var ev: Dictionary = entry
		if int(ev.get("frame", -1)) == frame:
			out.append(str(ev.get("evento", "")))
	return out


## true se in quel frame va aperta/chiusa la hitbox.
func has_event_at(frame: int, evento: String) -> bool:
	return evento in events_at(frame)


## [da, a] inclusi, in FRAME. Vector2i(-1, -1) se l'animazione non ha
## i-frame (solo il dash del personaggio li dichiara).
func iframe_window() -> Vector2i:
	if not _a.has("iframe_da"):
		return Vector2i(-1, -1)
	var da: int = int(_a["iframe_da"])
	return Vector2i(da, int(_a.get("iframe_a", da)))


func is_invulnerable_at(frame: int) -> bool:
	var w: Vector2i = iframe_window()
	return w.x >= 0 and frame >= w.x and frame <= w.y


## Frame della finestra di parata perfetta ([] se non e' una parata).
func perfect_parry_frames() -> Array:
	var out: Array = []
	for idx in (_a.get("finestra_perfetta", []) as Array):
		out.append(int(idx))
	return out


func is_perfect_parry_at(frame: int) -> bool:
	return perfect_parry_frames().has(frame)


## Stato di animazione separato che fa da anticipo (nemico_base.attack ->
## "anticipo"): "" quando l'anticipo e' nei frame interni.
func prefix_state() -> String:
	return str(_a.get("anticipo_in_stato", ""))
