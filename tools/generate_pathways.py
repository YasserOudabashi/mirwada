#!/usr/bin/env python3
"""
Genera i 22 file data/pathways/*.json con tutte e 220 le Sequenze.

Esecuzione (dalla root del progetto):
    python tools/generate_pathways.py

Idempotente per la struttura: NON sovrascrive i campi gia' popolati
(abilities, acting_actions, potion) se il file esiste gia'. Serve per
poter rigenerare la spina dorsale senza perdere il lavoro fatto.
"""

import json
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "pathways")
DEFERRED_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "pathways_deferred")

# Ordine: Sequenza 9 -> Sequenza 0
# (id_pathway, nome_pathway, gruppo, [10 nomi di sequenza], verbo_di_gioco, tag_principali)
PATHWAYS = [
    ("fool", "Fool", "lord_of_mysteries",
     ["Seer", "Clown", "Magician", "Faceless", "Marionettist", "Bizarro Sorcerer",
      "Scholar of Yore", "Miracle Invoker", "Attendant of Mysteries", "Fool"],
     "Falsificare la realta' e controllare i nemici come marionette",
     ["inganno", "spirito", "destino", "illusione"]),

    ("error", "Error", "lord_of_mysteries",
     ["Marauder", "Swindler", "Cryptologist", "Prometheus", "Dream Stealer", "Parasite",
      "Mentor of Deceit", "Trojan Horse of Destiny", "Worm of Time", "Error"],
     "Rubare le abilita' altrui e sfruttare i buchi nelle regole",
     ["furto", "inganno", "tempo", "parassita"]),

    ("door", "Door", "lord_of_mysteries",
     ["Apprentice", "Trickmaster", "Astrologer", "Scribe", "Traveler", "Secrets Sorcerer",
      "Wanderer", "Planeswalker", "Key of Stars", "Door"],
     "Attraversare lo spazio e replicare i poteri osservati",
     ["spazio", "viaggio", "stella", "occultamento"]),

    ("visionary", "Visionary", "god_almighty",
     ["Spectator", "Telepathist", "Psychiatrist", "Hypnotist", "Dreamwalker", "Manipulator",
      "Dream Weaver", "Discerner", "Author", "Visionary"],
     "Leggere e riscrivere la psiche, combattere dentro i sogni",
     ["mente", "sogno", "emozione", "controllo"]),

    ("sun", "Sun", "god_almighty",
     ["Bard", "Light Supplicant", "Solar High Priest", "Notary", "Priest of Light", "Unshadowed",
      "Justice Mentor", "Lightseeker", "White Angel", "Sun"],
     "Purificare, benedire e ridurre la Sequenza dei nemici",
     ["luce", "purificazione", "contratto", "fuoco"]),

    ("tyrant", "Tyrant", "god_almighty",
     ["Sailor", "Folk of Rage", "Seafarer", "Wind-blessed", "Ocean Songster", "Cataclysmic Interrer",
      "Sea King", "Calamity", "Thunder God", "Tyrant"],
     "Dominare mare, vento e fulmine su scala ambientale",
     ["acqua", "tempesta", "fulmine", "vento"]),

    ("white_tower", "White Tower", "god_almighty",
     ["Reader", "Student of Ratiocination", "Detective", "Polymath", "Mysticism Magister", "Prophet",
      "Cognizer", "Wisdom Angel", "Omniscient Eye", "White Tower"],
     "Rivelare informazioni e imitare i poteri analizzandoli",
     ["conoscenza", "analisi", "verita'", "predizione"]),

    ("hanged_man", "Hanged Man", "god_almighty",
     ["Secrets Supplicant", "Listener", "Shadow Ascetic", "Rose Bishop", "Shepherd", "Black Knight",
      "Trinity Templar", "Profane Presbyter", "Dark Angel", "Hanged Man"],
     "Usare l'ombra come risorsa e ascoltare i sussurri nascosti",
     ["ombra", "sangue", "depravazione", "sussurro"]),

    ("darkness", "Darkness", "eternal_darkness",
     ["Sleepless", "Midnight Poet", "Nightmare", "Soul Assurer", "Spirit Warlock", "Nightwatcher",
      "Horror Bishop", "Servant of Concealment", "Knight of Misfortune", "Darkness"],
     "Dominare la notte, le anime e il sonno; infliggere sfortuna",
     ["notte", "anima", "sonno", "occultamento"]),

    ("death", "Death", "eternal_darkness",
     ["Corpse Collector", "Gravedigger", "Spirit Medium", "Spirit Guide", "Gatekeeper", "Undying",
      "Ferryman", "Death Consul", "Pale Emperor", "Death"],
     "Evocare i morti e attraversare il mondo spirituale",
     ["morte", "spirito", "decadimento", "non_morto"]),

    ("twilight_giant", "Twilight Giant", "eternal_darkness",
     ["Warrior", "Pugilist", "Weapon Master", "Dawn Paladin", "Guardian", "Demon Hunter",
      "Silver Knight", "Glory", "Hand of God", "Twilight Giant"],
     "Combattere in prima linea con armi di luce e difesa assoluta",
     ["arma", "difesa", "luce", "decadimento"]),

    ("demoness", "Demoness", "calamity_of_destruction",
     ["Assassin", "Instigator", "Witch", "Pleasure", "Affliction", "Despair",
      "Unaging", "Catastrophe", "Apocalypse", "Demoness"],
     "Assassinare, maledire e scatenare disastri naturali",
     ["maledizione", "specchio", "disastro", "agilita'"]),

    ("red_priest", "Red Priest", "calamity_of_destruction",
     ["Hunter", "Provoker", "Pyromaniac", "Conspirer", "Reaper", "Iron-Blooded Knight",
      "War Bishop", "Weather Warlock", "Conqueror", "Red Priest"],
     "Provocare, incendiare e orchestrare disastri artificiali",
     ["fuoco", "guerra", "trappola", "provocazione"]),

    ("hermit", "Hermit", "demon_of_knowledge",
     ["Mystery Pryer", "Melee Scholar", "Warlock", "Scrolls Professor", "Constellations Master",
      "Mysticologist", "Clairvoyant", "Sage", "Knowledge Emperor", "Hermit"],
     "Praticare magia rituale, pergamene e costellazioni",
     ["occulto", "rituale", "stella", "divinazione"]),

    ("paragon", "Paragon", "demon_of_knowledge",
     ["Savant", "Archaeologist", "Appraiser", "Artisan", "Astronomer", "Alchemist",
      "Arcane Scholar", "Knowledge Magister", "Illuminator", "Paragon"],
     "Costruire oggetti Beyonder e piegare le leggi fisiche",
     ["scienza", "crafting", "invenzione", "conoscenza"]),

    ("wheel_of_fortune", "Wheel of Fortune", "key_of_light",
     ["Monster", "Robot", "Lucky One", "Calamity Priest", "Winner", "Misfortune Mage",
      "Chaoswalker", "Soothsayer", "Snake of Mercury", "Wheel of Fortune"],
     "Manipolare probabilita' e destino in modo esplicito",
     ["probabilita'", "destino", "fortuna", "disastro"]),

    ("mother", "Mother", "goddess_of_origin",
     ["Planter", "Doctor", "Harvest Priest", "Biologist", "Druid", "Classical Alchemist",
      "Pallbearer", "Desolate Matriarch", "Naturewalker", "Mother"],
     "Far crescere piante, curare e creare chimere",
     ["crescita", "terra", "guarigione", "genetica"]),

    ("moon", "Moon", "goddess_of_origin",
     ["Apothecary", "Beast Tamer", "Vampire", "Potions Professor", "Scarlet Scholar", "Shaman King",
      "High Summoner", "Life-Giver", "Beauty Goddess", "Moon"],
     "Domare bestie, evocare e distillare pozioni potenti",
     ["pozione", "bestia", "evocazione", "sangue"]),

    ("abyss", "Abyss", "father_of_devils",
     ["Criminal", "Unwinged Angel", "Serial Killer", "Devil", "Desire Apostle", "Demon",
      "Blatherer", "Bloody Archduke", "Filthy Monarch", "Abyss"],
     "Corrompere i desideri e schiacciare con forza demoniaca",
     ["desiderio", "corruzione", "forza", "demone"]),

    ("chained", "Chained", "father_of_devils",
     ["Prisoner", "Lunatic", "Werewolf", "Zombie", "Wraith", "Puppet",
      "Disciple of Silence", "Ancient Bane", "Abomination", "Chained"],
     "Mutare forma barattando razionalita' per potenza",
     ["mutazione", "maledizione", "possessione", "luna"]),

    ("black_emperor", "Black Emperor", "the_anarchy",
     ["Lawyer", "Barbarian", "Briber", "Baron of Corruption", "Mentor of Disorder", "Earl of the Fallen",
      "Frenzied Mage", "Duke of Entropy", "Prince of Abolition", "Black Emperor"],
     "Corrompere e distorcere le regole del gioco stesso",
     ["disordine", "corruzione", "cavillo", "dominio"]),

    ("justiciar", "Justiciar", "the_anarchy",
     ["Arbiter", "Sheriff", "Interrogator", "Judge", "Disciplinary Paladin", "Imperative Mage",
      "Chaos Hunter", "Balancer", "Hand of Order", "Justiciar"],
     "Imporre regole vincolanti e negare i poteri altrui",
     ["ordine", "legge", "giudizio", "negazione"]),
]


