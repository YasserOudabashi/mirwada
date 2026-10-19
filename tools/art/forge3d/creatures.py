"""Creature e oggetti naturali con lo stesso motore: slime, quadrupedi (lupo, cervo, cane...), alberi, rocce, cespugli."""
import math
import random

from .rig import Rig, add_pose, clip_from_keys


def slime(mat="slime_green", scale=1.0, eyes="eye", crown=False, name="slime"):
    r = Rig(name); r.scale = scale
    r.joint("body", "root", (0, 0, 0))
    r.part("body", "ellipsoid", (6.4, 6.0, 5.2), (0, 0, 4.4), mat=mat, soft=0.0)
    r.part("body", "ellipsoid", (2.0, 1.2, 1.4), (-2.6, 3.6, 7.6), mat="white", soft=0, name="gloss")
    for sx in (-1, 1):
        r.part("body", "ellipsoid", (1.2, 0.8, 1.7), (sx * 2.2, 5.0, 5.4), mat=eyes)
    if crown:
        r.part("body", "cone", (3.0, 3.0, 2.0), (0, 0, 10.4), mat="gold")
    return r


def slime_clips():
    def idle(n=4):
        return [{"body": (0, 0, 0, 0, 0, 0.0)} for _ in range(n)]
    return idle


def slime_pose(sq):
    """sq>0 schiaccia (largo e basso), sq<0 allunga. Realizzato come scala via part size: usa rig.scale_xyz."""
    return {"_squash": sq}


def quadruped(body_mat="fur_grey", belly="fur_white", head_mat=None, size=1.0, snout=2.6, ears="point",
              tail="bushy", eyes="eye_yellow", legs_mat=None, horns=None, bulk=1.0, name="quadruped", head=1.0):
    r = Rig(name); r.scale = size
    hm = head_mat or body_mat
    lm = legs_mat or body_mat
    r.joint("hips", "root", (0, 0, 6.2))
    r.joint("head", "hips", (0, 5.6, 2.8))
    r.joint("tail", "hips", (0, -5.8, 1.5), rest=(60, 0, 0))
    legs = {}
    for nm, (x, y) in {"fl": (-2.0 * bulk, 3.8), "fr": (2.0 * bulk, 3.8), "bl": (-2.0 * bulk, -3.8), "br": (2.0 * bulk, -3.8)}.items():
        r.joint("leg_" + nm, "hips", (x, y, -0.8))
        r.joint("shin_" + nm, "leg_" + nm, (0, 0, -2.6))
        r.part("leg_" + nm, "ellipsoid", (1.2, 1.4, 2.1), (0, 0, -1.4), mat=lm)
        r.part("shin_" + nm, "ellipsoid", (1.0, 1.1, 2.0), (0, 0.1, -1.6), mat=lm)
        r.part("shin_" + nm, "ellipsoid", (1.3, 1.6, 0.9), (0, 0.6, -3.3), mat=lm, soft=0.2)
    r.part("hips", "ellipsoid", (3.4 * bulk, 6.6, 3.2), (0, 0, 0.6), mat=body_mat)
    r.part("hips", "ellipsoid", (2.4 * bulk, 5.4, 1.8), (0, 0.3, -1.4), mat=belly)
    r.part("hips", "ellipsoid", (3.3 * bulk, 3.0, 3.2), (0, 3.4, 1.0), mat=body_mat)     # spalle
    r.part("head", "ellipsoid", (2.9 * bulk * head, 2.9 * head, 2.7 * head), (0, 0, 0), mat=hm)   # head: grandezza
    r.part("head", "ellipsoid", (1.7 * bulk, snout, 1.5), (0, 2.8, -0.7), mat=hm)
    r.part("head", "ellipsoid", (0.7, 0.5, 0.5), (0, 2.8 + snout * 0.85, -0.5), mat="ink", keep=True) if False else None
    for sx in (-1, 1):
        r.part("head", "ellipsoid", (0.7, 0.5, 0.8), (sx * 1.6 * bulk, 2.2, 0.8), mat=eyes)
        if ears == "point":
            r.part("head", "cone", (1.0, 0.7, 1.6), (sx * 1.8, -0.4, 3.2), mat=hm, rot=(0, sx * 12, 0))
        elif ears == "round":
            r.part("head", "ellipsoid", (1.2, 0.8, 1.2), (sx * 2.0, -0.6, 2.6), mat=hm)
        elif ears == "long":
            r.part("head", "ellipsoid", (0.8, 0.6, 2.4), (sx * 1.4, -0.8, 3.6), mat=hm, rot=(0, sx * 10, 0))
    if horns == "antlers":
        for sx in (-1, 1):
            r.part("head", "cylinder", (0.4, 0.4, 2.8), (sx * 1.4, -0.4, 5.0), mat="bone", rot=(-10, sx * 25, 0))
            r.part("head", "cylinder", (0.35, 0.35, 1.5), (sx * 2.6, -0.4, 6.2), mat="bone", rot=(-10, sx * 60, 0))
    elif horns == "horns":
        for sx in (-1, 1):
            r.part("head", "cone", (0.7, 0.7, 2.2), (sx * 1.8, -0.2, 3.4), mat="bone", rot=(-25, sx * 30, 0))
    if tail == "bushy":
        r.part("tail", "ellipsoid", (1.4, 1.4, 3.8), (0, 0, -3.0), mat=body_mat)
    elif tail == "thin":
        r.part("tail", "cylinder", (0.5, 0.5, 3.0), (0, 0, -3.0), mat=body_mat)
    elif tail == "stub":
        r.part("tail", "ellipsoid", (1.0, 1.0, 1.0), (0, 0, -1.0), mat=belly)
    return r


