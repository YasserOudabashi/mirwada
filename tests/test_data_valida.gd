extends "res://tests/test_case.gd"
## US-014 — il validator dei dati Python gira dentro la suite. Un JSON
## strutturalmente rotto committato deve far fallire i test, non aspettare
## che qualcuno lanci lo script a mano.

func test_validate_data_esce_zero() -> void:
	var script_path: String = ProjectSettings.globalize_path("res://tools/validate_data.py")
	var out: Array = []

	var code: int = -1
	for py in ["python", "python3", "py"]:
		code = OS.execute(py, [script_path], out, true)
		if code != -1:
			break

	if code == -1:
		push_warning("[test_data_valida] nessun interprete Python trovato: "
			+ "il validator NON e' stato eseguito. In CI deve esserci Python.")
		return

	if code != 0:
		var testo: String = "\n".join(out)
		failures.append("tools/validate_data.py e' uscito con codice %d:\n%s" % [code, testo])