# Pathway attivi nel progetto. Gli altri 12 restano in data/pathways_deferred/:
# non sono cancellati, sono fuori scope. Criterio di selezione: 4 GRUPPI
# COMPLETI, cosi' che il cambio di Pathway della fase 7 (possibile solo tra
# vicini dello stesso gruppo) resti implementabile.
ACTIVE = {
    "fool", "error", "door",                    # Lord of Mysteries
    "darkness", "death", "twilight_giant",      # Eternal Darkness
    "hermit", "paragon",                        # Demon of Knowledge
    "mother", "moon",                           # Goddess of Origin
}

# Concept di gioco per ognuna delle 100 sequenze attive, in ordine 9 -> 0.
# Non e' lore: e' cosa fa il giocatore a quel livello. E' la specifica da cui
# si scrivono le abilita' in data/abilities/.
CONCEPTS = {
"fool": [
 "Divinazione col pendolo e lettura delle intenzioni nemiche. Nessuna offesa: il Seer osserva.",
 "Destrezza acrobatica, travestimento, illusioni brevi per rompere l'aggro.",
 "Illusioni solide che infliggono danno percepito; oggetti evocati dal nulla per un colpo.",
 "Assume aspetto e voce di un NPC e ne eredita i permessi sociali: apre porte chiuse.",
 "Fili spirituali: controlla un nemico come marionetta e lo usa contro gli altri.",
 "Sostituisce se stesso con un oggetto a distanza; gioco di prestigio su scala di stanza.",
 "Richiama dal passato una versione precedente di se' o di un oggetto distrutto.",
 "Converte spiritualita' in eventi improbabili: il miracolo come risorsa spendibile.",
 "Crea un'area di segretezza in cui la realta' locale puo' essere manomessa.",
 "Falsifica la realta' su scala di mondo.",
],
"error": [
 "Scasso, furto da inventario nemico, colpo alle spalle con bonus se non visto.",
 "Eloquenza e truffa: estrae denaro e informazioni dagli NPC senza combattere.",
 "Decifra formule, sigilli e testi cifrati; ruba conoscenza invece di oggetti.",
 "Ruba temporaneamente un'abilita' Beyonder appena vista e la usa una volta.",
 "Entra nei sogni per rubare ricordi e formule di pozione.",
 "Si attacca a un ospite: ne usa sensi, movimento e risorse restando nascosto.",
 "Crea avatar autonomi che agiscono come lui; inganni a piu' livelli.",
 "Impianta un errore nel destino di un bersaglio: i suoi piani falliscono.",
 "Riavvolge brevi tratti di tempo in un raggio limitato.",
 "Sfrutta i buchi nelle regole del mondo stesso.",
],
"door": [
 "Teletrasporti brevi a vista; apre serrature mistiche e passaggi bloccati.",
 "Incantesimi di fuga e scambio di posizione con un bersaglio.",
 "Divinazione stellare che rivela percorsi nascosti sulla mappa.",
 "Registra un'abilita' osservata e la riproduce una volta.",
 "Viaggio nel mondo spirituale come scorciatoia tra zone lontane.",
 "Occultamento totale: sfugge al rilevamento anche mistico.",
 "Teletrasporto a lunga distanza portando con se' alleati e pet.",
 "Apre porte stabili tra piani; replica abilita' che conosce senza registrarle.",
 "Chiavi che aprono qualunque cosa, compresi luoghi che non hanno una porta.",
 "Passaggio senza limiti.",
],
"darkness": [
 "Veglia perpetua: visione notturna, immunita' al sonno, forza al buio.",
 "Parole che deprimono desideri e umore nemico, riducendo aggressivita'.",
 "Entra negli incubi e infligge paura che disorienta i controlli nemici.",
 "Pacifica anime inquiete e cura il danno spirituale degli alleati.",
 "Ospita spiriti maligni nel corpo e li scaglia come proiettili viventi.",
 "Dominio della notte: statistiche raddoppiate al buio, oscurita' creabile.",
 "Aura di terrore che rompe le formazioni nemiche e controlla il buio.",
 "Cancella cose e persone dalla percezione altrui, anche in pieno giorno.",
 "Infligge sfortuna cronica: i nemici falliscono, inciampano, si feriscono da soli.",
 "La notte come dominio.",
],
"death": [
 "Resiste a freddo e decomposizione; vede dove sono morti di recente.",
 "Rianima cadaveri semplici come alleati temporanei.",
 "Parla con i morti per ottenere informazioni non altrimenti accessibili.",
 "Comanda spiriti e li scaglia; il primo vero potere offensivo del Pathway.",
 "Apre passaggi verso il mondo spirituale, usabili per esplorare e fuggire.",
 "Rigenerazione estrema: non muore facilmente, torna in piedi.",
 "Uccide separando anima e corpo; traghetta anime come risorsa.",
 "Eserciti di non-morti persistenti anche fuori dal combattimento.",
 "Uccisione istantanea sotto soglia e resurrezione degli alleati.",
 "Dominio sulla fine: la morte come autorita' sul mondo.",
],
"twilight_giant": [
 "Maestria delle armi, forza e resistenza. Il combattente puro.",
 "Combattimento a mani nude con contrattacco su parata perfetta.",
 "Padroneggia ogni arma; tecniche avanzate e combo estese.",
 "Crescita fisica e armatura di luce evocabile.",
 "Assorbe il danno diretto agli alleati; stance difensiva quasi inviolabile.",
 "Concoction di potenziamento e caccia agli spiriti maligni.",
 "Arma di luce solida che purifica cio' che colpisce.",
 "Luce del crepuscolo: infligge decadimento a materia e spirito.",
 "Forza divina applicata: rompe strutture e barriere.",
 "Il crepuscolo come autorita'.",
],
"hermit": [
 "Percepisce il misticismo e traccia rituali di base.",
 "Combatte applicando la conoscenza: sigilli incisi sull'arma in tempo reale.",
 "Incantesimi tradizionali ed evocazione minore.",
 "Prepara pergamene monouso: magia precotta da spendere al momento giusto.",
 "Costellazioni: potenziamenti stellari legati alla posizione e all'ora.",
 "Crea incantesimi propri combinando conoscenze acquisite.",
 "Vede e sente le esistenze nascoste, incluse quelle che non vogliono essere viste.",
 "Drena potere direttamente dalla conoscenza mistica accumulata.",
 "Legge e altera il destino tessuto di una persona.",
 "L'occulto come dominio.",
],
"paragon": [
 "Conoscenza scientifica: analizza oggetti e ne rivela le proprieta'.",
 "Scava, identifica reperti e disinnesca trappole antiche.",
 "Valuta e identifica gli Oggetti Sigillati, rivelandone gli effetti collaterali.",
 "Costruisce armi e congegni Beyonder: il Pathway del crafting.",
 "Strumenti ottici e mappe: previsione e ricognizione a distanza.",
 "Trasmutazione dei materiali; alchimia applicata al crafting.",
 "Unisce scienza e misticismo: incisioni che funzionano su entrambi i piani.",
 "Infonde spirito negli oggetti creati: costrutti autonomi e permanenti.",
 "Altera le leggi fisiche locali in un raggio.",
 "La civilta' come dominio.",
],
"mother": [
 "Coltiva e accelera la crescita delle piante; base del ciclo ingredienti.",
 "Cura le ferite e diagnostica veleni e maledizioni.",
 "Benedice i raccolti e rigenera un'area viva intorno a se'.",
 "Modifica le creature: innesti e primi ibridi.",
 "Comanda la vegetazione come arma e come terreno: terraforming tattico.",
 "Alchimia della vita: omuncoli e materiali organici artificiali.",
 "Drena forza vitale dai nemici e dall'ambiente, restituendola alla terra.",
 "Crea esseri viventi da zero: chimere su misura per il giocatore.",
 "La natura risponde ai suoi comandi senza bisogno di rituali.",
 "La terra come dominio.",
],
"moon": [
 "Pozioni di base ed erboristeria: la porta d'ingresso all'alchimia.",
 "Doma le bestie: il primo pet permanente del gioco.",
 "Drena sangue, rigenera e guadagna forza di notte.",
 "Pozioni avanzate con qualita' superiore e effetti combinati.",
 "Sangue come materiale rituale: potenzia i rituali di avanzamento.",
 "Comanda branchi e spiriti bestiali; il pet acquisisce un branco.",
 "Evoca creature da grande distanza, anche mai incontrate.",
 "Dona vita: crea creature durature che coltivano insieme al giocatore.",
 "Fascino assoluto: dominio sui viventi senza combattimento.",
 "La luna come dominio.",
],
}

