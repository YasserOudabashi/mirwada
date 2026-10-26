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
AGGIORNATO_AL = "26.10.2026"  # data ultimo aggiornamento, formato GG.MM.AAAA

# Le 5 sezioni fisse della documentazione. Testo discorsivo, righe "- " = bullet.
SEZIONI = {
    "Come funziona": """Mirwada e' un action-RPG 2D top-down in pixel art (Godot 4.3, GDScript) con progressione a Pathway e Sequenze: 10 Pathway attivi in 4 gruppi completi, 10 Sequenze ciascuno dalla 9 alla 0, piu' i Pathway non-standard che avanzano per Boon. Il gioco si avvia, si crea il personaggio nel libro (nome, Pathway, due talenti innati, modalita' facile o difficile) e si gioca in un mondo unico di 1200 x 1000 caselle.

Il principio architetturale e' uno: il codice implementa primitive parametriche (28 attive), i dati JSON le compongono in abilita'. I registri sono CHIUSI (primitive, 12 eventi tracciabili, tag, tipi di pagina e di gate): aggiungere una voce e' una decisione, non un gesto.

- Mondo: generato una volta dal generatore forge3d (seed 6) e salvato come dati in assets/world/: tessere 32x32 gia' composte e deduplicate (circa 34.600 per modalita'), indici, collisioni (blocchi.png: 0 libera, 128 dislivello, 255 acqua o vuoto), mappa delle regioni, oggetti di scena e il sottosuolo come secondo livello. scripts/world/mondo.gd costruisce solo i blocchi attorno al giocatore.
- Regioni: la regione e la zona vengono dalla posizione (musica, densita' mistica, gating). Alle Marche del Crepuscolo si arriva solo volando o dal sottosuolo (le catacombe sbucano nelle Marche); la Frontiera respinge chi e' oltre la Sequenza 4.
- Contenuto: gli NPC stanno al luogo del loro orario con il proprio aspetto; nemici, boss e oggetti dei layout delle fasi 8-11 sono riportati sul mondo generato (il boss di Mirwada vive nelle fogne).
- Due modalita': facile = mondo luminoso; difficile = mondo cupo come le concept e numeri del combattimento piu' duri (data/modalita.json). Si sceglie a inizio partita e va nel salvataggio.
- Il libro e' tutta l'interfaccia (scaffale, frontespizio, diagramma dei Pathway, inventario, mappa, dialoghi, colophon), con copertina di cuoio, pergamena e font Alegreya.
- data/: pathways, abilities, synergies, schema/ (registri), animations.json (timing del combat), audio.json, balance.json, world/ (regioni, layout, campagna, interni), npc/, ui/book.json.
- tools/: validate_data.py (esce 0/1), run_tests.sh (suite + controllo degli errori nascosti), art/ (generatori rilanciabili: personaggi, NPC, mondo, libro).
- tests/: circa 980 test headless.""",
    "Perché funziona così": """Tutto e' data-driven perche' il progetto e' enorme per una persona: aggiungere contenuto deve costare una riga di JSON e mai una classe. La prova: dieci Pathway completi con zero righe di codice che ne nominino uno.

- I nomi (opera di riferimento protetta) vivono solo nei dati e nelle chiavi i18n: il flag SERIAL_NUMBERS_FILED_OFF permette la rinominazione completa.
- L'arte la genera Claude con sprite-forge (forge3d): ogni asset esce da uno script rilanciabile con un seed, in palette Endesga 32, e si guarda ingrandito prima di consegnarlo. Mai PNG ritoccati a mano.
- Il mondo si genera una volta e si salva come dati: il gioco non rigenera nulla a runtime, e le correzioni si fanno nel generatore o nei dati. Per questo le collisioni, le regioni e il sottosuolo sono immagini lette dal disco, e il contenuto dei vecchi layout si riporta sul mondo con una regola (luogo della zona o posizione relativa) invece di essere ridisegnato.
- Le decisioni di gioco stanno nei dati: come si arriva in una regione (regions.json "accesso"), dove non compaiono nemici (balance.json), l'aspetto del libro (book.json "tema").
- La suite fallisce anche se un test si interrompe a meta' per un errore di script (tools/run_tests.sh): GDScript non ha eccezioni e prima quei test risultavano superati.""",
    "Come deployarlo": """Non c'e' ancora una build distribuibile: il gioco si avvia dall'editor o da riga di comando.

- Godot 4.3. Prima volta e dopo aver cambiato le PNG: godot --headless --path . --import.
- Python 3 per i dati (nessuna dipendenza); numpy e Pillow per tools/art/ e la mappa; python-docx per questa documentazione.
- Verifica completa: python tools/validate_data.py (esce 0) e bash tools/run_tests.sh (esce 0, GODOT=percorso se il binario non e' sul PATH).
- CI: GitHub Actions su push a main e sulle pull request (validator + suite con il controllo degli errori nascosti).
- Rigenerare l'arte: tools/art/build_personaggi.py, build_npc.py, build_libro.py; il mondo con tools/art/esporta_mondo.py (circa 1 ora per tutto; --solo-blocchi, --sottosuolo, --solo-dati per le parti).
- Repo: https://github.com/YasserOudabashi/mirwada. Nota IP nel CLAUDE.md: non distribuibile ne' monetizzabile coi nomi attuali.""",
    "Cosa migliorare": """Dal controllo completo del 25.10.2026 e dal lavoro dei giorni dopo:

- Mirwada non ha edifici: la citta' ha i sedimi degli isolati (le aree di pietra) ma il generatore non disegna ancora case; per lo stesso motivo le porte verso gli interni delle fasi 10-11 non sono ancora sul mondo generato.
- Gli interni usano ancora il tileset segnaposto a 32 px; le icone degli oggetti a terra sono segnaposto.
- Volo: il meccanismo c'e' (i dislivelli hanno uno strato di collisione che chi vola non sente), ma manca la decisione su chi sa volare e come.
- Non si raggiungono la Frontiera (decisione aperta su come arrivarci) e le isole (servono le barche).
- Acqua ferma, alberi senza collisione, terreno a 32 px per casella con personaggi a 64 (pixel di grana diversa).
- La primitiva teleport sposta il giocatore senza controllare le collisioni.
- Le pagine del libro sono impaginate su tutta la doppia pagina e passano sopra la piega; gli interruttori del colophon hanno ancora il disegno di Godot.
- Il repository cresce di circa 18 MB a ogni esportazione completa del mondo.""",
    "Prossimi punti": """- Edifici di Mirwada sugli isolati del generatore, case dei villaggi e porte verso gli interni (US-8B18), poi gli interni con l'arte vera.
- Decidere chi sa volare e come (US-8B93), e come si arriva alla Frontiera; poi barche e isole (US-8B91).
- Varchi di gating visibili e barriere delle sotto-aree sul mondo (US-8B21).
- Icone degli oggetti, degli stati e delle primitive (US-8B70..72), panorami (US-8B74), VFX (US-8B40..44).
- Fase 12: Atto II e III e Mondo vivo (PRD in 006_PRD/).""",
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
