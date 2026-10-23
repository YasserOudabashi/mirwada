"""Generatore di mondo: elevazione, clima, biomi, fiumi, laghi, insediamenti, strade, oggetti e spawn.

Tutto e' deterministico dal `seed`. Restituisce un `World` con array numpy (ground/biome/elevazione)
e liste serializzabili (oggetti, spawn, npc, insediamenti) pronte per l'export JSON.
"""
import heapq
import json
import math
import random
from dataclasses import dataclass, field

import numpy as np

from .terrain import ORDER

LEVEL = {n: i for i, n in enumerate(ORDER)}


def fbm(W, H, scale, octaves, seed, persistence=0.5):
    rng = np.random.RandomState(seed)
    out = np.zeros((H, W)); amp, tot = 1.0, 0.0
    for o in range(octaves):
        gw = int(W / scale * (2 ** o)) + 3
        gh = int(H / scale * (2 ** o)) + 3
        g = rng.rand(gh, gw)
        ys = np.arange(H) * (gh - 3) / H; xs = np.arange(W) * (gw - 3) / W
        y0 = ys.astype(int); x0 = xs.astype(int)
        fy = (ys - y0); fx = (xs - x0)
        fy = (fy * fy * (3 - 2 * fy))[:, None]; fx = (fx * fx * (3 - 2 * fx))[None, :]
        a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x0 + 1)]; c = g[np.ix_(y0 + 1, x0)]; d = g[np.ix_(y0 + 1, x0 + 1)]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        tot += amp; amp *= persistence
    out /= tot
    return (out - out.min()) / (np.ptp(out) + 1e-9)


BIOME_GROUND = {"ocean": "deep_water", "sea": "water", "beach": "sand", "desert": "sand", "savanna": "dry_grass",
                "plains": "grass", "forest": "forest", "swamp": "mud", "taiga": "forest", "tundra": "snow",
                "hills": "grass", "mountain": "stone", "peak": "snow", "badlands": "dirt", "lake": "water",
                "river": "water"}


@dataclass
class World:
    W: int
    H: int
    seed: int
    ground: np.ndarray
    biome: np.ndarray
    elev: np.ndarray
    biome_names: list
    objects: list = field(default_factory=list)
    spawns: list = field(default_factory=list)
    settlements: list = field(default_factory=list)
    roads: list = field(default_factory=list)
    water_mask: np.ndarray = None

    def to_json(self):
        return {"width": self.W, "height": self.H, "seed": self.seed, "terrains": ORDER,
                "ground": self.ground.tolist(), "biomes": self.biome_names,
                "biome_map": self.biome.tolist(),
                "objects": self.objects, "spawns": self.spawns, "settlements": self.settlements, "roads": self.roads}