# Pathway originati dalle Divinita' Esterne (rilevante per la meccanica di corruzione)
OUTER_DEITY_ORIGIN = {"mother", "moon", "abyss", "chained", "black_emperor", "justiciar"}


def tier_for(seq_num: int) -> str:
    if seq_num >= 7:
        return "low"
    if seq_num >= 5:
        return "mid"
    if seq_num >= 3:
        return "saint"
    if seq_num >= 1:
        return "angel"
    return "god"


def build_pathway(pid, name, group, seq_names, verb, tags):
    assert len(seq_names) == 10, f"{pid}: servono esattamente 10 sequenze"
    concepts = CONCEPTS.get(pid, [""] * 10)
    sequences = []
    for offset, seq_name in enumerate(seq_names):
        seq_num = 9 - offset
        sequences.append({
            "sequence": seq_num,
            "id": f"{pid}_{seq_num}",
            "name": seq_name,
            "name_i18n": f"sequence.{pid}.{seq_num}",
            "tier": tier_for(seq_num),
            "concept": concepts[offset],
            "stat_modifiers": {},
            "abilities": [],
            "acting_actions": [],
            "potion": {
                "characteristic_sequence": seq_num,
                "ingredients": [],
                "formula_id": f"formula_{pid}_{seq_num}"
            },
            "advancement_ritual": None if seq_num > 4 else {
                "location_tags": [],
                "moon_phase": None,
                "sacrifices": [],
                "sigils": []
            },
            "madness_on_force": 0,
            "notes": ""
        })
    return {
        "schema_version": 1,
        "id": pid,
        "name": name,
        "name_i18n": f"pathway.{pid}",
        "group": group,
        "god_title": name,
        "from_outer_deity": pid in OUTER_DEITY_ORIGIN,
        "gameplay_verb": verb,
        "tags": tags,
        "sequences": sequences
    }


