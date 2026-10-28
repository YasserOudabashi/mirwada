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
        for k in range(4):                            # liane: fili scuri che escono da dentro la chioma
            x = -7.5 + k * 5.0 + rnd.uniform(-1.2, 1.2)
            lung = rnd.uniform(1.5, 3.0)                # mezza lunghezza: pendono fino a meta' tronco, non a terra
            r.part("crown", "cylinder", (0.35, 0.35, lung), (x, 6.5 + rnd.uniform(-1, 1), 14.5 - lung),
                   mat="leaf_dark", rot=(0, rnd.uniform(-8, 8), 0))
    elif kind == "mushroom":
        r.part("trunk", "cylinder", (2.0, 2.0, 5.0), (0, 0, 5.0), mat="bone")
        r.part("crown", "ellipsoid", (8.0, 8.0, 5.0), (0, 0, 11), mat="mushroom_red")
        for sx, sy in [(-3, 2), (3, 3), (1, -4)]:
            r.part("crown", "ellipsoid", (1.2, 1.2, 0.6), (sx, sy, 15.4), mat="white", soft=0)
    return r


def trono(seed=1, size=1.0):
    """Trono del Gigante (concept marche/trono): blocchi di roccia squadrati e un po' storti, schienale altissimo,
    braccioli, gradini rotti alla base. Guarda +y."""
    rnd = random.Random(seed)
    r = Rig(f"trono_{seed}"); r.scale = size
    r.joint("t", "root", (0, 0, 0))
    def blocco(dim, pos, mat="roccia_trono"):
        r.part("t", "box", dim, pos, mat=mat, rot=(rnd.uniform(-3, 3), rnd.uniform(-3, 3), rnd.uniform(-4, 4)))
    blocco((13, 10, 1.6), (0, 1.5, 1.6))                          # gradini
    blocco((11, 8, 1.4), (0, 0.5, 4.4))
    blocco((9, 6.5, 3.2), (0, -0.5, 8.6))                         # seduta
    blocco((9, 2.6, 13), (0, -6.4, 18))                           # schienale altissimo
    blocco((5, 2.2, 5), (-4.5, -6.6, 33.5))                       # cima spezzata, piu' alta a sinistra
    blocco((3.4, 2.2, 3), (4.6, -6.4, 30.5))
    for sx in (-1, 1):                                            # braccioli
        blocco((2.4, 6, 4.2), (sx * 10.2, -0.8, 13.5))
    for k in range(6):                                            # macerie attorno
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(11, 15)
        s_ = rnd.uniform(1.0, 2.2)
        blocco((s_, s_, s_ * 0.8), (math.cos(a) * d, math.sin(a) * d * 0.7, s_ * 0.6), "stone_light")
    return r


def spada(seed=1, size=1.0):
    """Spada piantata nel terreno, un po' inclinata (concept marche: campo di battaglia, piedi del trono)."""
    rnd = random.Random(seed)
    r = Rig(f"spada_{seed}"); r.scale = size
    r.joint("s", "root", (0, 0, 0), rest=(rnd.uniform(-18, 18), rnd.uniform(-18, 18), rnd.uniform(0, 180)))
    r.part("s", "box", (0.25, 0.9, 5.0), (0, 0, 4.2), mat="steel")
    r.part("s", "box", (0.5, 2.6, 0.45), (0, 0, 9.4), mat="iron")          # guardia
    r.part("s", "cylinder", (0.45, 0.45, 1.4), (0, 0, 11.2), mat="leather_dark")
    r.part("s", "ellipsoid", (0.6, 0.6, 0.6), (0, 0, 12.8), mat="iron")    # pomo
    return r


