"""Costruttore di personaggi umanoidi (proporzioni "chibi", alti ~31 unita' = 31 px a risoluzione 32).

    from forge3d.humanoid import humanoid
    hero = humanoid(skin="skin_light", hair="hair_brown", hair_style="short", outfit="tunic",
                    top="cloth_blue", weapon="sword", cape="cloth_red")

Giunti: root > hips > torso > head, arm_l/arm_r > fore_l/fore_r > weapon(r), leg_l/leg_r > shin_l/shin_r, cape.
"""
from .engine import rotm
from .rig import Rig


def P(shape, size, pos, mat, rot=(0, 0, 0), **kw):
    return (shape, size, pos, rot, mat, kw)


# ------------------------------------------------------------------------------------------------
# armi (disegnate lungo +z a partire dalla mano; il gruppo viene ruotato in avanti)
# ------------------------------------------------------------------------------------------------

def _weapon_parts(kind, detail):
    if kind == "sword":
        return [
            P("cylinder", (0.75, 0.75, 1.6), (0, 0, 0.9), "leather"),
            P("ellipsoid", (1.1, 1.1, 0.95), (0, 0, -0.8), "gold"),
            P("box", (2.7, 0.9, 0.55), (0, 0, 2.7), "gold", soft=0.6),
            P("box", (1.1, 0.42, 5.6), (0, 0, 8.4), "steel", soft=0.5),
            P("cone", (1.1, 0.42, 1.3), (0, 0, 15.3), "steel"),
        ]
    if kind == "greatsword":
        return [
            P("cylinder", (0.85, 0.85, 2.2), (0, 0, 1.0), "leather"),
            P("ellipsoid", (1.2, 1.2, 1.0), (0, 0, -1.4), "gold"),
            P("box", (3.4, 1.0, 0.65), (0, 0, 3.2), "gold", soft=0.6),
            P("box", (1.6, 0.5, 8.0), (0, 0, 11.7), "steel", soft=0.5),
            P("cone", (1.6, 0.5, 1.8), (0, 0, 21.5), "steel"),
        ]
    if kind == "dagger":
        return [
            P("cylinder", (0.6, 0.6, 1.2), (0, 0, 0.6), "leather"),
            P("box", (1.7, 0.6, 0.4), (0, 0, 1.9), "bronze", soft=0.5),
            P("box", (0.8, 0.32, 2.6), (0, 0, 4.6), "steel", soft=0.5),
            P("cone", (0.8, 0.32, 0.9), (0, 0, 8.1), "steel"),
        ]
    if kind == "axe":
        return [
            P("cylinder", (0.8, 0.8, 6.2), (0, 0, 4.0), "wood"),
            P("box", (0.7, 3.0, 2.3), (0, 0.9, 9.4), "steel", soft=0.5),
            P("box", (0.6, 1.1, 1.2), (0, -1.1, 9.4), "iron", soft=0.5),
        ]
    if kind == "mace":
        return [
            P("cylinder", (0.8, 0.8, 4.6), (0, 0, 3.0), "wood"),
            P("ellipsoid", (2.4, 2.4, 2.4), (0, 0, 8.6), "iron", soft=0.5),
            P("cone", (0.8, 0.8, 1.2), (0, 0, 11.4), "steel"),
        ]
    if kind == "spear":
        return [
            P("cylinder", (0.7, 0.7, 11.0), (0, 0, 7.0), "wood"),
            P("box", (1.2, 0.35, 2.0), (0, 0, 18.4), "steel", soft=0.5),
            P("cone", (1.2, 0.35, 1.5), (0, 0, 21.8), "steel"),
        ]
    if kind == "staff":
        return [
            P("cylinder", (0.8, 0.8, 10.0), (0, 0, 6.0), "wood"),
            P("ellipsoid", (1.9, 1.9, 1.9), (0, 0, 16.8), "gem_blue", soft=0.0),
            P("cone", (1.0, 1.0, 1.1), (0, 1.2, 15.2), "gold", rot=(-60, 0, 0)),
            P("cone", (1.0, 1.0, 1.1), (0, -1.2, 15.2), "gold", rot=(60, 0, 0)),
        ]
    if kind == "torch":
        return [
            P("cylinder", (0.75, 0.75, 3.0), (0, 0, 2.0), "wood"),
            P("ellipsoid", (1.5, 1.5, 2.2), (0, 0, 6.2), "fire"),
        ]
    if kind == "book":
        return [
            P("box", (2.4, 0.9, 3.0), (0, 0.4, 2.8), "leather", soft=0.4),
            P("box", (2.1, 0.7, 2.7), (0.1, 0.9, 2.8), "cloth_cream", soft=0.2),
        ]
    if kind == "wand":
        return [
            P("cylinder", (0.5, 0.5, 3.2), (0, 0, 2.2), "wood"),
            P("ellipsoid", (0.9, 0.9, 0.9), (0, 0, 5.6), "gem_blue"),
        ]
    raise KeyError(f"arma sconosciuta '{kind}'")