QUAD_REST = {}


def quad_walk(n=6, stride=28):
    out = []
    for i in range(n):
        p = 2 * math.pi * i / n
        s, c = math.sin(p), math.cos(p)
        out.append({
            "hips": (0, 0, 2 * s, 0, 0, -0.5 * abs(s)),
            "leg_fl": (stride * s, 0, 0), "leg_br": (stride * s, 0, 0),
            "leg_fr": (-stride * s, 0, 0), "leg_bl": (-stride * s, 0, 0),
            "shin_fl": (-30 * max(0, c), 0, 0), "shin_br": (-30 * max(0, c), 0, 0),
            "shin_fr": (30 * min(0, c), 0, 0), "shin_bl": (30 * min(0, c), 0, 0),
            "head": (3 * s, 0, 3 * s), "tail": (10 * s, 0, 8 * s)})
    return out


def quad_idle(n=4):
    return [{"hips": (0, 0, 0, 0, 0, -0.25 * (1 - math.sin(2 * math.pi * i / n)) / 2),
             "head": (2 * math.sin(2 * math.pi * i / n), 0, 0), "tail": (8 * math.sin(2 * math.pi * i / n + 1), 0, 6 * math.sin(2 * math.pi * i / n))}
            for i in range(n)]


def quad_attack(n=4):
    crouch = {"hips": (6, 0, 0, 0, -1.0, -1.2), "head": (-12, 0, 0), "leg_fl": (-12, 0, 0), "leg_fr": (-12, 0, 0)}
    lunge = {"hips": (-10, 0, 0, 0, 0.8, 0.4), "head": (8, 0, 0), "leg_fl": (24, 0, 0), "leg_fr": (24, 0, 0),
             "leg_bl": (-30, 0, 0), "leg_br": (-30, 0, 0), "tail": (20, 0, 0)}
    return clip_from_keys([(0, crouch, "out"), (1, lunge, "snap"), (2, lunge), (n - 1, {})], n)


def quad_death(n=6):
    keys = [(0, {}), (2, {"hips": (0, 25, 0, 0, 0, -3.0), "head": (10, 0, 0)}, "in"),
            (n - 1, {"hips": (0, 88, 0, 2.5, 0, -4.2), "head": (10, 0, 0), "leg_fl": (20, 0, 0), "leg_bl": (-20, 0, 0),
                     "leg_fr": (30, 0, 0), "leg_br": (-10, 0, 0)}, "out")]
    return clip_from_keys(keys, n)


