"""Documentazione del progetto Mirwada — rigenera Documentazione_Mirwada.docx.

Come si usa: aggiornare i testi in SEZIONI (e AGGIORNATO_AL), poi rilanciare:

    python docs/documentazione.py

Lo script rigenera sempre il docx da zero (idempotente). Le righe che iniziano
con "- " diventano elenchi puntati; le righe vuote separano i paragrafi.
"""
from pathlib import Path

from docx import Document
from docx.shared import Pt, RGBColor

PROGETTO = "Mirwada"
AGGIORNATO_AL = "02.09.2026"  # data ultimo aggiornamento, formato GG.MM.AAAA

# Le 5 sezioni fisse della documentazione. Testo discorsivo, righe "- " = bullet.
SEZIONI = {
    "Come funziona": """Mirwada e' un action-RPG 2D top-down (Godot 4.3, GDScript, pixel art 32x32, base 640x360) con progressione a Pathway e Sequenze: 10 Pathway attivi in 4 gruppi completi, 10 Sequenze ciascuno dalla 9 (novizio) alla 0 (Vero Dio). Altri 12 Pathway restano differiti, completi ma fuori scope.

Il principio architetturale e' uno: il codice implementa 28 primitive parametriche (projectile, buff_stat, summon, teleport...), i dati JSON le compongono in abilita'. I registri sono CHIUSI: 28+3 primitive, 12 eventi tracciabili, 82 tag di sinergia, 8 tag di danno, vocabolario del tempo. Aggiungere una voce a un registro e' una decisione, non un gesto.

- data/: pathways (100 sequenze), abilities (32), synergies, schema/ (registri e vocabolari), animations.json (timing del combat NEI DATI), audio.json (feedback, tell sonori, follia, palette timbriche per pathway), balance.json.
- scripts/: GameData (caricatore con hot-reload F5), AbilityEngine (dispatch tipo->Callable), StatsComponent (base + modificatori per id), projectile e melee_arc.
- tools/: validate_data.py (~50 regole, esce 0/1), generate_pathways.py (spina dorsale idempotente), generate_placeholders.py (324 frame diagnostici).
- tests/: 43 test headless (godot --headless --script res://tests/run_tests.gd).
- 006_PRD/: roadmap fasi 2-8, PRD fase 1, e i design doc (master, pathways, lore, world, npc-quest, ui-libro, vfx).""",
    "Perché funziona così": """Tutto e' data-driven perche' il progetto e' enorme per una persona: 100 sequenze, ~200 abilita' potenziali, 4-6 regioni. L'unico modo di reggerlo e' che aggiungere contenuto costi una riga di JSON e mai una classe. La prova che regge: il Twilight Giant e' completo dalla Sequenza 9 alla 0 (20 abilita', 5 rituali) con zero righe di codice dedicate.

- I nomi (gioco di riferimento protetto da IP) vivono SOLO nei dati e nelle chiavi i18n: il flag SERIAL_NUMBERS_FILED_OFF permette la rinominazione completa in un pomeriggio.
- Il timing del combat (anticipo, frame attivi, iframe, parata perfetta) sta in animations.json: tarare il feel costa secondi, non ricompilazioni.
- L'audio e' un canale informativo (tell sonori distinti per categoria, sussurri della follia, percezione che cresce con la Sequenza), e ogni informazione audio ha l'equivalente visivo attivabile (FR-8, accessibilita').
- Il validator e' la cintura di sicurezza dei registri chiusi: parametri delle primitive, tag di danno, sequenze stub dichiarate, vocabolario del tempo, sinergie raggiungibili. Deve uscire 0 prima di ogni commit.""",
    "Come deployarlo": """Non c'e' ancora una build distribuibile (fase 1 in corso, il gioco e' motore + dati). Ambiente di lavoro:

- Godot 4.3 (eseguibile locale nella cartella Godot_v4.3-stable_win64.exe/, gitignorato).
- Python 3 per i tool dei dati (nessuna dipendenza; Pillow solo per generate_placeholders.py; python-docx per questa documentazione).
- Verifica completa: python tools/validate_data.py (esce 0) e godot --headless --path . --script res://tests/run_tests.gd (esce 0).
- Repo privata: https://github.com/YasserOudabashi/mirwada. Nota IP nel CLAUDE.md: non distribuibile ne' monetizzabile coi nomi attuali.
- Cicli autonomi con ralph: bash ~/.claude/skills/ralph.sh 26 --fase 1 --test-cmd "python tools/validate_data.py" (il --test-cmd NON e' opzionale, vedi README).""",
    "Cosa migliorare": """Dall'audit completo del 02.09.2026 (tre passate su codice, dati e documenti):

- Il gioco e' ancora una finestra nera: tutte le story visibili a schermo (movimento, camera, combat, HUD) sono aperte e richiedono verifica con l'editor.
- 5 primitive implementate su 31, i dati ne usano 20: buona parte delle 32 abilita' e' parziale o no-op a runtime finche' le primitive non arrivano.
- 89 sequenze su 100 sono stub dichiarati: il contenuto dei 9 pathway oltre il Twilight Giant e' materia di fase 5, con la matrice di proprieta' del design-master a prevenire le sovrapposizioni.
- Robustezza: i JSON di gioco sono ancora trattati come fidati dal loader (US-022); cooldown e indici non si purgano (US-023); stats di partenza in parte hardcoded (US-024); test con conteggi fragili (US-025); niente CI (US-026).
- i18n promesso dal giorno 1 ma nessun file di locale esiste: ~250 chiavi puntano nel vuoto (story R-12, fase 2).""",
    "Prossimi punti": """- Chiudere la fase 1: US-004..US-021 (movimento, camera, tilemap, combat, save sicuro secondo i criteri nuovi di US-015, HUD, audio, animazioni) + le story di risanamento US-022..US-026.
- Fase 2: eseguire il Twilight Giant per davvero (pozioni, EventTracker, Acting, follia, rituali), shell della UI a libro con diagramma dei Pathway e impostazioni, data/vfx.json con le 10 palette visive.
- I PRD di fase si generano con /prd SOLO a fase precedente chiusa, pescando dai design doc in 006_PRD/ (design-master.md e' l'indice).
- Decisioni aperte elencate in design-master.md Appendice B (nomi delle regioni, libro diegetico, antagonista, eredita' tra personaggi...).""",
}

