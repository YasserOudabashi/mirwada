#!/usr/bin/env bash
# Suite headless + controllo sugli errori nascosti.
#
#   bash tools/run_tests.sh            (GODOT=/percorso/godot per un binario diverso)
#
# GDScript non ha eccezioni: un errore di script dentro un test lo interrompe a
# meta' e tests/run_tests.gd lo conta come superato (succedeva a 3 test fino al
# 2026-10-25). Qui la suite fallisce anche se nell'output compare un errore di
# script o di formattazione. Gli ERROR di push_error() voluti dai test non contano.
set -u
GODOT="${GODOT:-godot}"
RADICE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp)"
"$GODOT" --headless --path "$RADICE" --script res://tests/run_tests.gd 2>&1 | tee "$OUT"
CODICE=${PIPESTATUS[0]}
if grep -nE "SCRIPT ERROR|not all arguments converted|not enough arguments for format string" "$OUT"; then
	echo ""
	echo "ERRORI DI SCRIPT NEI TEST (righe sopra): un test interrotto a meta' risulta superato. Vanno corretti."
	CODICE=1
fi
rm -f "$OUT"
exit "$CODICE"
