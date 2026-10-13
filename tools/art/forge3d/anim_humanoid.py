"""Animazioni per il rig umanoide: ogni funzione ritorna una lista di pose (una per frame).

Le fasi (anticipo / attivi / recupero) seguono i frame di data/animations.json di Mirwada, ma i
numeri di frame sono parametri: cambia `n` e il movimento si ridistribuisce da solo.
"""
import math

from .humanoid import REST
from .rig import add_pose, clip_from_keys, lerp_pose, sample, scale_pose


def _p(**kw):
    """Scorciatoia: _p(arm_r=(60,0,0)) -> posa sommata a REST."""
    return add_pose(REST, kw)


def idle(n=4):
    out = []
    for i in range(n):
        s = math.sin(2 * math.pi * i / n)
        out.append(add_pose(REST, {
            "hips": (0, 0, 0, 0, 0, -0.35 * (1 - s) / 2),
            "torso": (-1.5 * s, 0, 0),
            "head": (1.2 * s, 0, 0),
            "arm_l": (1.5 * s, 0, 0), "arm_r": (-1.5 * s, 0, 0),
            "leg_l": (0, 0, 0), "shin_l": (0, 0, 0)}))
    return out


def walk(n=6, stride=32, bob=0.7, arms=26, lean=4):
    out = []
    for i in range(n):
        p = 2 * math.pi * i / n
        s, c = math.sin(p), math.cos(p)
        out.append(add_pose(REST, {
            "hips": (0, 0, 3 * s, 0, 0, -bob * abs(math.sin(p))),
            "torso": (-lean, 0, -3 * s),
            "head": (-2, 0, 2 * s),
            "leg_l": (stride * s, 0, 0), "leg_r": (-stride * s, 0, 0),
            "shin_l": (-34 * max(0.0, c), 0, 0), "shin_r": (34 * min(0.0, c), 0, 0),
            "arm_l": (-arms * s, 0, 0), "arm_r": (arms * s, 0, 0),
            "fore_l": (8 + 6 * max(0, s), 0, 0), "fore_r": (8 + 6 * max(0, -s), 0, 0),
            "cape": (6 + 10 * abs(s), 0, 0)}))
    return out


def run(n=6):
    return walk(n, stride=48, bob=1.2, arms=45, lean=14)


def dash(n=4):
    keys = [(0, _p(hips=(0, 0, 0, 0, 0, -1.5), torso=(-28, 0, 0), head=(-14, 0, 0),
                    leg_l=(38, 0, 0), leg_r=(-42, 0, 0), shin_r=(-40, 0, 0), arm_l=(-50, 0, 0), arm_r=(40, 0, 0),
                    cape=(40, 0, 0))),
            (n - 1, _p(hips=(0, 0, 0, 0, 0, -0.6), torso=(-22, 0, 0), head=(-10, 0, 0),
                       leg_l=(-34, 0, 0), leg_r=(30, 0, 0), shin_l=(-35, 0, 0), arm_l=(-44, 0, 0),
                       arm_r=(30, 0, 0), cape=(50, 0, 0)), "linear")]
    return clip_from_keys(keys, n)


def attack_light(n=5):
    """anticipo 0-1, attivo 2, recupero 3-4: colpo diagonale dall'alto a destra verso il basso."""
    windup = _p(torso=(-6, 0, 14), hips=(0, 0, -8), arm_r=(125, 0, 20), fore_r=(25, 0, 0),
                weapon=(25, 0, 0), head=(-4, 0, 6), leg_l=(10, 0, 0), leg_r=(-14, 0, 0), shin_r=(-10, 0, 0))
    hit = _p(torso=(10, 0, -22), hips=(0, 0, 12, 0, 1.2, -0.6), arm_r=(70, 0, -12), fore_r=(0, 0, 0), weapon=(-45, 0, 0),
             head=(2, 0, -8), leg_l=(-12, 0, 0), leg_r=(22, 0, 0), arm_l=(-20, 0, 0))
    follow = _p(torso=(8, 0, -14), hips=(0, 0, 8, 0, 0.6, -0.4), arm_r=(55, 0, -18), fore_r=(0, 0, 0), weapon=(-35, 0, 0),
                leg_r=(14, 0, 0), leg_l=(-8, 0, 0))
    keys = [(0, _p(), "out"), (1, windup, "in"), (2, hit, "snap"), (3, follow, "out"), (n - 1, REST, "inout")]
    keys = [(min(k[0], n - 1),) + k[1:] for k in keys]
    return clip_from_keys(keys, n)