def humanoid(skin="skin_light", hair="hair_brown", hair_style="short", outfit="tunic", top="cloth_blue",
             bottom="cloth_grey", boots="leather_dark", belt="leather", cape=None, hat=None,
             weapon="sword", shield=None, eyes="eye", ears="round", build=1.0, scale=1.0, head=1.0,
             sleeves=True, gloves=None, scarf=None, detail=1, name="humanoid"):
    r = Rig(name)
    r.scale = scale
    w = build           # larghezza del corpo
    hs = head           # scala della testa

    # ---- scheletro -------------------------------------------------------------------------
    r.joint("hips", "root", (0, 0, 10.8))
    r.joint("torso", "hips", (0, 0, 1.2))
    r.joint("head", "torso", (0, 0, 7.6), rest=(9, 0, 0))
    r.joint("arm_l", "torso", (-5.0 * w, 0, 6.4))
    r.joint("arm_r", "torso", (5.0 * w, 0, 6.4))
    r.joint("fore_l", "arm_l", (0, 0, -4.4))
    r.joint("fore_r", "arm_r", (0, 0, -4.4))
    r.joint("weapon", "fore_r", (0, 0, -4.7))
    r.joint("leg_l", "hips", (-2.5 * w, 0, -0.2))
    r.joint("leg_r", "hips", (2.5 * w, 0, -0.2))
    r.joint("shin_l", "leg_l", (0, 0, -5.0))
    r.joint("shin_r", "leg_r", (0, 0, -5.0))
    r.joint("cape", "torso", (0, -2.7, 6.8))

    robe = outfit == "robe"
    armor = outfit == "armor"
    bare_arms = outfit in ("rags", "peasant") or not sleeves
    arm_mat = skin if bare_arms else top
    leg_mat = bottom if outfit != "armor" else "iron"
    boot_mat = boots if outfit != "armor" else "steel"

    # ---- bacino e busto -----------------------------------------------------------------------
    r.part("hips", "ellipsoid", (4.0 * w, 3.0, 2.4), (0, 0, 0.5), mat=bottom if not robe else top)
    if robe:
        r.part("hips", "cone", (5.6 * w, 4.4, 4.4), (0, 0, -1.6), mat=top)
    r.part("torso", "ellipsoid", (4.4 * w, 3.2, 4.3), (0, 0, 3.4), mat=top)
    if armor:
        r.part("torso", "ellipsoid", (4.8 * w, 3.6, 3.6), (0, 0.5, 3.7), mat="steel")
        r.part("torso", "ellipsoid", (2.3 * w, 0.9, 2.0), (0, 3.7, 4.0), mat="gold", soft=0.4)
        for sx in (-1, 1):
            r.part("torso", "ellipsoid", (2.6, 2.6, 2.0), (sx * 5.2 * w, 0, 6.6), mat="steel")
    if outfit == "leather":
        r.part("torso", "ellipsoid", (4.7 * w, 3.5, 3.0), (0, 0.4, 3.0), mat="leather")
    # cintura
    r.part("torso", "cylinder", (4.5 * w, 3.3, 0.7), (0, 0, 0.5), mat=belt, soft=0.3)
    r.part("torso", "box", (1.0, 0.4, 0.9), (0, 3.2, 0.5), mat="gold", soft=0.5)
    if scarf:
        r.part("torso", "ellipsoid", (3.6, 3.0, 1.2), (0, 0.2, 7.9), mat=scarf)
        r.part("torso", "ellipsoid", (1.0, 0.8, 3.0), (2.2, -2.8, 5.2), mat=scarf)

    # ---- testa --------------------------------------------------------------------------------
    hz = 5.4 * hs
    r.part("head", "ellipsoid", (6.2 * hs, 5.6 * hs, 5.8 * hs), (0, 0.3, hz), mat=skin)
    ez = hz - 0.5 * hs
    for sx in (-1, 1):
        ex = 2.55 * hs
        r.part("head", "ellipsoid", (1.05 * hs, 0.7, 1.6 * hs), (sx * ex, 5.05 * hs, ez), mat=eyes)
        if detail >= 2:
            r.part("head", "box", (1.3, 0.3, 0.28), (sx * ex, 5.2 * hs, ez + 2.3 * hs), mat=hair, soft=0.5)
    r.part("head", "ellipsoid", (0.75, 0.75, 0.7), (0, 5.7 * hs, ez - 1.5 * hs), mat="skin_tan" if skin == "skin_light" else skin)
    if ears == "round":
        for sx in (-1, 1):
            r.part("head", "ellipsoid", (1.0, 1.0, 1.4), (sx * 6.1 * hs, 0.2, hz - 0.3), mat=skin)
    elif ears == "elf":
        for sx in (-1, 1):
            r.part("head", "ellipsoid", (0.7, 1.1, 2.6), (sx * 6.6 * hs, 0.0, hz + 0.6), rot=(0, sx * 25, 0), mat=skin)

    # ---- capelli ------------------------------------------------------------------------------
    if hair_style != "bald" and hat not in ("helmet",):
        if hair_style == "hood":
            r.part("head", "ellipsoid", (6.9 * hs, 6.5 * hs, 6.4 * hs), (0, -0.5, hz + 0.5), mat=cape or top)
            r.part("head", "ellipsoid", (4.6 * hs, 1.2, 4.2 * hs), (0, 5.6 * hs, hz - 0.6), mat="shadow_mat")
            r.part("head", "ellipsoid", (0.95, 0.65, 1.35), (-2.6 * hs, 5.9 * hs, hz - 0.2), mat="eye_yellow")
            r.part("head", "ellipsoid", (0.95, 0.65, 1.35), (2.6 * hs, 5.9 * hs, hz - 0.2), mat="eye_yellow")
        else:
            r.part("head", "ellipsoid", (6.5 * hs, 6.0 * hs, 5.7 * hs), (0, -0.9, hz + 1.5 * hs), mat=hair)
            if hair_style in ("short", "long", "ponytail", "bun", "spiky"):
                # frangia: copre solo la fronte, lascia liberi occhi e guance
                r.part("head", "ellipsoid", (5.2 * hs, 1.9, 1.5 * hs), (0.4, 4.6 * hs, hz + 3.5 * hs), mat=hair,
                       rot=(-15, 0, 8))
                r.part("head", "ellipsoid", (1.5, 1.6, 2.3), (-4.4 * hs, 3.6 * hs, hz + 1.9 * hs), mat=hair)
            for sx in (-1, 1):
                r.part("head", "ellipsoid", (1.4, 3.0, 3.2), (sx * 5.7 * hs, -0.8, hz + 0.5), mat=hair)
            if hair_style == "long":
                r.part("head", "ellipsoid", (5.8 * hs, 2.6, 8.0), (0, -4.6 * hs, hz - 3.2), mat=hair)
                for sx in (-1, 1):
                    r.part("head", "ellipsoid", (1.6, 2.2, 5.0), (sx * 5.6 * hs, -1.6, hz - 2.6), mat=hair)
            elif hair_style == "ponytail":
                r.part("head", "ellipsoid", (1.7, 1.7, 5.5), (0, -6.2 * hs, hz - 0.6), mat=hair, rot=(25, 0, 0))
            elif hair_style == "bun":
                r.part("head", "ellipsoid", (2.8, 2.8, 2.8), (0, -1.2, hz + 6.8 * hs), mat=hair)
            elif hair_style == "spiky":
                for (x, y, z, ry_, rx_) in ((0, 0.6, 6.6, 0, 0), (-3.0, 0.2, 6.0, 25, 0), (3.0, 0.2, 6.0, -25, 0),
                                            (0, -3.2, 5.8, 0, 30), (0, 3.2, 6.0, 0, -28)):
                    r.part("head", "cone", (2.0, 2.0, 2.8), (x * hs, y * hs, hz + z * hs), mat=hair,
                           rot=(rx_, ry_, 0))
    if hat == "wizard":
        r.part("head", "cylinder", (8.4 * hs, 8.0 * hs, 0.7), (0, 0.2, hz + 3.4 * hs), mat=top, soft=0.5)
        r.part("head", "cone", (5.0 * hs, 4.8 * hs, 6.2), (0.0, -0.4, hz + 9.6 * hs), mat=top, rot=(-10, 0, 0))
        r.part("head", "cylinder", (5.4 * hs, 5.2 * hs, 0.7), (0, 0, hz + 4.5 * hs), mat="gold", soft=0.5)
    elif hat == "helmet":
        r.part("head", "ellipsoid", (6.7 * hs, 6.3 * hs, 5.6 * hs), (0, -0.3, hz + 1.7 * hs), mat="steel")
        r.part("head", "box", (0.9, 0.6, 3.3), (0, 5.8 * hs, hz + 0.9), mat="steel", soft=0.5)
        r.part("head", "cone", (1.0, 3.0, 2.2), (0, -0.5, hz + 8.0 * hs), mat="red" if False else "cloth_red",
               rot=(-80, 0, 0))
    elif hat == "crown":
        r.part("head", "cylinder", (5.4 * hs, 5.0 * hs, 1.0), (0, -0.4, hz + 5.4 * hs), mat="gold", soft=0.4)
        for k in range(5):
            import math
            a = math.radians(k * 72)
            r.part("head", "cone", (0.9, 0.9, 1.4), (5.0 * hs * math.sin(a), -0.4 + 4.6 * hs * math.cos(a),
                                                     hz + 7.1 * hs), mat="gold")
    elif hat == "cap":
        r.part("head", "ellipsoid", (6.6 * hs, 6.2 * hs, 3.5 * hs), (0, -0.5, hz + 3.6 * hs), mat=top)
        r.part("head", "ellipsoid", (4.0, 2.8, 0.8), (0, 5.2 * hs, hz + 3.0 * hs), mat=top, soft=0.3)

    # ---- braccia ------------------------------------------------------------------------------
    for sx, side in ((-1, "l"), (1, "r")):
        a, f = f"arm_{side}", f"fore_{side}"
        r.part(a, "ellipsoid", (1.9 * w, 1.9 * w, 2.9), (0, 0, -2.1), mat=arm_mat)
        r.part(f, "ellipsoid", (1.65 * w, 1.65 * w, 2.7), (0, 0, -2.2), mat=arm_mat if sleeves else skin)
        gl = gloves or skin
        r.part(f, "ellipsoid", (1.7, 1.7, 1.7), (0, 0.1, -4.6), mat=gl)
        if armor:
            r.part(f, "ellipsoid", (2.0, 2.0, 2.0), (0, 0, -2.4), mat="steel")
        if detail >= 2:
            r.part(f, "cylinder", (1.9, 1.9, 0.5), (0, 0, -3.6), mat=belt, soft=0.3)

    # ---- gambe --------------------------------------------------------------------------------
    for sx, side in ((-1, "l"), (1, "r")):
        l, s = f"leg_{side}", f"shin_{side}"
        r.part(l, "ellipsoid", (2.35 * w, 2.35 * w, 3.3), (0, 0, -2.5), mat=leg_mat if not robe else bottom)
        r.part(s, "ellipsoid", (2.1 * w, 2.1 * w, 3.0), (0, 0, -2.2), mat=boot_mat if outfit != "rags" else leg_mat)
        r.part(s, "ellipsoid", (2.5 * w, 3.6, 1.7), (0, 1.2, -3.65), mat=boot_mat)
        if armor:
            r.part(s, "ellipsoid", (2.4 * w, 2.4, 2.4), (0, 0.4, -2.0), mat="steel")

    # ---- mantello -----------------------------------------------------------------------------
    if cape:
        r.part("cape", "ellipsoid", (5.6 * w, 1.1, 8.0), (0, -0.2, -6.0), mat=cape, rot=(4, 0, 0))
        r.part("torso", "ellipsoid", (3.4, 2.4, 1.3), (0, -0.8, 7.7), mat=cape)

    # ---- arma e scudo -------------------------------------------------------------------------
    if weapon:
        r.group("weapon", _weapon_parts(weapon, detail), pos=(0, 0.2, -0.3), rot=(-90, 0, 0))
    if shield:
        if shield == "round":
            r.part("fore_l", "cylinder", (4.8, 4.8, 0.8), (-1.0, 1.6, -3.6), mat="wood", rot=(90, 0, 0), soft=0.6)
            r.part("fore_l", "cylinder", (1.3, 1.3, 1.0), (-1.0, 2.0, -3.6), mat="iron", rot=(90, 0, 0), soft=0.5)
            r.part("fore_l", "cylinder", (4.9, 4.9, 0.5), (-1.0, 1.9, -3.6), mat="steel", rot=(90, 0, 0), soft=0.0)
        else:
            r.part("fore_l", "box", (3.6, 0.9, 5.0), (-1.0, 1.6, -3.4), mat="cloth_red", soft=0.6)
            r.part("fore_l", "box", (3.8, 0.55, 5.2), (-1.0, 1.9, -3.4), mat="steel", soft=0.3)
    return r


# ------------------------------------------------------------------------------------------------
# pose di riferimento
# ------------------------------------------------------------------------------------------------

REST = {
    "arm_l": (4, 6, 0), "arm_r": (4, -6, 0),
    "fore_l": (10, 0, 0), "fore_r": (22, 0, 0),
    "weapon": (0, 0, 0),
}