def merge_preserving(new_doc, old_doc):
    """Riporta nel nuovo documento i campi gia' popolati nel vecchio."""
    old_seqs = {s["id"]: s for s in old_doc.get("sequences", [])}
    for seq in new_doc["sequences"]:
        old = old_seqs.get(seq["id"])
        if not old:
            continue
        for field in ("stat_modifiers", "abilities", "acting_actions", "potion",
                      "advancement_ritual", "madness_on_force", "notes", "concept"):
            if field in old and old[field] not in (None, [], {}, "", 0):
                seq[field] = old[field]
    return new_doc


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(DEFERRED_DIR, exist_ok=True)
    total_sequences = 0
    active_count = 0
    for pid, name, group, seqs, verb, tags in PATHWAYS:
        doc = build_pathway(pid, name, group, seqs, verb, tags)
        active = pid in ACTIVE
        target = OUT_DIR if active else DEFERRED_DIR
        path = os.path.join(target, f"{pid}.json")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                doc = merge_preserving(doc, json.load(fh))
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        if active:
            active_count += 1
            total_sequences += len(doc["sequences"])

    print(f"OK: {active_count} pathway attivi ({total_sequences} sequenze) in data/pathways/")
    print(f"    {len(PATHWAYS) - active_count} pathway differiti in data/pathways_deferred/")
    if active_count != 10 or total_sequences != 100:
        print("ERRORE: attesi 10 pathway attivi e 100 sequenze", file=sys.stderr)
        return 1
    for pid in ACTIVE:
        if len(CONCEPTS.get(pid, [])) != 10:
            print(f"ERRORE: concept mancanti per {pid}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