QUAD_CLIPS = {"idle": quad_idle, "walk": quad_walk, "attack": quad_attack, "death": quad_death,
              "anticipo": lambda n=4: clip_from_keys([(0, {}), (n - 1, {"hips": (8, 0, 0, 0, -1.0, -1.5), "head": (-14, 0, 0)})], n),
              "stagger": lambda n=4: clip_from_keys([(0, {"hips": (-8, 0, 0, 0, -1.2, 0)}), (n - 1, {})], n)}


# --- alberi, rocce, cespugli (statici; il vento si fa nel viewer/export con sway) ---------------------
# --- uccello (volatili: vola sopra l'origine, l'ombra a terra la mette il gioco) --------------------------------
VOLO = 9.0      # quota del corpo in volo (unita'): i piedi a terra sono l'origine del rig


def bird(body_mat="fur_black", beak="iron", eyes="eye_yellow", legs="iron", size=1.0, name="uccello"):
    """Corpo, testa col becco, ali in due segmenti (spalla e punta), coda a ventaglio, zampette. Guarda +y."""
    r = Rig(name); r.scale = size
    r.joint("body", "root", (0, 0, VOLO))
    r.joint("head", "body", (0, 2.6, 1.3))
    r.joint("tail", "body", (0, -2.6, 0.2))
    r.part("body", "ellipsoid", (1.7, 3.0, 1.7), (0, 0, 0), mat=body_mat)
    r.part("body", "ellipsoid", (1.4, 1.8, 1.4), (0, 1.4, 0.4), mat=body_mat)               # petto
    r.part("head", "ellipsoid", (1.35, 1.45, 1.3), (0, 0.3, 0.3), mat=body_mat)
    r.part("head", "cone", (0.6, 0.5, 1.3), (0, 2.4, -0.1), mat=beak, rot=(-97, 0, 0))      # becco in avanti
    for sx in (-1, 1):
        r.part("head", "ellipsoid", (0.45, 0.45, 0.5), (sx * 0.95, 0.9, 0.55), mat=eyes)
        w = r.joint("wing_" + ("l" if sx < 0 else "r"), "body", (sx * 1.4, 0.6, 0.9))
        t = r.joint("tip_" + ("l" if sx < 0 else "r"), w, (sx * 3.4, -0.4, 0))
        r.part(w, "ellipsoid", (1.9, 1.3, 0.3), (sx * 1.7, -0.3, 0), mat=body_mat)
        r.part(t, "ellipsoid", (2.1, 0.85, 0.22), (sx * 1.8, -0.7, 0), mat=body_mat, rot=(0, 0, sx * -18))   # punta stretta
        leg = r.joint("leg_" + ("l" if sx < 0 else "r"), "body", (sx * 0.6, -0.2, -1.3), rest=(-50, 0, 0))
        r.part(leg, "cylinder", (0.22, 0.22, 0.8), (0, 0, -0.8), mat=legs)
    r.part("tail", "ellipsoid", (1.2, 1.9, 0.3), (0, -1.6, 0), mat=body_mat)
    return r


def _ali(a, b=0.0):
    """Ali alzate di a gradi (negativo = abbassate); b piega la punta (positivo = punta piu' su)."""
    return {"wing_l": (0, a, 0), "wing_r": (0, -a, 0), "tip_l": (0, b, 0), "tip_r": (0, -b, 0)}


def bird_idle(n=4):
    """Sospeso a mezz'aria: battito corto, il corpo sale quando le ali scendono."""
    out = []
    for i in range(n):
        s = math.sin(2 * math.pi * i / n)
        p = _ali(10 + 35 * s, 10 * s)
        p["body"] = (0, 0, 0, 0, 0, -0.5 * s)
        p["tail"] = (6 * s, 0, 0)
        out.append(p)
    return out


def bird_walk(n=6):
    """Volo: battito pieno, corpo un po' inclinato in avanti."""
    out = []
    for i in range(n):
        s = math.sin(2 * math.pi * (i + 0.5) / n)     # mezzo frame di sfasamento: nessuna posa ripetuta
        p = _ali(5 + 55 * s, 25 * s)
        p["body"] = (-10, 0, 0, 0, 0, -0.8 * s)
        p["head"] = (8, 0, 0)
        p["tail"] = (8 * s, 0, 0)
        out.append(p)
    return out