def generate(W=128, H=96, seed=1, sea=0.40, island=0.55, rivers=10, lakes=6, settlements=5, cold_north=True,
             forest_density=1.0, wetness=0.0):
    rnd = random.Random(seed)
    e = 0.65 * fbm(W, H, 28, 5, seed) + 0.35 * fbm(W, H, 9, 3, seed + 1)
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx / W - 0.5) * 2) ** 2 + ((yy / H - 0.5) * 2) ** 2)
    e = e - island * np.clip(d - 0.3, 0, 1) ** 1.4 * 1.6
    e = (e - e.min()) / np.ptp(e)
    m = np.clip(fbm(W, H, 24, 4, seed + 2) + wetness, 0, 1)
    t = np.clip((1 - yy / H * 0.8 if cold_north else 0.5 + 0.0 * yy) * 0.85 + 0.35 * fbm(W, H, 30, 3, seed + 3) - 0.1
                - np.clip(e - sea - 0.25, 0, 1) * 0.9, 0, 1)
    # a mano: ricalibra il livello del mare per ottenere ~ (1-sea) di terraferma percentuale
    sea_lv = np.quantile(e, sea)
    names = ["ocean", "sea", "beach", "desert", "savanna", "plains", "forest", "swamp", "taiga", "tundra", "hills",
             "mountain", "peak", "badlands", "lake", "river"]
    ix = {n: i for i, n in enumerate(names)}
    biome = np.zeros((H, W), int)
    eh = e - sea_lv
    top = 1 - sea_lv
    for y in range(H):
        for x in range(W):
            h, mm, tt = eh[y, x], m[y, x], t[y, x]
            if h < -0.10: b = "ocean"
            elif h < 0: b = "sea"
            elif h < 0.025: b = "beach"
            elif h > 0.80 * top: b = "peak" if tt < 0.6 else "mountain"
            elif h > 0.60 * top: b = "mountain" if mm < 0.62 else "hills"
            elif h > 0.44 * top and mm < 0.55: b = "hills"
            elif tt < 0.25: b = "tundra" if mm < 0.6 else "taiga"
            elif tt < 0.4: b = "taiga" if mm > 0.45 else "plains"
            elif tt > 0.62 and mm < 0.32: b = "desert"
            elif tt > 0.55 and mm < 0.42: b = "savanna"
            elif mm > 0.68 and h < 0.12 * top: b = "swamp"
            elif mm > 0.52: b = "forest"
            else: b = "plains"
            biome[y, x] = ix[b]
    water = biome <= ix["sea"]

    # --- laghi: minimi locali pieni fino a un'altezza ---
    def nb4(y, x):
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy_, xx_ = y + dy, x + dx
            if 0 <= yy_ < H and 0 <= xx_ < W:
                yield yy_, xx_
    ts = 0
    for _ in range(lakes * 12):
        if ts >= lakes: break
        x, y = rnd.randrange(8, W - 8), rnd.randrange(8, H - 8)
        if water[y, x] or eh[y, x] < 0.05 or biome[y, x] in (ix["mountain"], ix["peak"], ix["desert"]): continue
        win = eh[y - 6:y + 7, x - 6:x + 7]
        if eh[y, x] > win.min() + 0.01: continue
        level = eh[y, x] + 0.025 + rnd.random() * 0.02
        stack, seen = [(y, x)], {(y, x)}
        while stack and len(seen) < 140:
            cy, cx = stack.pop()
            for ny, nx in nb4(cy, cx):
                if (ny, nx) not in seen and eh[ny, nx] <= level and not water[ny, nx]:
                    seen.add((ny, nx)); stack.append((ny, nx))
        if len(seen) < 12: continue
        for (cy, cx) in seen:
            biome[cy, cx] = ix["lake"]; water[cy, cx] = True
        ts += 1

    # --- fiumi: discesa lungo il gradiente dalle zone alte ---
    elev_c = e.copy()
    cand = [(y, x) for y in range(2, H - 2, 3) for x in range(2, W - 2, 3) if eh[y, x] > 0.30 * top and not water[y, x]]
    rnd.shuffle(cand)
    nriv = 0
    for (sy, sx) in cand:
        if nriv >= rivers: break
        y, x = sy, sx; path = [(y, x)]; seen = {(y, x)}
        for _ in range(W * 3):
            if water[y, x] and len(path) > 3: break
            best = None; bv = 9
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in seen:
                    v = elev_c[ny, nx] + rnd.random() * 0.004 + (0.002 if dy and dx else 0)
                    if v < bv: bv, best = v, (ny, nx)
            if best is None: break
            if bv > elev_c[y, x]: elev_c[y, x] = bv - 0.002          # riempie le buche: il fiume prosegue
            y, x = best; path.append(best); seen.add(best)
        reached = water[y, x]
        if len(path) < 25 or not reached: continue
        nriv += 1
        for i, (py, px) in enumerate(path):
            if biome[py, px] in (ix["ocean"], ix["sea"]): break
            biome[py, px] = ix["river"]; water[py, px] = True
            if i > len(path) * 0.78 and i % 2 == 0:               # allarga verso la foce
                for ny, nx in nb4(py, px):
                    if biome[ny, nx] not in (ix["ocean"], ix["sea"], ix["mountain"], ix["peak"]):
                        biome[ny, nx] = ix["river"]; water[ny, nx] = True

    # --- rive: sabbia attorno ad acqua dolce, fango in zone umide ---
    ground = np.array([[LEVEL[BIOME_GROUND[names[biome[y, x]]]] for x in range(W)] for y in range(H)])
    sand, mud = LEVEL["sand"], LEVEL["mud"]
    for y in range(H):
        for x in range(W):
            if not water[y, x] and ground[y, x] > sand and biome[y, x] not in (ix["mountain"], ix["peak"]):
                if any(water[ny, nx] for ny, nx in nb4(y, x)):
                    ground[y, x] = sand if m[y, x] < 0.62 or rnd.random() < 0.3 else mud
    # macchie di terra e sassi nelle colline
    dm = fbm(W, H, 6, 2, seed + 9)
    for y in range(H):
        for x in range(W):
            if biome[y, x] == ix["hills"] and dm[y, x] > 0.68: ground[y, x] = LEVEL["dirt"]
            if biome[y, x] == ix["plains"] and dm[y, x] > 0.8: ground[y, x] = LEVEL["dry_grass"]
            if biome[y, x] == ix["plains"] and dm[y, x] < 0.12: ground[y, x] = LEVEL["forest"]

    w = World(W, H, seed, ground, biome, eh, names, water_mask=water)

    # --- insediamenti ---
    sites = []
    tries = 0
    while len(sites) < settlements and tries < 4000:
        tries += 1
        x, y = rnd.randrange(10, W - 10), rnd.randrange(10, H - 10)
        if names[biome[y, x]] not in ("plains", "forest", "savanna", "taiga", "hills"): continue
        win = water[y - 4:y + 5, x - 4:x + 5]
        if win.sum() > 10 or np.ptp(eh[y - 3:y + 4, x - 3:x + 4]) > 0.12: continue
        if any((x - sx) ** 2 + (y - sy) ** 2 < 18 ** 2 for sx, sy, _ in sites): continue
        sites.append((x, y, rnd.choice(["village", "village", "town", "camp", "ruins"])))
    for i, (x, y, kind) in enumerate(sites):
        for yy_ in range(y - 3, y + 4):
            for xx_ in range(x - 3, x + 4):
                if (xx_ - x) ** 2 + (yy_ - y) ** 2 <= 10 and not water[yy_, xx_]:
                    ground[yy_, xx_] = LEVEL["dirt"] if kind != "ruins" else LEVEL["stone"]
        w.settlements.append({"id": f"s{i}", "kind": kind, "x": x, "y": y,
                              "npcs": _npcs(kind, rnd), "name_seed": rnd.randrange(10 ** 6)})

    # --- strade (A*) tra insediamenti vicini ---
    def astar(a, b):
        cost = lambda y, x: 1 + (30 if water[y, x] else 0) + eh[y, x] * 6 + (14 if biome[y, x] in (ix["mountain"], ix["peak"]) else 0)
        pq = [(0, a)]; came = {a: None}; g = {a: 0}
        while pq:
            _, cur = heapq.heappop(pq)
            if cur == b: break
            for ny, nx in nb4(*cur[::-1]) if False else [(cur[1] + dy, cur[0] + dx) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]:
                if not (0 <= ny < H and 0 <= nx < W): continue
                n = (nx, ny)
                ng = g[cur] + cost(ny, nx)
                if n not in g or ng < g[n]:
                    g[n] = ng; came[n] = cur
                    heapq.heappush(pq, (ng + abs(nx - b[0]) + abs(ny - b[1]), n))
        p = []; c = b
        while c is not None: p.append(c); c = came.get(c)
        return p[::-1]
    pts = [(s["x"], s["y"]) for s in w.settlements]
    linked = set()
    for i, a in enumerate(pts):
        order = sorted(range(len(pts)), key=lambda j: (pts[j][0] - a[0]) ** 2 + (pts[j][1] - a[1]) ** 2)[1:3]
        for j in order:
            k = tuple(sorted((i, j)))
            if k in linked: continue
            linked.add(k)
            p = astar(a, pts[j])
            w.roads.append(p)
            for (x, y) in p:
                if water[y, x]:
                    w.objects.append({"type": "bridge", "x": x + .5, "y": y + .5, "variant": 0})
                elif ground[y, x] not in (LEVEL["stone"], LEVEL["snow"]):
                    ground[y, x] = LEVEL["path"]
    _place_objects(w, rnd, ix, m, forest_density)
    _place_spawns(w, rnd, ix)
    return w


