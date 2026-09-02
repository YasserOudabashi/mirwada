extends SceneTree
## Esecutore della suite headless.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Esce 0 se tutto passa, 1 al primo fallimento. Scopre da solo ogni
## tests/test_*.gd: aggiungere un test non richiede di toccare questo file.
##
## Aspetta un frame prima di partire perche' gli autoload NON esistono ancora
## dentro _init(): senza l'attesa, ogni test su GameData troverebbe null.

const TESTS_DIR := "res://tests"


func _init() -> void:
	await process_frame

	var files: PackedStringArray = _discover()
	if files.is_empty():
		print("NESSUN file di test trovato in %s — la discovery e' rotta." % TESTS_DIR)
		quit(1)
		return

	var total := 0
	var failed := 0
	var all_failures: PackedStringArray = []

	for path in files:
		var script: GDScript = load(path)
		if script == null:
			all_failures.append("%s: impossibile caricare lo script" % path)
			failed += 1
			continue

		var suite: RefCounted = script.new()
		var suite_name: String = path.get_file().get_basename()

		for m in suite.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			total += 1
			suite.failures = PackedStringArray()
			# Setup comune opzionale: una suite che dichiara prepara() la fa
			# eseguire prima di ogni suo test (stato pulito, US-025).
			if suite.has_method("prepara"):
				suite.call("prepara")
			suite.call(mname)
			var fails: PackedStringArray = suite.failures
			if fails.is_empty():
				print("  ok   %s.%s" % [suite_name, mname])
			else:
				failed += 1
				print("  FAIL %s.%s" % [suite_name, mname])
				for f in fails:
					all_failures.append("%s.%s — %s" % [suite_name, mname, f])
					print("       %s" % f)

	print("")
	if total == 0:
		print("0 test eseguiti: i file ci sono ma nessun metodo test_. Falso verde.")
		quit(1)
		return
	if failed == 0:
		print("%d test, tutti passati." % total)
		quit(0)
	else:
		print("%d test, %d FALLITI:" % [total, failed])
		for f in all_failures:
			print("  - %s" % f)
		quit(1)


func _discover() -> PackedStringArray:
	var out := PackedStringArray()
	for n in DirAccess.get_files_at(TESTS_DIR):
		if n.begins_with("test_") and n.ends_with(".gd") and n != "test_case.gd":
			out.append(TESTS_DIR.path_join(n))
	out.sort()  # ordine stabile fra macchine
	return out
