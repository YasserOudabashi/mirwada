"""Le pose dei nemici umani (nemico_base: idle 6, walk 8, anticipo 4, attack 6, stagger 4, death 10) prese da quelle
di Enel: l'arma sempre in mano, il tell (anticipo) e' la carica del colpo pesante col lampo negli occhi, l'attacco e'
il colpo che parte da li', stagger e morte sono hurt e death."""
from . import personaggio as P

IN_MANO = dict(arma=(-20, 25), braccio_r=(24, 18, 40))


def _rifai(chiavi, da, a, extra=None, togli=("due_mani",)):
    """Le chiavi fra il tempo `da` e `a`, riportate su 0..1."""
    fuori = []
    for t, p in chiavi:
        if da - 1e-6 <= t <= a + 1e-6:
            q = {k: x for k, x in p.items() if k not in togli}
            fuori.append(((t - da) / (a - da), {**q, **(extra or {})}))
    return fuori


def _con_arma(chiavi):
    return [(t, {**{k: x for k, x in p.items() if k != "arma_su"}, **IN_MANO}) for t, p in chiavi]


def anim_nemico(due_mani=False):
    togli = () if due_mani else ("due_mani",)
    hv = P.ANIM["attack_heavy"]["chiavi"]
    return {
        "idle": {"chiavi": _con_arma(P.ANIM["idle"]["chiavi"])},
        "walk": {"chiavi": _con_arma(P.ANIM["walk"]["chiavi"])},
        "anticipo": {"chiavi": _rifai(hv, 0.0, 5 / 11, {"lampo": True}, togli)},
        "attack": {"chiavi": _rifai(hv, 5 / 11, 1.0, None, togli)},
        "stagger": {"chiavi": P.ANIM["hurt"]["chiavi"]},
        "death": {"chiavi": P.ANIM["death"]["chiavi"]},
    }
