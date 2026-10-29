"""Tema dei colori (decisione 2026-10-20: due modalita'). "luminoso" = i colori di sempre (modalita' facile, l'arte
di oggi, che non cambia di un byte). "cupo" = modalita' difficile, come le concept (assets/concept/regioni/): ogni
colore di terreni, pareti e materiali passa per CUPO, la sua versione meno satura, piu' scura e con le ombre fredde.

CUPO e' una palette chiusa: un gemello cupo per ogni colore usato (Endesga 32 se ce n'e' uno quasi uguale, altrimenti
un extra cupo dichiarato solo qui). Bozza calcolata (saturazione x0,55, luce x0,62, ombre verso il blu) e poi
guardata; le correzioni a mano si scrivono qui, una riga per colore. (Raggruppare i gemelli in pochi colori mescolava
le tinte: le luci verdi delle chiome diventavano grigie.) Nessun riempimento va sul colore del contorno #181425. I materiali emissive (occhi, rune, fuoco) non passano di
qui: nel buio sono loro a brillare. Un terreno puo' avere una sua "ramp_cupo" (umore della regione) che vince.

    python tools/art/build_world.py --tema cupo     # -> arte/mondo/cupo/
"""
TEMA = "luminoso"

CUPO = {
    "#feae34": "#8a6f45",   # amber -> cupo
    "#0099db": "#1f546b",   # blue -> cupo
    "#124e89": "#182d42",   # blue_d -> cupo
    "#b86f50": "#624a40",   # brown -> cupo
    "#733e39": "#3e2731",   # brown_d -> brown_dd
    "#3e2731": "#211a1f",   # brown_dd -> cupo
    "#ead4aa": "#8b8476",   # cream -> cupo
    "#2ce8f5": "#408085",   # cyan -> cupo
    "#63c74d": "#4d6f46",   # green -> cupo
    "#265c42": "#20332c",   # green_d -> cupo
    "#3e8948": "#324c37",   # green_m -> cupo
    "#8b9bb4": "#5a5f69",   # grey -> cupo
    "#c0cbdc": "#797d84",   # grey_l -> cupo
    "#181425": "#0e0d14",   # ink -> cupo
    "#262b44": "#231d30",   # navy -> cupo
    "#f77622": "#7d5135",   # orange -> cupo
    "#d77643": "#704f3f",   # orange_d -> cupo
    "#f6757a": "#7f5356",   # pink -> cupo
    "#ff0044": "#6e1730",   # pink_h -> cupo
    "#b55088": "#5e3b50",   # purple -> cupo
    "#68386c": "#38283b",   # purple_d -> cupo
    "#e43b44": "#6c3337",   # red -> cupo
    "#a22633": "#4c2228",   # red_d -> cupo
    "#be4a2f": "#5e362e",   # rust -> cupo
    "#e8b796": "#85746a",   # skin_l -> cupo
    "#c28569": "#6b564e",   # skin_m -> cupo
    "#5a6988": "#3b404c",   # slate -> cupo
    "#3a4466": "#262a37",   # slate_d -> cupo
    "#e4a672": "#7f6a59",   # tan -> cupo
    "#193c3e": "#152224",   # teal_d -> cupo
    "#ffffff": "#9e9e9e",   # white -> cupo
    "#fee761": "#958d5f",   # yellow -> cupo
    "#1fb5d6": "#316471",   # extra -> cupo
    "#5e4b4a": "#363031",   # extra -> cupo
    "#76839c": "#4c515a",   # extra -> cupo
    "#8a7a38": "#504b35",   # extra -> cupo
    "#8a7b72": "#524d4b",   # extra -> cupo
    "#978a80": "#5a5654",   # extra -> cupo
    "#9a7fb0": "#5b5264",   # extra -> cupo
    "#a4988e": "#635f5c",   # extra -> cupo
    "#a9b3c6": "#6b6f76",   # extra -> cupo
    "#b3a050": "#686248",   # extra -> cupo
    "#b8b0c8": "#716e77",   # extra -> cupo
    "#b9a3cc": "#6f6877",   # extra -> cupo
    "#c9946a": "#705f51",   # extra -> cupo
    "#c99a9a": "#736364",   # extra -> cupo
    "#cdb8dc": "#7c7582",   # extra -> cupo
    "#cdbb64": "#787355",   # extra -> cupo
    "#cfc8db": "#7f7d84",   # extra -> cupo
    "#dcb68a": "#7f7264",   # extra -> cupo
    "#ddb3b0": "#807272",   # extra -> cupo
    "#e0dbe8": "#8a898d",   # extra -> cupo
    "#e2d4ec": "#8a858e",   # extra -> cupo
    "#e8c6c1": "#897d7c",   # extra -> cupo
    "#f0edf4": "#949396",   # extra -> cupo
    "#f3dcd6": "#928a88",   # extra -> cupo
    "#f3e7cf": "#938f87",   # extra -> cupo
}


def imposta(nome):
    """'luminoso' o 'cupo'. Va chiamata prima di generare (le cache tengono conto del tema)."""
    global TEMA
    assert nome in ("luminoso", "cupo"), nome
    TEMA = nome


def colore(h):
    """#hex nel tema corrente."""
    return CUPO.get(h.lower(), h) if TEMA == "cupo" else h
