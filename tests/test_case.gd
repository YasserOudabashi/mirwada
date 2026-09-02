extends RefCounted
## Base dei test. Minima di proposito: raccoglie i fallimenti invece di
## interrompere al primo, cosi' un'esecuzione mostra tutti i problemi insieme.

var failures: PackedStringArray = []


func assert_true(condition: bool, what: String) -> void:
	if not condition:
		failures.append("%s: atteso vero, era falso" % what)


func assert_false(condition: bool, what: String) -> void:
	if condition:
		failures.append("%s: atteso falso, era vero" % what)


func assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		failures.append("%s: atteso %s, ottenuto %s" % [what, want, got])


func assert_ne(got: Variant, unwanted: Variant, what: String) -> void:
	if got == unwanted:
		failures.append("%s: non doveva essere %s" % [what, unwanted])


func assert_gt(got: float, threshold: float, what: String) -> void:
	if got <= threshold:
		failures.append("%s: atteso > %s, ottenuto %s" % [what, threshold, got])


func assert_almost_eq(got: float, want: float, what: String, epsilon: float = 0.0001) -> void:
	if absf(got - want) > epsilon:
		failures.append("%s: atteso %s, ottenuto %s" % [what, want, got])