def bird_attack(n=4):
    """Picchiata col becco: ali in alto (carica), giu' in avanti a ali chiuse, colpo, risalita."""
    carica = dict(_ali(60, 20), body=(15, 0, 0, 0, -0.8, 0.8), head=(10, 0, 0))
    picchiata = dict(_ali(-30, -20), body=(-40, 0, 0, 0, 2.2, -3.0), head=(-15, 0, 0), tail=(15, 0, 0))
    return clip_from_keys([(0, carica, "out"), (1, picchiata, "snap"),
                           (2, add_pose(picchiata, _ali(15, 10))), (n - 1, _ali(30, 10))], n)


def bird_hurt(n=3):
    """Colpito: perde quota all'indietro, ali scomposte."""
    colpo = dict(_ali(70, -30), body=(25, 0, 12, 0, -1.2, -1.2), head=(20, 0, -10), tail=(-20, 0, 0))
    colpo["wing_r"] = (0, -30, 0)
    return clip_from_keys([(0, colpo, "out"), (1, add_pose(colpo, {"body": (-8, 0, -4, 0, 0.3, 0.4)})), (n - 1, _ali(20))], n)


def bird_death(n=6):
    """Non direzionale: precipita e resta a terra a pancia in giu', ali aperte stese sul terreno, testa piegata
    (sul fianco un'ala restava in verticale e sembrava in piedi)."""
    a_terra = -VOLO + 1.2
    keys = [(0, dict(_ali(60, 10), body=(20, 0, 0), head=(25, 0, 0))),
            (2, dict(_ali(85, -25), body=(-25, 15, 20, 0, 0, a_terra * 0.6), head=(30, 0, 15)), "in"),
            (4, dict(_ali(-12, 0), body=(-8, 6, 25, 0, 0, a_terra), head=(-20, 0, 35)), "in"),
            (n - 1, dict(_ali(-16, -6), body=(-6, 4, 25, 0, 0, a_terra - 0.1), head=(-28, 0, 40), tail=(-8, 0, 0)), "out")]
    return clip_from_keys(keys, n)


BIRD_CLIPS = {"idle": bird_idle, "walk": bird_walk, "attack": bird_attack, "hurt": bird_hurt, "death": bird_death}