BLU = RGBColor(0x1A, 0x23, 0x7E)
OUTPUT = Path(__file__).parent / f"Documentazione_{PROGETTO}.docx"


def _p(doc, testo, *, bold=False, size=None, color=None):
    par = doc.add_paragraph()
    run = par.add_run(testo)
    run.bold = bold
    if size:
        run.font.size = Pt(size)
    if color:
        run.font.color.rgb = color
    return par


def _corpo(doc, testo):
    """Rende un blocco di testo: bullet per righe '- ', paragrafi per il resto."""
    for riga in [r.strip() for r in testo.strip().splitlines()]:
        if not riga:
            continue
        if riga.startswith("- "):
            doc.add_paragraph(riga[2:], style="List Bullet")
        else:
            doc.add_paragraph(riga)


def genera():
    doc = Document()
    _p(doc, f"Documentazione — {PROGETTO}", bold=True, size=16, color=BLU)
    _p(doc, f"Aggiornata al: {AGGIORNATO_AL}", size=10)
    for titolo, testo in SEZIONI.items():
        _p(doc, titolo, bold=True, size=13, color=BLU)
        if testo.strip():
            _corpo(doc, testo)
        else:
            _p(doc, "(da compilare)")
    doc.save(OUTPUT)
    return OUTPUT


if __name__ == "__main__":
    percorso = genera()
    assert percorso.exists() and percorso.stat().st_size > 0, "docx non generato"
    print(f"OK — generato {percorso}")
