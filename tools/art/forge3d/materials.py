"""Materiali: ogni materiale e' una ramp di colori (dal piu' scuro al piu' chiaro).

I colori di default vengono dalla palette Endesga 32 (la stessa della skill), quindi tutti gli
sprite generati restano coerenti tra loro. Si possono definire materiali nuovi con
`define("nome", ["#hex", ...], ...)` oppure passare direttamente una lista di colori.

Parametri di un materiale:
    ramp      lista di #hex dal piu' scuro al piu' chiaro (3-6 colori)
    bias      sposta la luminosita' (-0.3 = piu' scuro, +0.2 = piu' chiaro)
    contrast  quanto la luce direzionale pesa (1 = normale, 0.5 = piatto)
    spec      0..1: forza del riflesso lucido (metallo, occhi, gocce)
    shin      durezza del riflesso (piu' alto = punto piu' piccolo)
    tex       ("noise", scala, quantita') | ("stripes", asse, periodo, quantita') | None
    keep      True = i pixel isolati di questo materiale non vengono ripuliti (occhi, riflessi)
    emissive  True = non riceve ombre, usa i toni alti (fuoco, magia, occhi che brillano)
"""
from dataclasses import dataclass

from . import tema

# --- Endesga 32 -------------------------------------------------------------------------------
E32 = {
    "rust": "#be4a2f", "orange_d": "#d77643", "cream": "#ead4aa", "tan": "#e4a672",
    "brown": "#b86f50", "brown_d": "#733e39", "brown_dd": "#3e2731", "red_d": "#a22633",
    "red": "#e43b44", "orange": "#f77622", "amber": "#feae34", "yellow": "#fee761",
    "green": "#63c74d", "green_m": "#3e8948", "green_d": "#265c42", "teal_d": "#193c3e",
    "blue_d": "#124e89", "blue": "#0099db", "cyan": "#2ce8f5", "white": "#ffffff",
    "grey_l": "#c0cbdc", "grey": "#8b9bb4", "slate": "#5a6988", "slate_d": "#3a4466",
    "navy": "#262b44", "ink": "#181425", "pink_h": "#ff0044", "purple_d": "#68386c",
    "purple": "#b55088", "pink": "#f6757a", "skin_l": "#e8b796", "skin_m": "#c28569",
}


def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


@dataclass
class Material:
    name: str
    ramp: list
    bias: float = 0.0
    contrast: float = 1.0
    spec: float = 0.0
    shin: float = 24.0
    tex: tuple = None
    keep: bool = False
    emissive: bool = False
    ramp_cupo: list = None

    @property
    def rgb(self):
        """Colori nel tema corrente (forge3d/tema.py). Gli emissive restano accesi anche nel tema cupo; nel cupo una
        ramp_cupo del materiale (scelta sulla concept) vince sulla tabella."""
        if tema.TEMA == "cupo" and self.ramp_cupo:
            return [hex_to_rgb(c) for c in self.ramp_cupo]
        return [hex_to_rgb(c if self.emissive else tema.colore(c)) if isinstance(c, str) else tuple(c)
                for c in self.ramp]


MATS = {}


def define(name, ramp, **kw):
    """Crea (o sostituisce) un materiale. ramp: nomi della palette E32 oppure #hex."""
    cols = [E32.get(c, c) for c in ramp]
    if kw.get("ramp_cupo"):
        kw["ramp_cupo"] = [E32.get(c, c) for c in kw["ramp_cupo"]]
    MATS[name] = Material(name, cols, **kw)
    return MATS[name]


def get(m):
    """Accetta un nome, un Material o una lista di colori."""
    if isinstance(m, Material):
        return m
    if isinstance(m, (list, tuple)):
        key = "ramp:" + ",".join(E32.get(c, c) for c in m)
        if key not in MATS:
            define(key, list(m))
        return MATS[key]
    if m not in MATS:
        raise KeyError(f"materiale sconosciuto '{m}'. Disponibili: {', '.join(sorted(MATS))}")
    return MATS[m]