def stendardo(seed=1, size=1.0, mat="cloth_red"):
    """Asta storta con un drappo strappato (concept marche/trono)."""
    rnd = random.Random(seed)
    r = Rig(f"stendardo_{seed}"); r.scale = size
    r.joint("a", "root", (0, 0, 0), rest=(rnd.uniform(-8, 8), rnd.uniform(-10, 10), rnd.uniform(0, 180)))
    r.part("a", "cylinder", (0.35, 0.35, 9.0), (0, 0, 9.0), mat="wood")
    r.part("a", "cone", (0.5, 0.5, 0.8), (0, 0, 18.6), mat="iron")
    for k, (lung, z) in enumerate(((3.4, 15.5), (2.6, 13.8), (1.8, 12.3))):   # strisce sempre piu' corte: strappato
        r.part("a", "box", (0.12, lung, 0.8), (0, lung + 0.3, z), mat=mat, rot=(rnd.uniform(-6, 6), 0, 0))
    return r


# Edifici (US-8B18): tipo -> (pareti, tetto, altezza delle pareti in unita', piani, pendenza del tetto)
CASE_CITTA = ("intonaco", "intonaco", "intonaco_rosa", "intonaco_ocra")   # pareti: una scelta per variante
TIPI_EDIFICIO = {
    "casa": (CASE_CITTA, ("tegole", "tegole", "tegole_vecchie"), 54, 2, 20),     # case strette del quartiere operaio
    "bottega": (CASE_CITTA, ("tegole", "tegole_vecchie"), 72, 2, 18),          # negozi e famiglie del centro storico
    "palazzo": ("pietra_palazzo", "ardesia", 100, 3, 18), # palazzi del centro antico
    "magazzino": ("wood_light", "ardesia", 66, 1, 20),    # magazzini del porto commerciale
    "baracca": ("wood", "paglia", 36, 1, 24),             # baracche dei bassifondi
    "villa": ("intonaco_bianco", "tegole", 64, 2, 20),    # ville della citta' nuova
    "capanna": ("wood", "paglia", 40, 1, 26),             # villaggi, Valle, eremi, accampamenti
    "casale": ("pietra_palazzo", "tegole", 56, 1, 22),    # fattorie e rifugi
    "fienile": ("wood_light", "tegole", 62, 1, 24),       # fattorie
    "torre": ("pietra_palazzo", "ardesia", 150, 4, 0),    # torri di vedetta e fari (tetto a cono)
}
SENO_CAMERA = 0.5299                                      # sin(32 gradi): la camera di engine.render accorcia y