def attack_heavy(n=8):
    """anticipo 0-3 (carica lenta, leggibile), attivi 4-5, recupero 6-7."""
    wind1 = _p(torso=(-4, 0, 8), arm_r=(110, 0, 10), fore_r=(30, 0, 0), weapon=(15, 0, 0), hips=(0, 0, -3))
    wind2 = _p(torso=(-14, 0, 20), arm_r=(150, 0, 22), fore_r=(25, 0, 0), weapon=(35, 0, 0), hips=(0, 0, -10, 0, -0.8, -1.0),
               head=(-8, 0, 8), leg_l=(14, 0, 0), leg_r=(-18, 0, 0), shin_r=(-18, 0, 0), arm_l=(40, 0, 0))
    hit = _p(torso=(16, 0, -26), arm_r=(65, 0, -14), fore_r=(0, 0, 0), weapon=(-55, 0, 0), hips=(0, 0, 16, 0, 1.8, -1.4),
             head=(6, 0, -10), leg_l=(-20, 0, 0), leg_r=(34, 0, 0), shin_l=(-10, 0, 0), arm_l=(-30, 0, 0))
    hit2 = _p(torso=(20, 0, -30), arm_r=(50, 0, -18), fore_r=(0, 0, 0), weapon=(-60, 0, 0), hips=(0, 0, 20, 0, 2.2, -1.8),
              head=(8, 0, -12), leg_l=(-22, 0, 0), leg_r=(36, 0, 0), arm_l=(-34, 0, 0))
    keys = [(0, _p(), "inout"), (1, wind1, "inout"), (3, wind2, "hold"), (4, hit, "snap"),
            (5, hit2, "out"), (6, hit2, "inout"), (n - 1, REST, "inout")]
    return clip_from_keys(keys, n)


def parry(n=4):
    up = _p(torso=(-8, 0, 6), arm_r=(95, 0, 30), fore_r=(60, 0, 0), weapon=(0, 0, 0), arm_l=(70, 0, -10),
            fore_l=(60, 0, 0), leg_r=(-14, 0, 0), leg_l=(10, 0, 0), hips=(0, 0, 0, 0, 0, -0.8))
    keys = [(0, up, "out"), (1, up, "inout"), (2, add_pose(up, {"arm_r": (-8, 0, 6)}), "inout"), (n - 1, REST)]
    return clip_from_keys(keys, n)


def hurt(n=3):
    a = _p(torso=(-22, 0, 8), head=(-18, 0, 10), hips=(0, 0, 0, 0, -1.2, 0), arm_l=(50, 0, 0), arm_r=(60, 0, 0),
           leg_l=(10, 0, 0), leg_r=(-12, 0, 0), cape=(35, 0, 0))
    b = _p(torso=(-12, 0, 4), head=(-10, 0, 5), hips=(0, 0, 0, 0, -0.6, 0))
    return clip_from_keys([(0, a, "out"), (1, a), (n - 1, b)], n)


