"""Diario del progetto Mirwada — rigenera DIARIO_Mirwada.docx.

Come si usa: a ogni chiusura di lavoro AGGIUNGERE una voce in coda a VOCI
(mai riscrivere quelle esistenti), poi rilanciare:

    python diario.py

Stile: prima persona, discorsivo. Lo script rigenera sempre il docx da zero.
"""
from pathlib import Path

from docx import Document
from docx.shared import Pt, RGBColor

PROGETTO = "Mirwada"

# Una voce per giornata di lavoro. Stringa vuota = "(niente da segnalare)".
VOCI = [
    {
        "data": "02.09.2026",
        "lavori": "Nato il progetto e chiusa la prima giornata piena. Prima del codice ho costruito la spina dorsale dei dati (10 Pathway attivi in 4 gruppi completi, 100 Sequenze, registri chiusi di primitive/eventi/tag, validator) e le decisioni irreversibili: Godot 4.3, 32x32 a 640x360, 4 direzioni, timing del combat nei dati, audio come canale informativo. Chiuse le prime 6 story di fase 1: setup, caricatore JSON con hot-reload F5, componente statistiche, motore delle abilita' con le prime 5 primitive — 41 test headless verdi. Fissato il nome Mirwada, repo dedicata, doc di lore col roster di 8 NPC.",
        "problemi": "Il .git/HEAD si era corrotto (conteneva il reflog): riparato con git symbolic-ref. Quattro trappole di Godot 4.3 trovate eseguendo: inferenza di tipo da Variant trattata come errore, class_name che manda in stallo il runner, istanze liberate assegnate a variabili tipate, autoload assenti in _init().",
        "osservazioni": "La prova dell'architettura e' il Twilight Giant: 20 abilita' e 5 rituali interamente in dati, zero codice dedicato.",
    },
    {
        "data": "02.09.2026 (audit e design)",
        "lavori": "Audit completo del progetto in tre passate parallele (codice, dati, documenti) e sessione di design grossa. Risanati subito i problemi critici: leak del nodo melee_arc, heal che ignorava il bersaglio, tag_danno con contratto stringa + vocabolario chiuso nuovo (damage_tags.json), filtro sequenza_min rinominato perche' semanticamente invertito, vocabolario del tempo (time.json) al posto di moon_phase che mescolava momenti e fasi lunari, 89 sequenze stub dichiarate col flag e validator che ora esige recitazione e follia sulle non-stub, parametri delle primitive validati contro il registro, sinergie controllate, floor delle fondamenta. 43 test verdi. Scritti 5 design doc nuovi in 006_PRD/: design-master (baseline, sicurezza del save, contratti, story per fase), design-world (5 regioni, una per gruppo di pathway, gating e tempo), design-npc-quest (roster, dialoghi come dati, quest su EventTracker, tre atti e tre finali), design-ui-libro (tutta la UI come pagine di un libro diegetico che E' il salvataggio), design-vfx (stile manhwa alla Northern Blade: 10 palette visive specchio di quelle audio, VFX per primitiva). Aggiunte a prd.json le story di risanamento US-022..026 e i criteri di sicurezza su US-015. Creato questo scaffolding docx che mancava.",
        "problemi": "Il validator dichiarava valide 90 sequenze vuote (il check della somma di recitazione era bypassato dall'array vuoto): il flag stub esplicito chiude il buco. Trovato anche un crash latente: i dati passano tag_danno come stringa ma gli script lo tipavano Array — sarebbe esploso al primo attacco con dati veri.",
        "osservazioni": "Le decisioni ancora aperte sono elencate con raccomandazione in design-master.md Appendice B: nomi delle regioni, libro diegetico, antagonista, eredita' tra personaggi, taglio delle story di fase 5.",
    },
    {
        "data": "06.09.2026",
        "lavori": "Sessione lunga sulla fase 3. Prima ho sistemato la baseline: c'era un branch remoto parallelo (una sessione cloud) che rivendicava tutta la fase 3 chiusa ma senza aver mai eseguito Godot davvero — scartato, si continua da main, l'unico lavoro verificato. Questo PC non aveva Godot: scaricato l'editor 4.3, e nel farlo ho scoperto che due test di pagina fallivano solo perche' il locale del sistema e' inglese e le asserzioni confrontano la chrome italiana — ora run_tests.gd fissa il locale 'it' a inizio suite, cosi' gira identico ovunque. Poi ho chiuso tre blocchi interi: D (strutture — StructureRegistry piu' colpisce_oggetti, le abilita' d'area rompono anche la base del giocatore), E (pet — schema e magazzino, taming con tiro seedabile, il bond che cresce dagli eventi condivisi e sblocca comportamenti a soglia, la coltivazione del pet che non puo' superare la Sequenza del padrone, e la sua morte che passa da AnchorSystem come perdita di un'Ancora vera, con colpo di follia), F (base building — le 4 stanze coi livelli/costi/bonus nei dati, i sistemi esistenti — alchimia, forgia, biblioteca — che leggono i bonus per chiave senza un solo if sul nome di una stanza, il giardino con appezzamenti che crescono col tempo di gioco e si fermano col libro aperto, e la pagina Base nel libro). Da US-319 a US-329: 11 story, il save da schema 15 a 18, la suite da 399 a 471 test headless, tutti verdi. Ogni story verificata eseguendo Godot per davvero, non solo il validator; quelle con UI o effetti anche a schermo. Riordinate le key art di Gemini in assets/concept/regioni/ come prescrive l'art brief.",
        "problemi": "I 2000 minuti/mese di GitHub Actions dell'account erano esauriti: il workflow partiva a ogni push di ogni branch (i ralph, le sessioni cloud) piu' ogni PR. L'ho reso magro (solo main, niente commit di sola doc, concurrency, cache di Godot) e poi, siccome disabilitarlo via gh CLI era bloccato, ho commentato i trigger automatici lasciando solo l'avvio a mano fino al reset del primo ottobre. Un bug di segno trovato eseguendo: la riduzione del rischio degli esperimenti col laboratorio era negativa e finiva clampata a zero, quindi il bonus non faceva niente — il test statistico sulle aberrazioni l'ha smascherato. E i test di pagina che aprivano il libro due volte nello stesso metodo lasciavano nodi mezzo-distrutti: un test, un'apertura.",
        "osservazioni": "Il pattern 'i ganci prima del sistema' ha pagato: PotionSystem e Forge avevano gia' le chiamate a BaseSystem scritte come no-op da settembre, e con la fase 3 si sono accese da sole. Stessa cosa per pastura_spirituale (il cibo del pet, gia' nei dati da un mese) e i tre ingredienti coltivabili. Resta il blocco G (talenti) per chiudere la fase 3, poi la vertical slice di verdetto sull'architettura (US-335).",
    },
]