def _npcs(kind, rnd):
    roles = {"village": ["elder", "merchant", "blacksmith", "farmer", "child", "guard"],
             "town": ["merchant", "blacksmith", "guard", "guard", "innkeeper", "priest", "noble", "child"],
             "camp": ["hunter", "wanderer", "merchant"], "ruins": ["hermit", "scholar"]}[kind]
    return [{"role": r, "hair": rnd.choice(["hair_brown", "hair_black", "hair_blond", "hair_red", "hair_white"]),
             "skin": rnd.choice(["skin_light", "skin_tan", "skin_dark", "skin_pale"]),
             "top": rnd.choice(["cloth_red", "cloth_green", "cloth_blue", "cloth_cream", "cloth_orange", "cloth_purple"])}
            for r in rnd.sample(roles, min(len(roles), rnd.randint(3, 5)))]


TREES = {  # bioma: [(tipo, materiale foglia, peso)]
    "forest": [("oak", "leaf", 5), ("oak", "leaf_dark", 3), ("birch", "leaf_light", 2), ("pine", "leaf_dark", 1)],
    "taiga": [("pine", "leaf_dark", 6), ("pine", "snow", 3), ("birch", "leaf_light", 1)],
    "plains": [("oak", "leaf_light", 2), ("birch", "leaf_light", 1)],
    "savanna": [("palm", "leaf_light", 1), ("dead", "leaf", 1), ("oak", "leaf_autumn", 1)],
    "swamp": [("dead", "leaf", 3), ("mushroom", "leaf", 2), ("oak", "leaf_dark", 1)],
    "desert": [("palm", "leaf_light", 1)],
    "hills": [("pine", "leaf_dark", 2), ("oak", "leaf", 1)],
    "tundra": [("pine", "snow", 1), ("dead", "leaf", 1)],
    "beach": [("palm", "leaf_light", 1)],
}
DENS = {"forest": 0.30, "taiga": 0.26, "plains": 0.025, "savanna": 0.03, "swamp": 0.10, "desert": 0.012, "hills": 0.07,
        "tundra": 0.03, "beach": 0.015}