# --- pelle --------------------------------------------------------------------------------------
define("skin_light", ["brown_d", "brown", "skin_m", "tan", "skin_l"])
define("skin_tan", ["brown_dd", "brown_d", "brown", "skin_m", "tan"])
define("skin_dark", ["ink", "brown_dd", "brown_d", "brown", "skin_m"])
define("skin_pale", ["slate", "grey", "grey_l", "skin_l", "white"])
define("skin_green", ["teal_d", "green_d", "green_m", "green", "yellow"])
define("skin_grey", ["navy", "slate_d", "slate", "grey", "grey_l"])
# --- capelli / pelo ------------------------------------------------------------------------------
define("hair_brown", ["ink", "brown_dd", "brown_d", "brown"])
define("hair_black", ["ink", "navy", "slate_d", "slate"])
define("hair_blond", ["brown", "tan", "amber", "yellow"])
define("hair_red", ["brown_dd", "red_d", "rust", "orange"])
define("hair_white", ["slate", "grey", "grey_l", "white"])
define("hair_purple", ["navy", "purple_d", "purple", "pink"])
define("hair_blue", ["navy", "blue_d", "blue", "cyan"])
define("fur_grey", ["navy", "slate_d", "slate", "grey"], tex=("noise", 1.6, 0.18))
define("fur_brown", ["brown_dd", "brown_d", "brown", "orange_d"], tex=("noise", 1.6, 0.18))
define("fur_white", ["slate", "grey", "grey_l", "white"], tex=("noise", 1.6, 0.12))
define("fur_black", ["ink", "navy", "slate_d", "slate"], tex=("noise", 1.6, 0.15))
define("fur_orange", ["brown_d", "rust", "orange_d", "orange", "amber"], tex=("noise", 1.6, 0.15))
# --- tessuti -------------------------------------------------------------------------------------
define("cloth_blue", ["navy", "slate_d", "blue_d", "blue"])
define("cloth_red", ["brown_dd", "red_d", "red", "pink"])
define("cloth_green", ["teal_d", "green_d", "green_m", "green"])
define("cloth_purple", ["brown_dd", "purple_d", "purple", "pink"])
define("cloth_white", ["slate", "grey", "grey_l", "white"])
define("cloth_black", ["ink", "navy", "slate_d", "slate"])
define("cloth_cream", ["brown", "tan", "cream", "white"])
define("cloth_orange", ["brown_d", "rust", "orange", "amber"])
define("cloth_yellow", ["brown", "orange", "amber", "yellow"])
define("cloth_teal", ["navy", "teal_d", "blue_d", "blue"])
define("cloth_grey", ["navy", "slate_d", "slate", "grey"])
# --- materiali duri ------------------------------------------------------------------------------
define("leather", ["brown_dd", "brown_d", "brown", "orange_d"])
define("leather_dark", ["ink", "brown_dd", "brown_d", "brown"])
define("wood", ["brown_dd", "brown_d", "brown", "orange_d"], tex=("stripes", "z", 1.4, 0.12))
define("wood_light", ["brown_d", "brown", "tan", "cream"], tex=("stripes", "z", 1.4, 0.1))
define("bark", ["ink", "brown_dd", "brown_d", "brown"], tex=("noise", 1.2, 0.22),
       ramp_cupo=["#232a24", "#4d5a48", "#798972", "#97a790"])   # cupo: tronchi muschiosi chiari (concept valle)
define("steel", ["slate_d", "slate", "grey", "grey_l", "white"], spec=0.9, shin=30, contrast=1.1)
define("iron", ["ink", "navy", "slate_d", "slate", "grey"], spec=0.6, shin=26)
define("gold", ["brown_d", "orange", "amber", "yellow", "cream"], spec=0.9, shin=30)
define("bronze", ["brown_dd", "brown_d", "orange_d", "amber", "yellow"], spec=0.6, shin=26)
define("stone", ["navy", "slate_d", "slate", "grey"], tex=("noise", 1.1, 0.16))
define("stone_light", ["slate_d", "slate", "grey", "grey_l"], tex=("noise", 1.1, 0.16))
# Trono del Gigante: come "stone" nel luminoso; nel cupo roccia nera con le luci arancio del tramonto (concept trono)
define("roccia_trono", ["navy", "slate_d", "slate", "grey"], tex=("noise", 1.1, 0.16),
       ramp_cupo=["#1f1a1e", "#291f1c", "#3a2b26", "#9e5438"])
