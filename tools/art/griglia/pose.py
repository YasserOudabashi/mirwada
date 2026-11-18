"""Chiavi di posa a tempo normalizzato: [(t, posa), ...] con t in 0..1. Il numero di frame lo da' data/animations.json,
quindi cambiare i frame di un'animazione rifa' le pose senza toccare le chiavi.

Fra due chiavi si passa con ease in/out (i frame vicini alle chiavi restano piu' simili: le pose chiave si leggono).
`ciclo`: il frame dopo l'ultimo e' il primo (si campiona t = i/n); altrimenti il primo e l'ultimo frame sono le chiavi
a t = 0 e t = 1 (t = i/(n-1)). Le chiavi possono dire `"tieni": True` per non interpolare verso la successiva.
"""


def _mix(a, b, k):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return a + (b - a) * k
    if isinstance(a, tuple) and isinstance(b, tuple) and len(a) == len(b):
        return tuple(_mix(x, y, k) for x, y in zip(a, b))
    return a if k < 0.5 else b


def _ease(k):
    return k * k * (3 - 2 * k)


def campiona(chiavi, t, ciclo):
    chiavi = sorted(chiavi, key=lambda c: c[0])
    if ciclo:
        t = t % 1.0
        chiavi = chiavi + [(1.0 + chiavi[0][0], chiavi[0][1])]
    if t <= chiavi[0][0]:
        return dict(chiavi[0][1])
    for (t0, p0), (t1, p1) in zip(chiavi, chiavi[1:]):
        if t0 <= t <= t1:
            if p0.get("tieni") or t1 == t0:
                return dict(p0)
            k = _ease((t - t0) / (t1 - t0))
            out = {}
            for key in set(p0) | set(p1):
                if key == "tieni":
                    continue
                if key in p0 and key in p1:
                    out[key] = _mix(p0[key], p1[key], k)
                else:
                    out[key] = p0.get(key, p1.get(key))
            return out
    return dict(chiavi[-1][1])


def frame(chiavi, n, ciclo, base=None):
    chiavi = [(t, {**(base or {}), **k}) for t, k in chiavi]
    out = []
    for i in range(n):
        t = i / n if ciclo else (i / (n - 1) if n > 1 else 0.0)
        p = dict(base or {})
        p.update(campiona(chiavi, t, ciclo))
        out.append(p)
    return out