def death(n=8):
    """Cade all'indietro e resta a terra (non direzionale: si guarda dal davanti)."""
    keys = [(0, _p(), "out"),
            (1, _p(hips=(0, 0, 0, 0, -0.8, -1), torso=(-18, 0, 0), head=(-14, 0, 0), arm_l=(40, 0, 0), arm_r=(50, 0, 0)), "in"),
            (3, _p(hips=(-55, 0, 0, 0, -4, -5), torso=(-10, 0, 0), head=(-20, 0, 0), arm_l=(70, 0, 0), arm_r=(80, 0, 0),
                   leg_l=(40, 0, 0), leg_r=(34, 0, 0), shin_l=(-20, 0, 0)), "in"),
            (5, _p(hips=(-86, 0, 0, 0, -8, -8.2), torso=(0, 0, 0), head=(-8, 0, 0), arm_l=(10, 0, 0), arm_r=(120, 0, 10),
                   leg_l=(20, 0, 0), leg_r=(14, 0, 0)), "out"),
            (n - 1, _p(hips=(-90, 0, 0, 0, -9, -9.4), torso=(0, 0, 0), head=(-4, 0, 0), arm_l=(4, 0, 0), arm_r=(130, 0, 14),
                       leg_l=(8, 0, 0), leg_r=(6, 0, 0)), "out")]
    return clip_from_keys(keys, n)


def cast(n=6):
    """Mano libera in avanti, rilascio al frame 3."""
    gather = _p(arm_l=(40, 0, -20), fore_l=(80, 0, 0), torso=(-6, 0, 0), head=(-6, 0, 0))
    push = _p(arm_l=(98, 0, 0), fore_l=(10, 0, 0), torso=(8, 0, 0), head=(2, 0, 0), hips=(0, 0, 0, 0, 0.8, -0.5),
              leg_r=(-12, 0, 0), leg_l=(10, 0, 0))
    keys = [(0, _p(), "out"), (1, gather, "inout"), (2, gather, "inout"), (3, push, "snap"), (4, push), (n - 1, REST)]
    return clip_from_keys(keys, n)


def meditate(n=6):
    """Seduto a gambe incrociate (si abbassa il bacino) con respiro lento."""
    out = []
    for i in range(n):
        s = math.sin(2 * math.pi * i / n)
        out.append(add_pose(REST, {
            "hips": (0, 0, 0, 0, 0, -4.4 - 0.25 * s),
            "leg_l": (88, 0, -22), "leg_r": (88, 0, 22), "shin_l": (-125, 0, 0), "shin_r": (-125, 0, 0),
            "arm_l": (28, 0, -8), "arm_r": (28, 0, 8), "fore_l": (62, 0, 0), "fore_r": (62, 0, 0),
            "torso": (-1 + 1.2 * s, 0, 0), "head": (2 + 1.5 * s, 0, 0)}))
    return out


def anticipo(n=4):
    """Il 'tell' del nemico: si carica, leggibile."""
    keys = [(0, _p(), "out"), (1, _p(torso=(-8, 0, 0), arm_r=(120, 0, 10), fore_r=(50, 0, 0), hips=(0, 0, 0, 0, 0, -1.2)), "inout"),
            (n - 1, _p(torso=(-14, 0, 6), arm_r=(160, 0, 16), fore_r=(60, 0, 0), hips=(0, 0, 0, 0, -0.6, -1.8), head=(-8, 0, 0)))]
    return clip_from_keys(keys, n)


def enemy_attack(n=4):
    hit = _p(torso=(18, 0, -16), arm_r=(70, 0, -8), fore_r=(0, 0, 0), hips=(0, 0, 10, 0, 2.0, -1.0), head=(6, 0, 0))
    return clip_from_keys([(0, _p(torso=(-14, 0, 6), arm_r=(160, 0, 16), fore_r=(60, 0, 0))), (1, hit, "snap"),
                           (2, hit), (n - 1, REST)], n)


def stagger(n=4):
    a = hurt(3)[0]
    return clip_from_keys([(0, a, "out"), (1, a), (2, add_pose(a, {"torso": (6, 0, -6)})), (n - 1, REST)], n)


CLIPS = {"idle": idle, "walk": walk, "run": run, "dash": dash, "attack_light": attack_light,
         "attack_heavy": attack_heavy, "parry": parry, "hurt": hurt, "death": death, "cast": cast,
         "meditate": meditate, "anticipo": anticipo, "attack": enemy_attack, "stagger": stagger}