BLU = RGBColor(0x1A, 0x23, 0x7E)
GRIGIO = RGBColor(0x80, 0x80, 0x80)
OUTPUT = Path(__file__).parent / f"DIARIO_{PROGETTO}.docx"


def _p(doc, testo, *, bold=False, italic=False, size=None, color=None):
    par = doc.add_paragraph()
    run = par.add_run(testo)
    run.bold = bold
    run.italic = italic
    if size:
        run.font.size = Pt(size)
    if color:
        run.font.color.rgb = color
    return par


def _sezione(doc, etichetta, testo):
    par = doc.add_paragraph()
    run = par.add_run(f"{etichetta}: ")
    run.bold = True
    if testo.strip():
        par.add_run(testo.strip())
    else:
        run2 = par.add_run("(niente da segnalare)")
        run2.italic = True
        run2.font.color.rgb = GRIGIO


def genera():
    doc = Document()
    _p(doc, f"Diario di progetto — {PROGETTO}", bold=True, size=16, color=BLU)
    for voce in VOCI:
        _p(doc, voce["data"], bold=True, size=13, color=BLU)
        _sezione(doc, "1) Lavori effettuati", voce["lavori"])
        _sezione(doc, "2) Problemi riscontrati", voce["problemi"])
        _sezione(doc, "3) Eventuali osservazioni", voce["osservazioni"])
    doc.save(OUTPUT)
    return OUTPUT


if __name__ == "__main__":
    percorso = genera()
    assert percorso.exists() and percorso.stat().st_size > 0, "docx non generato"
    print(f"OK — generato {percorso}")