def edificio(tipo, larg, prof, seed=1, size=1.0):
    """Un edificio che a schermo copre esattamente il suo sedime di larg x prof caselle (32 unita' l'una):
    nel modello la profondita' e' divisa per il seno della camera. Origine = centro del lato davanti, a terra;
    il davanti guarda +y (la camera lo gira con yaw 180, come il trono)."""
    rnd = random.Random(seed)
    pareti, tetto, hw, piani, pend = TIPI_EDIFICIO[tipo]
    pareti = rnd.choice(pareti) if isinstance(pareti, tuple) else pareti     # piu' materiali: uno per variante
    tetto = rnd.choice(tetto) if isinstance(tetto, tuple) else tetto
    r = Rig(f"edificio_{tipo}_{larg}x{prof}_{seed}"); r.scale = size
    r.joint("e", "root", (0, 0, 0))
    W = larg * 32 - 6
    D = (prof * 32 - 6) / SENO_CAMERA
    if tipo == "torre":                                   # torre rotonda: cilindro e tetto a cono
        rx = ry = W / 2                                   # un cerchio vero: a schermo e' un'ellisse bassa
        r.part("e", "cylinder", (rx, ry, hw / 2), (0, -ry, hw / 2), mat=pareti)
        r.part("e", "cone", (rx + 2, ry + 2, 30), (0, -ry, hw + 30), mat=tetto)
        r.part("e", "box", (6, 1.6, 12), (0, 0.6, 12), mat="wood")
        for f in range(1, piani):
            r.part("e", "box", (3, 1.2, 5), (rnd.uniform(-rx * 0.3, rx * 0.3), 0.4, hw * f / piani + 8), mat="vetro")
        return r
    hw = hw + rnd.choice((0, 0, 4, -2))
    r.part("e", "box", (W / 2, D / 2, hw / 2), (0, -D / 2, hw / 2), mat=pareti)
    # tetto a due falde con il colmo lungo x a 3/4 della profondita': la falda davanti (in luce) copre quasi
    # tutto il sedime, quella dietro (in ombra) resta una striscia
    a = math.radians(pend)
    fd = 0.75 * D
    rh = fd * math.tan(a)
    b = math.degrees(math.atan2(rh, D - fd))
    r.part("e", "box", (W / 2 + 4, fd / math.cos(a) / 2 + 3, 2.5), (0, -fd / 2, hw + rh / 2),
           mat=tetto, rot=(-pend, 0, 0))                  # falda davanti: sale verso il colmo
    r.part("e", "box", (W / 2 + 4, (D - fd) / math.cos(math.radians(b)) / 2 + 2, 2.5),
           (0, -fd - (D - fd) / 2, hw + rh / 2), mat=tetto, rot=(b, 0, 0))
    r.part("e", "box", (W / 2 + 4, 2.5, 2.5), (0, -fd, hw + rh + 1.5), mat=tetto)      # colmo
    if tipo in ("casa", "bottega", "palazzo", "villa") and rnd.random() < 0.7:          # comignolo
        cx = rnd.choice((-1, 1)) * W * 0.3
        r.part("e", "box", (3, 3, 8), (cx, -fd * 0.7, hw + rh * 0.7 + 6), mat="brick")
    # porta al centro (un po' spostata), con soglia
    px = 0.0                                              # al centro del fronte: la porta di gioco sta li'
    rnd.random()                                          # (stessa sequenza casuale di prima per il resto)
    larg_p = 14 if tipo in ("magazzino", "palazzo") else 9
    alt_p = min(hw * 0.7, 26 if tipo != "baracca" else 16)
    r.part("e", "box", (larg_p / 2 + 1.5, 1.2, alt_p / 2 + 1), (px, 0.6, alt_p / 2 + 1), mat="stone" if tipo == "palazzo" else "wood_light")
    r.part("e", "box", (larg_p / 2, 1.6, alt_p / 2), (px, 1.0, alt_p / 2), mat="wood")
    # finestre: per piano, distribuite sul fronte lasciando libera la porta
    for f in range(piani):
        z = hw * (f + 0.6) / piani
        n = max(1, int(W // 28))
        for i in range(n):
            x = -W / 2 + W * (i + 0.5) / n
            if f == 0 and abs(x - px) < larg_p:
                continue
            if z - 6 < alt_p and abs(x - px) < larg_p + 6:
                continue
            r.part("e", "box", (4.5, 1.0, 5.5), (x, 0.5, z), mat="wood_light")
            r.part("e", "box", (3.2, 1.4, 4.2), (x, 0.8, z), mat="vetro")
    if tipo == "bottega" and rnd.random() < 0.8:                                         # tenda della bottega
        r.part("e", "box", (W * 0.35, 5, 1.2), (px, 5, alt_p + 4), mat=rnd.choice(("cloth_red", "cloth_green", "cloth_blue", "cloth_yellow")), rot=(-25, 0, 0))
    if tipo == "magazzino":                                       # casse contro il muro, dentro il sedime
        for k in range(rnd.randint(1, 3)):
            r.part("e", "box", (4, 4, 4), (W / 2 - 8 - k * 9, 2.5, 4), mat="wood_light")
    return r


def ingresso(kind="scale", seed=1, size=1.0):
    """Ingressi del sottosuolo (stesso punto sopra e sotto): 'botola' (fogne, grata di ferro in un anello di pietra),
    'scale' (gradini di pietra che scendono nel buio, catacombe/miniere/grotte/citta' sotterranea), 'risalita' (dal
    sottosuolo: scala a pioli verso la luce)."""
    rnd = random.Random(seed)
    r = Rig(f"ingresso_{kind}_{seed}"); r.scale = size
    r.joint("b", "root", (0, 0, 0))
    # misure: box = semi-lati, cylinder = (raggio x, raggio y, mezza altezza)
    if kind == "botola":
        r.part("b", "cylinder", (5.4, 5.4, 0.5), (0, 0, 0.5), mat="stone_light", soft=0.4)    # anello, cima a z 1
        r.part("b", "cylinder", (3.9, 3.9, 0.1), (0, 0, 1.05), mat="shadow_mat")              # il buio sotto la grata
        for i in (-1, 0, 1):
            r.part("b", "box", (0.35, 3.7, 0.12), (i * 1.4, 0, 1.25), mat="iron")
        r.part("b", "box", (3.7, 0.35, 0.12), (0, 0, 1.3), mat="iron")
    elif kind == "scale":
        r.part("b", "box", (4.6, 3.8, 0.1), (0, -0.6, 0.1), mat="shadow_mat")                  # il buio in fondo
        for k, (y, z, mat) in enumerate(((2.5, 0.55, "stone_light"), (1.1, 0.4, "stone"), (-0.3, 0.25, "stone"))):
            r.part("b", "box", (3.6, 0.7, 0.15), (0, y, z), mat=mat, rot=(0, 0, rnd.uniform(-2, 2)))
        r.part("b", "box", (5.8, 0.9, 1.0), (0, -4.4, 1.0), mat="stone")                       # muretto in fondo
        for sx in (-1, 1):                                                                      # spallette
            r.part("b", "box", (0.9, 4.4, 0.8), (sx * 4.9, -0.5, 0.8), mat="stone", rot=(0, 0, rnd.uniform(-2, 2)))
    elif kind == "porta":                                                                       # porta nella roccia
        r.part("b", "box", (6.5, 1.6, 7.5), (0, -0.4, 7.5), mat="stone")                        # stipiti e architrave
        r.part("b", "box", (4.6, 1.8, 6.0), (0, 0.2, 6.0), mat="wood")
        r.part("b", "box", (0.5, 2.0, 0.5), (2.6, 0.4, 6.0), mat="iron")                        # maniglia
        r.part("b", "box", (5.2, 3.0, 0.4), (0, 2.6, 0.4), mat="stone_light")                    # soglia
    else:                                                                                       # risalita
        r.part("b", "ellipsoid", (3.4, 2.4, 0.15), (0, 1.4, 0.15), mat="stone_light")          # pietra chiara: la luce
        for sx in (-1, 1):
            r.part("b", "cylinder", (0.45, 0.45, 5.5), (sx * 1.6, -1.0, 5.4), mat="wood", rot=(-14, 0, 0))
        for k in range(5):
            r.part("b", "box", (1.7, 0.18, 0.18), (0, -0.3 - k * 0.55, 1.4 + k * 2.1), mat="wood_light", rot=(-14, 0, 0))
    return r


ASPETTI_VARCO = ("cancello_cripta", "arco_ombra", "ponte_radici", "grotta", "porta_glifi", "soglia_nebbia", "faro")


def varco(aspetto, aperto=False, seed=1, size=1.0):
    """Varchi verso le sotto-aree (US-8B21a): un oggetto che sta in piedi da solo davanti alla sua porta, chiuso o
    aperto. Misure in unita' (32 per casella), origine al centro del lato davanti, il davanti guarda +y; la
    profondita' del modello e' divisa per SENO_CAMERA come negli edifici. Il giocatore deve capire che c'e' un
    passaggio, non come si apre: chiuso = sbarrato (grata, ombra che non segue la luce, radici spezzate, marea alta,
    glifi accesi, nebbia), aperto = la via libera."""
    rnd = random.Random(seed)
    r = Rig(f"varco_{aspetto}_{int(aperto)}"); r.scale = size
    r.joint("v", "root", (0, 0, 0))
    P = 1.0 / SENO_CAMERA
    cy = -16 * P                                          # il centro della casella dietro la porta

    def box(dim, pos, mat, rot=(0, 0, 0)):
        r.part("v", "box", dim, pos, mat=mat, rot=rot)

    def ell(dim, pos, mat):
        r.part("v", "ellipsoid", dim, pos, mat=mat)

    if aspetto == "cancello_cripta":                      # mausoleo: zoccolo, colonne, timpano, porta con la grata
        box((40, 24, 3), (0, cy, 3), "stone_light")
        box((28, 18, 20), (0, cy - 2, 26), "stone")
        box((33, 22, 3), (0, cy - 2, 49), "stone_light")
        box((24, 16, 4), (0, cy - 2, 56), "stone")
        for sx in (-1, 1):
            r.part("v", "cylinder", (3, 3, 20), (sx * 23, cy + 12, 26), mat="stone_light")
        fronte = cy - 2 + 18
        box((9, 1.0, 14), (0, fronte + 0.6, 20), "shadow_mat")
        if aperto:
            box((9, 4, 1), (0, fronte + 4, 4), "stone")
        else:
            for k in range(5):
                box((0.8, 1.2, 13.5), (-8 + k * 4, fronte + 1.6, 20), "iron")
            box((9.5, 1.2, 0.9), (0, fronte + 1.7, 26), "iron")
    elif aspetto == "arco_ombra":                         # due pilastri di roccia e un architrave storti
        for sx in (-1, 1):
            box((7, 9, 24), (sx * 16, cy, 24), "roccia_trono", rot=(rnd.uniform(-3, 3), 0, rnd.uniform(-4, 4)))
        box((26, 10, 6), (0, cy, 52), "roccia_trono", rot=(0, rnd.uniform(-4, 4), 0))
        if aperto:
            box((9, 8, 0.4), (0, cy, 0.4), "stone")
        else:                                             # un'ombra troppo scura, che non segue la luce
            box((9, 2, 23), (0, cy, 23), "shadow_mat")
            for sx in (-1, 1):
                box((1.3, 2.2, 22), (sx * 8.2, cy + 0.4, 23), "glow_purple")
            box((9, 2.2, 1.3), (0, cy + 0.4, 45), "glow_purple")
            for k in range(4):                            # filamenti che si muovono contro la luce
                box((0.8, 2.3, 0.8), (rnd.uniform(-5, 5), cy + 0.5, rnd.uniform(8, 40)), "glow_purple")
    elif aspetto == "ponte_radici":                       # un burrone; aperto: le radici lo attraversano
        r.part("v", "cylinder", (36, 15 * P, 0.3), (0, cy, 0.2), mat="stone")          # orlo di terra e sassi
        r.part("v", "cylinder", (32, 13 * P, 0.3), (0, cy, 0.5), mat="shadow_mat")     # il vuoto
        for sx in (-1, 1):
            for sy in (-1, 1):
                r.part("v", "cylinder", (4, 4, 5), (sx * 30, cy + sy * 9 * P, 5), mat="bark")
        if aperto:                                        # radici intrecciate da un orlo all'altro
            for k in (-7, -2.5, 2.5, 7):
                box((2.2, 15 * P, 2.0), (k, cy, 3.5 - abs(k) * 0.15), "wood_light", rot=(0, 0, k * 1.2))
            for k in range(7):
                ell((3, 3, 2), (rnd.uniform(-9, 9), cy + rnd.uniform(-11, 11) * P, 6), "leaf")
        else:                                             # radici spezzate che pendono nel vuoto
            for sx in (-1, 1):
                box((2.0, 5 * P, 2.0), (sx * 12, cy + 8 * P, 3), "wood_light", rot=(-35, 0, sx * 15))
                box((2.0, 5 * P, 2.0), (sx * 10, cy - 8 * P, 3), "wood_light", rot=(35, 0, sx * 15))
    elif aspetto == "grotta":                             # cumulo di roccia con la bocca; chiuso: la marea alta
        ell((30, 18, 24), (0, cy - 4, 20), "stone")
        ell((14, 10, 12), (-20, cy + 4, 10), "stone")
        ell((12, 9, 10), (21, cy + 2, 9), "stone")
        bocca = cy - 4 + 17
        ell((10, 2, 13), (0, bocca, 11), "shadow_mat")
        if aperto:
            ell((5, 3, 1.2), (-4, bocca + 5, 1), "stone_light")
            ell((4, 2.5, 1.0), (5, bocca + 7, 1), "stone_light")
        else:
            box((10, 1.5, 6), (0, bocca + 1.2, 5), "water")
            ell((16, 6, 1.0), (0, bocca + 6, 0.8), "water")
    elif aspetto == "porta_glifi":                        # porta sigillata con i glifi (Archivio, decisione 13/10)
        box((22, 10, 2), (0, cy, 2), "stone_light")
        for sx in (-1, 1):
            box((4, 6, 22), (sx * 14, cy, 24), "stone")
        box((18, 6, 4), (0, cy, 49), "stone_light")
        if aperto:
            box((10, 1.0, 20), (0, cy + 5.6, 24), "shadow_mat")
            for k in range(3):
                box((9, 2, 0.6), (0, cy + 5 - k * 3, 3.5 - k), "stone")
        else:
            box((10, 2, 20), (0, cy + 4, 24), "stone")
            for k in range(8):                            # un anello di glifi e uno al centro
                a = k * math.pi / 4
                box((1.6, 0.6, 1.6), (math.cos(a) * 6, cy + 6.2, 24 + math.sin(a) * 7), "glow_cyan")
            box((1.4, 0.6, 1.4), (0, cy + 6.2, 24), "glow_cyan")
    elif aspetto == "soglia_nebbia":                      # una cornice di porta sola; chiuso: la nebbia la riempie
        for sx in (-1, 1):
            box((2, 3, 25), (sx * 11, cy, 25), "intonaco_bianco")
        box((13, 3, 2), (0, cy, 51), "intonaco_bianco")
        box((13, 6, 1), (0, cy + 2, 1), "wood_light")
        if aperto:                                        # dall'altra parte: il buio di un altro posto
            box((9, 1, 24), (0, cy, 25), "shadow_mat")
            for sx in (-1, 1):
                box((1.2, 1.2, 24), (sx * 8.2, cy + 0.3, 25), "glow_purple")
            box((9, 1.2, 1.2), (0, cy + 0.3, 48.4), "glow_purple")
        else:
            for k in range(9):
                ell((rnd.uniform(5, 8), 4, rnd.uniform(4, 7)), (rnd.uniform(-6, 6), cy + rnd.uniform(-2, 3),
                                                               rnd.uniform(4, 46)), "snow")
    elif aspetto == "faro":                               # US-8B95: il faro, con la soglia verso la Frontiera alla base
        box((13, 9, 2.5), (0, cy, 2.5), "stone")
        r.part("v", "cylinder", (8, 8, 30), (0, cy, 35), mat="intonaco_bianco")
        for z in (22, 46):
            r.part("v", "cylinder", (8.4, 8.4, 3.5), (0, cy, z), mat="cloth_red")
        r.part("v", "cylinder", (10.5, 10.5, 1.2), (0, cy, 66), mat="iron")
        r.part("v", "cylinder", (5.5, 5.5, 5), (0, cy, 72.5), mat="glow_yellow")
        r.part("v", "cone", (7.5, 7.5, 5), (0, cy, 82), mat="cloth_red")
        porta = cy + 8.2
        if aperto:                                        # dall'altra parte: il buio delle soglie della Frontiera
            box((3.8, 1.0, 7), (0, porta, 12), "shadow_mat")
            for sx in (-1, 1):
                box((0.8, 1.2, 7), (sx * 3.6, porta + 0.3, 12), "glow_purple")
        else:
            box((3.8, 1.0, 7), (0, porta, 12), "wood")
            box((0.8, 0.6, 0.8), (2.2, porta + 0.8, 12), "gold")
    else:
        raise ValueError(f"varco sconosciuto: {aspetto}")
    return r


def barca(seed=1, size=1.0):
    """Barca a remi (US-8B91), lunga lungo x (a schermo di fianco): scafo basso con prua e poppa a punta,
    falchetta chiara sui due lati, dentro scuro, una panca. Misure in unita'; origine al centro, sul pelo
    dell'acqua. Ci sta dentro il giocatore."""
    r = Rig(f"barca_{seed}"); r.scale = size
    r.joint("b", "root", (0, 0, 0))
    r.part("b", "box", (13, 7, 2.5), (0, 0, 2.5), mat="wood")                         # scafo
    r.part("b", "cone", (2.5, 7, 4.5), (17.5, 0, 2.5), mat="wood", rot=(0, 90, 0))    # prua
    r.part("b", "cone", (2.5, 7, 3), (-16, 0, 2.5), mat="wood", rot=(0, -90, 0))      # poppa
    r.part("b", "box", (12.5, 5.6, 0.3), (0, 0, 4.8), mat="shadow_mat")               # dentro
    for sy in (-1, 1):                                                                 # falchetta
        r.part("b", "box", (13, 0.9, 0.7), (0, sy * 6.4, 5.2), mat="wood_light")
    r.part("b", "box", (1.3, 5.6, 0.5), (-3, 0, 5.2), mat="wood_light")               # panca
    return r


def nave(seed=1, size=1.0):
    """La nave della base (US-8B20d), ormeggiata: lunga lungo x come la barca (a schermo di fianco), scafo alto con
    la fascia rossa, prua a punta, castello di poppa col parapetto, un albero con la vela di taglio (si vede di
    fianco), il bompresso, una bandierina. Origine al centro, sul pelo dell'acqua; a size 1.4 (worldrender) ~6 caselle
    di lunghezza col bompresso."""
    r = Rig(f"nave_{seed}"); r.scale = size
    r.joint("b", "root", (0, 0, 0))
    r.part("b", "box", (40, 13, 5), (0, 0, 5), mat="wood")                              # scafo
    r.part("b", "box", (40.2, 13.2, 1.2), (0, 0, 7.5), mat="cloth_red")                 # fascia sotto il ponte
    r.part("b", "cone", (5, 13, 12), (52, 0, 5), mat="wood", rot=(0, 90, 0))            # prua
    r.part("b", "box", (39, 11.6, 0.4), (0, 0, 10.2), mat="wood_light")                 # ponte
    for sy in (-1, 1):                                                                   # murate
        r.part("b", "box", (40, 1.0, 1.0), (0, sy * 12.4, 11.0), mat="wood")
    r.part("b", "box", (11, 13, 4), (-29, 0, 13.5), mat="wood")                         # castello di poppa
    r.part("b", "box", (11, 13.2, 0.8), (-29, 0, 17.8), mat="wood_light")
    for sy in (-1, 1):
        r.part("b", "box", (11, 0.8, 1.2), (-29, sy * 12.4, 19.4), mat="wood")
    r.part("b", "box", (0.8, 4, 2.5), (-40.2, 0, 13.5), mat="vetro")                    # finestra di poppa
    r.part("b", "box", (2.4, 3.6, 3.0), (-17.5, -9.6, 13.2), mat="shadow_mat")         # porta del castello
    r.part("b", "cylinder", (1.3, 1.3, 32), (8, 0, 42), mat="wood")                     # albero
    r.part("b", "cylinder", (0.8, 0.8, 16), (8 - 14, 0, 30), mat="wood", rot=(0, 90, 0))  # boma
    r.part("b", "box", (14, 0.5, 18), (-6, 0, 50), mat="cloth_cream")                    # vela (randa)
    r.part("b", "box", (14.2, 0.6, 2.0), (-6, 0, 58), mat="cloth_red")                  # fascia della vela
    r.part("b", "cylinder", (0.7, 0.7, 13), (62, 0, 13), mat="wood", rot=(0, 70, 0))    # bompresso
    r.part("b", "box", (4, 0.3, 2.4), (12, 0, 72), mat="cloth_red")                     # bandierina
    r.part("b", "ellipsoid", (2.0, 2.0, 1.2), (24, -8, 12.2), mat="wood_light")         # botte sul ponte
    r.part("b", "box", (3, 3, 2.2), (30, 5, 12.5), mat="wood")                          # cassa
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