def tree(kind="oak", seed=1, leaf="leaf", trunk="bark", size=1.0, name=None):
    rnd = random.Random(seed)
    r = Rig(name or f"tree_{kind}_{seed}"); r.scale = size
    r.joint("trunk", "root", (0, 0, 0))
    r.joint("crown", "trunk", (0, 0, 0))     # per l'ondeggiare nel vento
    if kind == "oak":
        r.part("trunk", "cylinder", (2.3, 2.3, 6.0), (0, 0, 6.0), mat=trunk)
        r.part("trunk", "cone", (3.6, 3.6, 1.6), (0, 0, 1.4), mat=trunk)
        for sx, sy, sz, rad in [(0, 0, 17, 8.5), (-5.5, 1.5, 14, 6), (5.5, -1, 14.5, 6.5), (1, 5, 13.5, 5.5),
                                (-1, -5, 15.5, 6)]:
            r.part("crown", "ellipsoid", (rad, rad, rad * 0.92), (sx + rnd.uniform(-.6, .6), sy, sz), mat=leaf)
    elif kind == "pine":
        r.part("trunk", "cylinder", (1.5, 1.5, 4.0), (0, 0, 4.0), mat=trunk)
        for i, (z, rad, h) in enumerate([(5, 8.0, 5), (10, 6.6, 5), (15, 5.2, 4.8), (20, 3.6, 4.4), (24.5, 2.0, 3.6)]):
            r.part("crown", "cone", (rad, rad, h), (0, 0, z + h * 0.5), mat=leaf)
    elif kind == "birch":
        r.part("trunk", "cylinder", (1.5, 1.5, 7.5), (0, 0, 7.5), mat="bone", tex=("stripes", "z", 2.0, 0.3))
        for sx, sy, sz, rad in [(0, 0, 18, 6), (-3.5, 1, 14.5, 4.6), (3.5, -1, 15, 4.8), (0, 3, 21, 4)]:
            r.part("crown", "ellipsoid", (rad, rad, rad), (sx, sy, sz), mat=leaf)
    elif kind == "palm":
        r.part("trunk", "cylinder", (1.3, 1.3, 8.0), (0, 0, 8.0), mat="wood_light", rot=(0, 0, 0))
        for k in range(7):
            a = k * 360 / 7
            r.part("crown", "ellipsoid", (1.0, 6.5, 0.7), (0, 0, 17), mat=leaf, rot=(18, 0, a), soft=0.0) if False else None
            rx = math.radians(a)
            r.part("crown", "ellipsoid", (1.2, 5.5, 0.8), (math.sin(rx) * 5, math.cos(rx) * 5, 16.5 - 0.8), mat=leaf,
                   rot=(-25, 0, -a))
    elif kind == "dead":
        r.part("trunk", "cylinder", (1.8, 1.8, 7.0), (0, 0, 7.0), mat="leaf_dead" if False else "bark")
        for sx, rz in [(-1, 40), (1, -40)]:
            r.part("trunk", "cylinder", (0.8, 0.8, 4.0), (sx * 3.0, 0, 13), mat="bark", rot=(0, sx * 40, 0))
    elif kind == "ulivo":                             # tronco basso e contorto, chioma larga e bassa a ciuffi
        r.part("trunk", "cylinder", (1.6, 1.6, 3.2), (0, 0, 3.2), mat=trunk, rot=(0, 12, 0))
        r.part("trunk", "cylinder", (1.2, 1.2, 3.0), (1.6, 0, 8.0), mat=trunk, rot=(0, -22, 0))
        r.part("trunk", "cylinder", (1.0, 1.0, 2.6), (-1.8, 0.5, 8.5), mat=trunk, rot=(0, 30, 0))
        for k in range(7):
            a = k * 2 * math.pi / 7 + rnd.uniform(-.3, .3)
            rad = rnd.uniform(3.6, 4.6)
            r.part("crown", "ellipsoid", (rad, rad, rad * 0.7),
                   (math.cos(a) * 5.0, math.sin(a) * 3.5, 12 + rnd.uniform(-1, 1.5)), mat=leaf)
        r.part("crown", "ellipsoid", (4.5, 4.5, 3.2), (0, 0, 14.5), mat=leaf)
    elif kind == "cipresso":                          # colonna stretta e alta, punta in cima
        r.part("trunk", "cylinder", (1.0, 1.0, 2.0), (0, 0, 2.0), mat=trunk)
        r.part("crown", "ellipsoid", (3.4, 3.4, 11.0), (0, 0, 13.5), mat=leaf)
        r.part("crown", "cone", (2.2, 2.2, 3.0), (0, 0, 25.5), mat=leaf)
    elif kind == "felce":                             # felce gigante: fusto corto, fronde lunghe ad arco
        r.part("trunk", "cylinder", (1.5, 1.5, 5.0), (0, 0, 5.0), mat=trunk)
        for k in range(10):                           # due giri: fronde alte quasi dritte e fronde basse aperte
            a = k * 360 / 5 + (36 if k >= 5 else 0) + rnd.uniform(-10, 10)
            rx, alta = math.radians(a), k < 5
            r.part("crown", "ellipsoid", (1.5, 8.0, 0.7),
                   (math.sin(rx) * (4.5 if alta else 7.0), math.cos(rx) * (4.5 if alta else 7.0), 15 if alta else 11),
                   mat=leaf, rot=(-55 if alta else -25, 0, -a))
        r.part("crown", "ellipsoid", (2.4, 2.4, 1.8), (0, 0, 10.5), mat=leaf)
    elif kind == "gigante":                           # albero enorme della giungla: contrafforti e liane che pendono
        r.part("trunk", "cylinder", (3.2, 3.2, 8.0), (0, 0, 8.0), mat=trunk)
        for k in range(4):
            a = k * math.pi / 2 + 0.6
            r.part("trunk", "cone", (2.2, 1.2, 2.6), (math.cos(a) * 3.0, math.sin(a) * 3.0, 2.4), mat=trunk,
                   rot=(0, 0, math.degrees(a)))
        for sx, sy, sz, rad in [(0, 0, 22, 11), (-7.5, 2, 18, 8), (7.5, -1.5, 18.5, 8.5), (1.5, 7, 17.5, 7.5),
                                (-1.5, -7, 19.5, 8)]:
            r.part("crown", "ellipsoid", (rad, rad, rad * 0.85), (sx + rnd.uniform(-.8, .8), sy, sz), mat=leaf)
        for k in range(7):                            # liane: fili dal bordo della chioma, davanti al tronco
            x = -9.0 + k * 3.0 + rnd.uniform(-1.2, 1.2)
            lung = rnd.uniform(1.5, 5.5)
            r.part("crown", "cylinder", (0.4, 0.4, lung), (x, 7.5 + rnd.uniform(-1, 1), 13.5 - lung), mat="leaf")
    elif kind == "mushroom":
        r.part("trunk", "cylinder", (2.0, 2.0, 5.0), (0, 0, 5.0), mat="bone")
        r.part("crown", "ellipsoid", (8.0, 8.0, 5.0), (0, 0, 11), mat="mushroom_red")
        for sx, sy in [(-3, 2), (3, 3), (1, -4)]:
            r.part("crown", "ellipsoid", (1.2, 1.2, 0.6), (sx, sy, 15.4), mat="white", soft=0)
    return r