def _place_objects(w, rnd, ix, m, density):
    H, W = w.H, w.W
    near_set = {(s["x"], s["y"]) for s in w.settlements}
    road = set(p for r in w.roads for p in r)
    clump = fbm(W, H, 5, 2, w.seed + 77)
    for y in range(H):
        for x in range(W):
            if w.water_mask[y, x] or (x, y) in road or w.ground[y, x] in (LEVEL["path"],):
                continue
            if any((x - sx) ** 2 + (y - sy) ** 2 < 14 for sx, sy in near_set):
                continue
            b = w.biome_names[w.biome[y, x]]
            if w.ground[y, x] == LEVEL["dirt"] and b not in ("hills",): continue
            p = DENS.get(b, 0) * density * (0.4 + 1.6 * clump[y, x])
            if rnd.random() < p and b in TREES:
                opts = TREES[b]
                tot = sum(o[2] for o in opts); r = rnd.random() * tot
                for kind, leaf, wt in opts:
                    r -= wt
                    if r <= 0: break
                w.objects.append({"type": "tree", "kind": kind, "leaf": leaf, "x": x + rnd.uniform(.2, .8), "y": y + rnd.uniform(.3, .9),
                                  "seed": rnd.randrange(6), "size": rnd.choice([0.9, 1.0, 1.1])})
            elif b in ("plains", "forest", "hills", "savanna", "taiga", "swamp") and rnd.random() < 0.045:
                w.objects.append({"type": "bush", "x": x + .5, "y": y + .7, "seed": rnd.randrange(6),
                                  "berries": rnd.choice([None, None, "gem_red", "gem_blue"]),
                                  "mat": "leaf_autumn" if b == "savanna" else "leaf"})
            elif b in ("mountain", "peak", "hills", "desert", "tundra", "badlands") and rnd.random() < 0.07:
                w.objects.append({"type": "rock", "x": x + .5, "y": y + .7, "seed": rnd.randrange(6),
                                  "mat": "stone_light" if b != "desert" else "sand", "moss": b in ("hills",)})
    w.objects.sort(key=lambda o: o["y"])


SPAWNS = {  # bioma: [(specie, tipo, peso, livello_base)]
    "plains": [("rabbit", "animal", 5, 1), ("deer", "animal", 3, 1), ("slime_green", "monster", 3, 1), ("wolf", "monster", 1, 3)],
    "forest": [("wolf", "monster", 4, 2), ("deer", "animal", 3, 1), ("slime_green", "monster", 2, 1), ("bear", "monster", 1, 5)],
    "taiga": [("wolf_white", "monster", 4, 3), ("deer", "animal", 2, 1), ("bear", "monster", 1, 6)],
    "tundra": [("wolf_white", "monster", 3, 4), ("slime_blue", "monster", 3, 3)],
    "swamp": [("slime_purple", "monster", 4, 3), ("slime_green", "monster", 3, 2)],
    "desert": [("slime_red", "monster", 3, 4), ("scorpion", "monster", 2, 4)],
    "savanna": [("deer", "animal", 3, 1), ("lion", "monster", 1, 5), ("rabbit", "animal", 3, 1)],
    "hills": [("wolf", "monster", 3, 3), ("goat", "animal", 3, 1)],
    "mountain": [("goat", "animal", 2, 2), ("slime_blue", "monster", 2, 5), ("golem", "monster", 1, 8)],
    "peak": [("golem", "monster", 1, 10)],
}


def _place_spawns(w, rnd, ix):
    cx, cy = w.W / 2, w.H / 2
    step = 6
    for y in range(0, w.H, step):
        for x in range(0, w.W, step):
            xx, yy = x + rnd.randrange(step), y + rnd.randrange(step)
            if xx >= w.W or yy >= w.H or w.water_mask[yy, xx]: continue
            b = w.biome_names[w.biome[yy, xx]]
            if b not in SPAWNS or rnd.random() < 0.35: continue
            opts = SPAWNS[b]; tot = sum(o[2] for o in opts); r = rnd.random() * tot
            for sp, kind, wt, lv in opts:
                r -= wt
                if r <= 0: break
            dist = min(math.hypot(xx - s["x"], yy - s["y"]) for s in w.settlements) if w.settlements else 0
            w.spawns.append({"species": sp, "kind": kind, "x": xx + .5, "y": yy + .5, "level": lv + int(dist // 25),
                             "group": rnd.randint(1, 3) if kind == "animal" or "slime" in sp else 1, "biome": b})