define("brick", ["brown_dd", "brown_d", "rust", "orange_d"], tex=("noise", 0.9, 0.12))
define("bone", ["slate", "grey", "grey_l", "cream", "white"])
define("sand", ["brown", "tan", "cream", "skin_l"], tex=("noise", 1.5, 0.1))
# --- natura --------------------------------------------------------------------------------------
define("leaf_dark", ["ink", "teal_d", "green_d", "green_m"], tex=("noise", 1.3, 0.2))
define("leaf", ["teal_d", "green_d", "green_m", "green"], tex=("noise", 1.3, 0.2))
define("leaf_light", ["green_d", "green_m", "green", "yellow"], tex=("noise", 1.3, 0.2))
define("leaf_autumn", ["brown_dd", "rust", "orange", "amber"], tex=("noise", 1.3, 0.2))
define("leaf_pink", ["purple_d", "purple", "pink", "skin_l"], tex=("noise", 1.3, 0.2))
define("leaf_dead", ["ink", "brown_dd", "brown_d", "brown"], tex=("noise", 1.3, 0.2))
# --- personaggi di Mirwada (revisione arte 1.1, 1.10, 1.13): tinte che si staccano dal selciato blu-ardesia ---
define("coat_enel", ["ink", "ink", "brown_dd", "purple_d"], tex=("noise", 1.2, 0.1))   # quasi nero, riflesso prugna
define("trou_enel", ["ink", "ink", "navy", "slate_d"])
define("skin_enel", ["brown_d", "skin_m", "skin_l", "skin_l"])                          # pelle esausta, chiara
define("cloth_bandito", ["teal_d", "green_d", "green_m", "green"])                      # il nemico: giubba verde
define("fur_cinereo", ["ink", "brown_dd", "slate_d", "grey"], tex=("noise", 1.6, 0.2))  # lupo: dorso cenere scuro
define("fur_lunare", ["slate", "grey", "grey_l", "cream"], tex=("noise", 1.6, 0.14))  # capra: manto argento-crema
define("corno", ["ink", "brown_dd", "slate_d", "slate"], spec=0.4, shin=20)  # corna scure sul manto chiaro
define("piume_corvo", ["ink", "ink", "navy", "slate_d"], tex=("noise", 1.4, 0.1))  # corvo: nero, luci grigio-blu
define("leaf_olive", ["teal_d", "green_d", "green_d", "green_m"], tex=("noise", 1.3, 0.28))   # ulivo: verde spento
define("grass", ["teal_d", "green_d", "green_m", "green"])
define("mushroom_red", ["brown_dd", "red_d", "red", "pink"])
define("snow", ["slate", "grey", "grey_l", "white"])
define("ice", ["blue_d", "blue", "cyan", "white"], spec=0.6, shin=20)
define("water", ["blue_d", "blue", "cyan", "white"], spec=0.5, shin=18)
# --- creature ------------------------------------------------------------------------------------
define("slime_green", ["teal_d", "green_d", "green_m", "green", "yellow"], spec=0.7, shin=18)
define("slime_blue", ["navy", "blue_d", "blue", "cyan", "white"], spec=0.7, shin=18)
define("slime_red", ["brown_dd", "red_d", "red", "pink", "skin_l"], spec=0.7, shin=18)
define("slime_purple", ["navy", "purple_d", "purple", "pink", "skin_l"], spec=0.7, shin=18)
define("scale_green", ["teal_d", "green_d", "green_m", "green"], tex=("noise", 2.2, 0.2), spec=0.3)
define("scale_red", ["brown_dd", "red_d", "red", "orange"], tex=("noise", 2.2, 0.2), spec=0.3)
define("white", ["grey_l", "white", "white"], keep=True)
define("shadow_mat", ["ink", "navy", "slate_d", "purple_d"])
define("ghost", ["slate", "grey", "grey_l", "white"], contrast=0.6, bias=0.15)
# --- luminosi ------------------------------------------------------------------------------------
define("eye", ["ink", "ink", "white"], spec=1.0, shin=60, keep=True, bias=-0.2)
define("eye_white", ["grey", "grey_l", "white"], keep=True)
define("eye_red", ["red_d", "red", "pink"], emissive=True, keep=True)
define("eye_cyan", ["blue", "cyan", "white"], emissive=True, keep=True)
define("eye_yellow", ["orange", "amber", "yellow"], emissive=True, keep=True)
define("glow_cyan", ["blue_d", "blue", "cyan", "white"], emissive=True)
define("glow_purple", ["purple_d", "purple", "pink", "white"], emissive=True)
define("glow_yellow", ["orange", "amber", "yellow", "white"], emissive=True)
define("fire", ["red_d", "red", "orange", "amber", "yellow"], emissive=True)
define("gem_red", ["brown_dd", "red_d", "red", "pink", "white"], spec=0.9, shin=40)
define("gem_blue", ["navy", "blue_d", "blue", "cyan", "white"], spec=0.9, shin=40)
define("gem_green", ["teal_d", "green_d", "green", "yellow", "white"], spec=0.9, shin=40)