def ossa(seed=1, size=1.0):
    """Ossa nella sabbia delle Marche: un teschio di bestia e qualche costola."""
    rnd = random.Random(seed)
    r = Rig(f"ossa_{seed}"); r.scale = size
    r.joint("body", "root", (0, 0, 0))
    r.part("body", "ellipsoid", (3.0, 2.2, 1.8), (rnd.uniform(-2, 2), 0, 1.4), mat="bone", soft=0.0)
    for k in range(4):
        x = -3.5 + k * 2.2
        r.part("body", "cylinder", (0.45, 0.45, 2.6), (x, 2.5, 1.6), mat="bone", rot=(70, 0, rnd.uniform(-15, 15)))
    r.part("body", "cylinder", (0.5, 0.5, 4.5), (rnd.uniform(-1, 1), -2.5, 0.5), mat="bone", rot=(0, 90, 20))
    return r


def rock(seed=1, mat="stone", size=1.0, moss=True):
    rnd = random.Random(seed)
    r = Rig(f"rock_{seed}"); r.scale = size
    r.joint("body", "root", (0, 0, 0))
    for i in range(3):
        rad = rnd.uniform(3.5, 6)
        r.part("body", "ellipsoid", (rad, rad * rnd.uniform(.8, 1.1), rad * .7), (rnd.uniform(-3, 3), rnd.uniform(-3, 3), rad * .55),
               mat=mat, soft=0.0, rot=(0, 0, rnd.uniform(0, 90)))
    if moss:
        r.part("body", "ellipsoid", (3.5, 3.0, 1.0), (0, 0, 5.2), mat="grass")
    return r


def bush(seed=1, mat="leaf", berries=None, size=1.0):
    rnd = random.Random(seed)
    r = Rig(f"bush_{seed}"); r.scale = size
    r.joint("body", "root", (0, 0, 0))
    for i in range(4):
        rad = rnd.uniform(3.2, 4.6)
        r.part("body", "ellipsoid", (rad, rad, rad * .85), (rnd.uniform(-3.5, 3.5), rnd.uniform(-3, 3), rad * .8), mat=mat)
    if berries:
        for i in range(5):
            r.part("body", "ellipsoid", (.7, .7, .7), (rnd.uniform(-4, 4), rnd.uniform(-4, 4) + 2.0, rnd.uniform(3, 6.5)),
                   mat=berries, soft=0, tex=None)
    return r
