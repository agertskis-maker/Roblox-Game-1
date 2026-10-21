# Island kit: park and lake props (Lane 3), in the vegetation's smooth faceted language: chamfered
# boards, rounded rims, low side counts, no studs. Sizes follow the approved layout (HubData.park):
# fountain basin radius 12, gazebo 16 x 16 x 12, food stand strip 32 x 12 x 8, bridges 16 span
# with 18, 12 and 10 decks. Ground line at y 0. Glowing or transparent pieces (lamp glass,
# fountain water) are separate meshes so the placement can give them their own material.
# Food stands are decorative only: no prices, counters with goods, or anything that reads as a
# working shop. Sign boards are blank shapes; their designed content follows the Figma workflow.

import math
import random

from mathutils import Vector

from kitlib import Builder, box, clump, disc, ring, rock, tube


def seed_of(name):
    return sum(map(ord, name)) * 13 + len(name)


def cyl(b, base, height, radius, sides, swatch, top=True, bottom=False, r_top=None):
    rt = radius if r_top is None else r_top
    rings = tube(b, [base, base + Vector((0, 0, height))], [radius, rt], sides, [swatch], cap=False)
    if top:
        c = base + Vector((0, 0, height))
        t = rings[-1]
        for k in range(sides):
            b.tri(t[k], t[(k + 1) % sides], c, swatch)
    if bottom:
        t = rings[0]
        for k in range(sides):
            b.tri(t[(k + 1) % sides], t[k], base, swatch)
    return rings


def bowl(b, centre, radius, depth, rim, sides, swatch, inner_swatch):
    """A round basin: outer wall, rounded rim, inner wall and floor."""
    outer_top = ring(centre + Vector((0, 0, depth)), Vector((0, 0, 1)), radius, sides)
    outer_bot = ring(centre, Vector((0, 0, 1)), radius * 0.92, sides)
    inner_top = ring(centre + Vector((0, 0, depth)), Vector((0, 0, 1)), radius - rim, sides)
    inner_bot = ring(centre + Vector((0, 0, rim)), Vector((0, 0, 1)), (radius - rim) * 0.95, sides)
    lip = ring(centre + Vector((0, 0, depth + rim * 0.35)), Vector((0, 0, 1)), radius - rim * 0.5, sides)
    for k in range(sides):
        k2 = (k + 1) % sides
        b.quad(outer_bot[k], outer_bot[k2], outer_top[k2], outer_top[k], swatch)
        b.quad(outer_top[k], outer_top[k2], lip[k2], lip[k], swatch)
        b.quad(lip[k], lip[k2], inner_top[k2], inner_top[k], swatch)
        b.quad(inner_top[k], inner_top[k2], inner_bot[k2], inner_bot[k], inner_swatch)
        b.tri(inner_bot[k], inner_bot[k2], centre + Vector((0, 0, rim)), inner_swatch)


def planks(b, origin, length, width, count, gap, swatches, thick=0.35, along=Vector((1, 0, 0)), arch=0.0, rng=None):
    """Deck boards across `width`, laid along `along`, following an optional arch height."""
    step = length / count
    side = Vector((-along.y, along.x, 0))
    for i in range(count):
        t = (i + 0.5) / count - 0.5
        z = arch * (1 - (2 * t) ** 2)
        c = origin + along * (t * length) + Vector((0, 0, z))
        rot = math.atan2(along.y, along.x)
        sw = swatches[i % len(swatches)]
        box(b, c, Vector((step - gap, width * (1 + (rng.uniform(-0.02, 0.02) if rng else 0)), thick)), sw, rot)


# ---------------------------------------------------------------- rocks
def boulder(name, size, sub=2):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    rock(b, Vector((0, 0, size.z * 0.35)), size, rng, ["rock", "rock", "rock_dark"], subdiv=sub)
    if size.x > 3:
        rock(b, Vector((size.x * 0.7, size.y * 0.2, size.z * 0.05)), size * 0.45, rng, ["rock", "rock_dark", "rock"], subdiv=1)
    return b, {"height": size.z * 1.35, "sink": size.z * 0.65}


# ---------------------------------------------------------------- lake scenery
def dock(name, length, width):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # deck at 1.4 above the water line, running out along +x from the shore end at x 0
    deck_z = 1.4
    planks(b, Vector((length / 2, 0, deck_z)), length, width, int(length / 1.1), 0.12, ["plank", "plank", "plank_dark"], rng=rng)
    for x in (0.4, length * 0.5, length - 0.4):
        for y in (-width / 2 + 0.3, width / 2 - 0.3):
            cyl(b, Vector((x, y, -4)), deck_z + 4 + (1.6 if x > length - 1 else 0), 0.32, 6, "plank_dark")
    # stringers under the boards and a mooring cleat
    for y in (-width / 2 + 0.3, width / 2 - 0.3):
        box(b, Vector((length / 2, y, deck_z - 0.35)), Vector((length, 0.35, 0.4)), "plank_dark")
    box(b, Vector((length - 1.2, width / 2 - 0.5, deck_z + 0.3)), Vector((0.8, 0.25, 0.25)), "metal")
    return b, {"height": deck_z + 1.6, "length": length, "deck": deck_z}


def rowboat(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # a hull from rings along x, pointed bow (+x), flat-ish stern; water line at y 0
    L = 9.0
    n = 7
    prev = None
    rings = []
    for i in range(n + 1):
        t = i / n
        x = -L / 2 + L * t
        w = 1.8 * math.sin(math.pi * min(0.97, 0.18 + 0.82 * t)) if t < 1 else 0.05
        if t < 0.1:
            w = 1.5
        rise = 0.25 * (2 * t - 1) ** 2
        rim_z = 1.1 + rise
        pts = [
            Vector((x, -w, rim_z)),
            Vector((x, -w * 0.85, 0.2)),
            Vector((x, -w * 0.35, -0.35)),
            Vector((x, w * 0.35, -0.35)),
            Vector((x, w * 0.85, 0.2)),
            Vector((x, w, rim_z)),
        ]
        rings.append(pts)
    for i in range(n):
        a, c = rings[i], rings[i + 1]
        for k in range(5):
            sw = "cart_white" if k in (0, 4) else "plank"
            b.quad(a[k], c[k], c[k + 1], a[k + 1], sw)
            # inside of the hull
            b.quad(a[k + 1] + Vector((0, 0, 0.02)), c[k + 1] + Vector((0, 0, 0.02)), c[k] + Vector((0, 0, 0.02)), a[k] + Vector((0, 0, 0.02)), "plank_dark")
    # the transom
    s = rings[0]
    for k in range(1, 5):
        b.tri(s[0], s[k + 1], s[k], "plank")
    # seats and oars
    for x in (-1.8, 1.0):
        box(b, Vector((x, 0, 0.55)), Vector((0.9, 2.9, 0.18)), "plank")
    for sgn in (-1, 1):
        tube(b, [Vector((-0.6, sgn * 1.2, 0.9)), Vector((2.6, sgn * 1.5, 0.75))], [0.08, 0.08], 4, ["plank_dark"])
        box(b, Vector((3.1, sgn * 1.55, 0.72)), Vector((1.1, 0.06, 0.4)), "plank_dark")
    # the mooring rope coiled at the bow
    tube(b, [Vector((4.3, 0, 1.2)), Vector((5.4, 0.2, 0.9)), Vector((6.6, 0.5, 1.5))], [0.07, 0.07, 0.07], 4, ["rope"])
    return b, {"height": 1.6, "length": L}


# ---------------------------------------------------------------- park furniture
def bench(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    L = 6.0
    for y in (-0.35, 0.05, 0.45):
        box(b, Vector((0, y, 1.5)), Vector((L, 0.34, 0.16)), "bench_wood")
    # backrest slats, leaning back
    for z in (2.05, 2.5):
        box(b, Vector((0, 0.72 + (z - 2.05) * 0.12, z)), Vector((L, 0.12, 0.36)), "bench_wood")
    for x in (-L / 2 + 0.6, L / 2 - 0.6):
        # cast frame: leg, seat bearer, arm and back upright
        box(b, Vector((x, -0.4, 0.72)), Vector((0.2, 0.2, 1.5)), "metal")
        box(b, Vector((x, 0.55, 0.72)), Vector((0.2, 0.2, 1.5)), "metal")
        box(b, Vector((x, 0.07, 1.38)), Vector((0.22, 1.35, 0.16)), "metal")
        box(b, Vector((x, 0.82, 2.05)), Vector((0.2, 0.16, 1.5)), "metal")
        box(b, Vector((x, 0.1, 1.95)), Vector((0.22, 1.4, 0.14)), "metal")
    return b, {"height": 2.8, "length": L, "seat": 1.6}


def lamp_post(name):
    b = Builder(name)
    cyl(b, Vector((0, 0, -0.6)), 1.4, 0.75, 8, "metal", r_top=0.55)
    cyl(b, Vector((0, 0, 0.8)), 8.4, 0.22, 8, "metal", r_top=0.17)
    for k in range(4):
        a = math.pi / 2 * k
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(b, [Vector((0, 0, 8.2)) + d * 0.15, Vector((0, 0, 8.9)) + d * 0.55], [0.06, 0.06], 4, ["metal"])
    # lantern housing: base plate, four corner posts and a peaked cap (the glass is LampGlass)
    cyl(b, Vector((0, 0, 9.0)), 0.18, 0.55, 8, "metal")
    for k in range(4):
        a = math.pi / 4 + math.pi / 2 * k
        p = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 9.1))
        box(b, p + Vector((0, 0, 0.6)), Vector((0.08, 0.08, 1.2)), "metal")
    cyl(b, Vector((0, 0, 10.3)), 0.12, 0.75, 8, "metal")
    cyl(b, Vector((0, 0, 10.42)), 0.55, 0.7, 8, "metal", r_top=0.05)
    return b, {"height": 11.0, "light": 9.7}


def lamp_glass(name):
    b = Builder(name)
    cyl(b, Vector((0, 0, 9.18)), 1.1, 0.44, 8, "lamp_glass", bottom=True, r_top=0.48)
    return b, {"height": 10.3}


def food_cart(name, body_sw, awning_a, awning_b, kind):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    L, W = 6.0, 3.2
    # body on a chassis, rounded front, wheels and a push handle
    box(b, Vector((0, 0, 2.0)), Vector((L, W, 2.4)), body_sw)
    box(b, Vector((0, 0, 3.3)), Vector((L + 0.3, W + 0.3, 0.2)), "cart_white")
    box(b, Vector((0, 0, 0.75)), Vector((L - 0.4, W - 0.4, 0.3)), "metal")
    for x in (-L / 2 + 1.1, L / 2 - 1.1):
        for y in (-W / 2 - 0.05, W / 2 + 0.05):
            disc(b, Vector((x, y, 0.85)), 0.85, 10, "black", normal=Vector((0, 1 if y > 0 else -1, 0)), thickness=0.25)
            disc(b, Vector((x, y + (0.02 if y > 0 else -0.02), 0.85)), 0.35, 8, "cart_white", normal=Vector((0, 1 if y > 0 else -1, 0)))
    tube(b, [Vector((-L / 2, -1, 2.6)), Vector((-L / 2 - 1.2, -1, 2.9)), Vector((-L / 2 - 1.2, 1, 2.9)), Vector((-L / 2, 1, 2.6))], [0.08] * 4, 4, ["metal"])
    # canopy on four poles: a scalloped striped awning
    for x in (-L / 2 + 0.25, L / 2 - 0.25):
        for y in (-W / 2 + 0.25, W / 2 - 0.25):
            cyl(b, Vector((x, y, 3.4)), 3.2, 0.08, 4, "metal")
    stripes = 8
    for i in range(stripes):
        x0 = -L / 2 - 0.4 + (L + 0.8) * i / stripes
        x1 = -L / 2 - 0.4 + (L + 0.8) * (i + 1) / stripes
        sw = awning_a if i % 2 == 0 else awning_b
        apex_z, eave_z = 7.6, 6.6
        b.face2([Vector((x0, -W / 2 - 0.5, eave_z)), Vector((x1, -W / 2 - 0.5, eave_z)), Vector((x1, 0, apex_z)), Vector((x0, 0, apex_z))], sw)
        b.face2([Vector((x0, 0, apex_z)), Vector((x1, 0, apex_z)), Vector((x1, W / 2 + 0.5, eave_z)), Vector((x0, W / 2 + 0.5, eave_z))], sw)
        xm = (x0 + x1) / 2
        for y in (-W / 2 - 0.5, W / 2 + 0.5):
            b.face2([Vector((x0, y, eave_z)), Vector((x1, y, eave_z)), Vector((xm, y, eave_z - 0.45))], sw)
    # the shape that says what it is: a product sculpture on top
    top = Vector((0, 0, 7.6))
    if kind == "hotdog":
        tube(b, [top + Vector((-1.4, 0, 0.5)), top + Vector((0, 0, 0.7)), top + Vector((1.4, 0, 0.5))], [0.42, 0.5, 0.42], 8, ["fruit_orange"])
        tube(b, [top + Vector((-1.7, 0, 0.55)), top + Vector((0, 0, 0.75)), top + Vector((1.7, 0, 0.55))], [0.25, 0.3, 0.25], 6, ["cart_red"])
    elif kind == "popcorn":
        tube(b, [top + Vector((0, 0, 0.2)), top + Vector((0, 0, 1.6))], [0.55, 0.85], 8, ["popcorn_red", "cart_white"], cap=False)
        for _ in range(9):
            clump(b, top + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1.8 + rng.uniform(0, 0.4))), Vector((0.32, 0.32, 0.28)), rng, ["cart_white", "lemon"], subdiv=1)
    return b, {"height": 9.0 if kind else 7.6, "length": L}


def stand(name, kind):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    L, W = 6.0, 4.0
    # a little booth: body, front with a closed hatch, roof
    body_sw = "icecream_pink" if kind == "icecream" else "lemon"
    box(b, Vector((0, 0, 1.9)), Vector((L, W, 3.8)), body_sw)
    box(b, Vector((0, -W / 2 - 0.05, 3.0)), Vector((L - 1.2, 0.15, 1.3)), "cart_white")
    box(b, Vector((0, -W / 2 - 0.4, 2.1)), Vector((L - 0.6, 0.9, 0.2)), "bench_wood")
    for x in (-L / 2, L / 2):
        for y in (-W / 2, W / 2):
            box(b, Vector((x, y, 2.4)), Vector((0.3, 0.3, 4.8)), "cart_white")
    # a rounded scalloped roof
    roof = 6.4
    for i in range(6):
        x0 = -L / 2 - 0.5 + (L + 1.0) * i / 6
        x1 = -L / 2 - 0.5 + (L + 1.0) * (i + 1) / 6
        sw = "cart_white" if i % 2 else ("blossom" if kind == "icecream" else "awning_yellow")
        b.face2([Vector((x0, -W / 2 - 0.9, 4.9)), Vector((x1, -W / 2 - 0.9, 4.9)), Vector((x1, 0, roof)), Vector((x0, 0, roof))], sw)
        b.face2([Vector((x0, 0, roof)), Vector((x1, 0, roof)), Vector((x1, W / 2 + 0.6, 4.9)), Vector((x0, W / 2 + 0.6, 4.9))], sw)
        b.face2([Vector((x0, -W / 2 - 0.9, 4.9)), Vector((x1, -W / 2 - 0.9, 4.9)), Vector(((x0 + x1) / 2, -W / 2 - 0.9, 4.4))], sw)
    top = Vector((0, 0, roof))
    if kind == "icecream":
        tube(b, [top + Vector((0, 0, 0.1)), top + Vector((0, 0, 1.4))], [0.12, 0.6], 8, ["fruit_orange", "straw"], cap=False)
        clump(b, top + Vector((0, 0, 1.7)), Vector((0.7, 0.7, 0.6)), rng, ["icecream_pink", "blossom_pale"], subdiv=1)
        clump(b, top + Vector((0, 0, 2.3)), Vector((0.5, 0.5, 0.45)), rng, ["cart_white", "blossom_white"], subdiv=1)
    else:
        clump(b, top + Vector((0, 0, 1.0)), Vector((1.0, 1.0, 0.85)), rng, ["lemon", "fruit_yellow"], flatten=0.85, subdiv=1)
        clump(b, top + Vector((0.6, 0.3, 1.6)), Vector((0.35, 0.18, 0.2)), rng, ["leaf_mid"], subdiv=1)
    return b, {"height": roof + 2.6, "length": L}


def fountain(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # three stepped tiers in the basin (radius 12). The fountain stands in two viewing corridors,
    # where nothing solid may be taller than 3, so the stone stays low and wide and the water
    # jets (effects, see-through) give it height: a pool wall, a raised ring basin, a top bowl.
    bowl(b, Vector((0, 0, 0)), 12.0, 1.3, 0.9, 28, "stone_light", "rock")
    cyl(b, Vector((0, 0, 0.2)), 1.0, 6.0, 18, "stone_light", r_top=5.6)
    bowl(b, Vector((0, 0, 1.2)), 6.2, 0.6, 0.55, 20, "stone_light", "rock")
    cyl(b, Vector((0, 0, 1.5)), 0.7, 1.4, 10, "stone_light", r_top=1.1)
    bowl(b, Vector((0, 0, 2.2)), 2.6, 0.45, 0.35, 14, "stone_light", "rock")
    clump(b, Vector((0, 0, 2.62)), Vector((0.32, 0.32, 0.3)), rng, ["stone_light", "cart_white"], subdiv=1)
    return b, {"height": 2.95, "radius": 12.0, "pool": 0.95, "tier2": 1.2 + 0.45, "tier3": 2.2 + 0.32, "jet": 2.7}


def fountain_water(name):
    """The water surfaces of the fountain's three tiers and the overflow sheets between them."""
    b = Builder(name)
    for z, r in ((1.05, 10.95), (1.68, 5.55), (2.52, 2.2)):
        disc(b, Vector((0, 0, z)), r, 24 if r > 5 else 16, "fountain_water")
    # overflow curtains from the two upper bowls (open cylinders, two-sided)
    for z_top, z_bot, r in ((2.6, 1.7, 2.65), (1.8, 1.05, 6.25)):
        n = 18
        top = ring(Vector((0, 0, z_top)), Vector((0, 0, 1)), r, n)
        bot = ring(Vector((0, 0, z_bot)), Vector((0, 0, 1)), r * 1.12, n)
        for k in range(n):
            k2 = (k + 1) % n
            b.face2([top[k], top[k2], bot[k2], bot[k]], "fountain_water")
    return b, {"height": 2.7}


def hedge(name, length, height, depth):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    n = max(2, int(length / 2.2))
    for i in range(n):
        x = -length / 2 + length * (i + 0.5) / n
        clump(b, Vector((x, 0, height * 0.55)), Vector((length / n * 0.85, depth * 0.62, height * 0.6)), rng, ["hedge_dark", "hedge", "hedge", "leaf_mid"], flatten=1.0, subdiv=2)
    box(b, Vector((0, 0, height * 0.35)), Vector((length * 0.96, depth * 0.85, height * 0.7)), ["hedge_dark", "hedge"])
    return b, {"height": height, "length": length}


def topiary(name, shape):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    cyl(b, Vector((0, 0, -0.3)), 1.1, 1.6, 8, "plank", r_top=1.7)
    if shape == "ball":
        cyl(b, Vector((0, 0, 0.8)), 1.6, 0.18, 5, "bark_warm")
        clump(b, Vector((0, 0, 3.6)), Vector((1.9, 1.9, 1.9)), rng, ["hedge_dark", "hedge", "leaf_mid"], subdiv=2)
    else:
        tube(b, [Vector((0, 0, 0.8)), Vector((0, 0, 3.0)), Vector((0, 0, 5.6)), Vector((0, 0, 6.6))], [1.5, 1.3, 0.6, 0.05], 10, ["hedge_dark", "hedge", "leaf_mid"], rng=rng, jitter=0.06)
    return b, {"height": 6.6 if shape != "ball" else 5.5}


def car_topiary(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # a raised bed with a clipped-hedge car on it: body, cabin, wheels and headlamp flowers
    box(b, Vector((0, 0, 0.35)), Vector((12, 6.5, 1.1)), ["stone_light", "stone_light", "plank"])
    box(b, Vector((0, 0, 0.92)), Vector((11.4, 5.9, 0.1)), "dirt")
    hedge_sw = ["hedge_dark", "hedge", "hedge", "leaf_mid"]
    for x, s in ((-2.8, Vector((2.6, 2.5, 1.2))), (0, Vector((2.9, 2.5, 1.3))), (2.8, Vector((2.6, 2.4, 1.15)))):
        clump(b, Vector((x, 0, 2.6)), s, rng, hedge_sw, flatten=1.0, subdiv=2)
    clump(b, Vector((-0.4, 0, 4.0)), Vector((2.3, 2.0, 1.1)), rng, hedge_sw, flatten=1.0, subdiv=2)
    for x in (-3.0, 3.0):
        for y in (-2.25, 2.25):
            disc(b, Vector((x, y, 1.9)), 1.05, 10, "hedge_dark", normal=Vector((0, 1 if y > 0 else -1, 0)), thickness=0.6)
    for y in (-1.3, 1.3):
        clump(b, Vector((5.2, y, 2.7)), Vector((0.35, 0.35, 0.35)), rng, ["tulip_yellow"], subdiv=1)
    clump(b, Vector((-5.2, 0, 2.6)), Vector((0.3, 0.9, 0.3)), rng, ["tulip_red"], subdiv=1)
    return b, {"height": 5.2, "length": 12}


def signpost(name, boards):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    cyl(b, Vector((0, 0, -1.0)), 9.0, 0.32, 6, "plank_dark")
    clump(b, Vector((0, 0, 8.2)), Vector((0.42, 0.42, 0.42)), rng, ["plank"], subdiv=1)
    for i in range(boards):
        z = 7.0 - 1.35 * i
        a = (i * 1.9) % (2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        L, H = 4.2, 0.95
        c = d * (L / 2 - 0.1) + Vector((0, 0, z))
        # an arrow-shaped blank board (designed text goes on a SurfaceGui later, per the Figma spec)
        pts = [c - d * L / 2 + Vector((0, 0, H / 2)), c + d * (L / 2 - 0.6) + Vector((0, 0, H / 2)), c + d * L / 2, c + d * (L / 2 - 0.6) - Vector((0, 0, H / 2)), c - d * L / 2 - Vector((0, 0, H / 2))]
        front = [p - s * 0.12 for p in pts]
        back = [p + s * 0.12 for p in pts]
        b.face(front, "sign_board")
        b.face(list(reversed(back)), "sign_board")
        for k in range(len(pts)):
            k2 = (k + 1) % len(pts)
            b.quad(front[k2], front[k], back[k], back[k2], "plank")
    return b, {"height": 8.6, "boards": boards}


def bridge(name, span, deck):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # arched deck along x over a 16-stud stream crossing; abutments run into the banks
    L = span + 6
    arch = 0.3
    planks(b, Vector((0, 0, 0.35)), L, deck, int(L / 1.05), 0.1, ["plank", "plank", "plank_dark", "plank"], thick=0.35, arch=arch, rng=rng)
    # two curved stringers under the deck and stone abutments at the ends
    for y in (-deck / 2 + 0.6, deck / 2 - 0.6):
        path = [Vector((x, y, -0.15 + arch * (1 - (2 * x / L) ** 2))) for x in (-L / 2, -L / 4, 0, L / 4, L / 2)]
        tube(b, path, [0.35] * 5, 4, ["plank_dark"])
    for x in (-L / 2 + 1.2, L / 2 - 1.2):
        box(b, Vector((x, 0, -1.0)), Vector((2.4, deck + 1.2, 2.2)), ["stone_light", "rock"])
    # rails: posts with rounded caps and two curved rails per side
    posts = 7
    for y in (-deck / 2 + 0.25, deck / 2 - 0.25):
        tops = []
        for i in range(posts):
            x = -L / 2 + 0.6 + (L - 1.2) * i / (posts - 1)
            z = 0.5 + arch * (1 - (2 * x / L) ** 2)
            cyl(b, Vector((x, y, z - 0.2)), 2.15, 0.2, 6, "plank_dark")
            clump(b, Vector((x, y, z + 1.98)), Vector((0.24, 0.24, 0.14)), rng, ["plank"], subdiv=1)
            tops.append(Vector((x, y, z)))
        for h, r in ((1.8, 0.13), (1.0, 0.09)):
            tube(b, [t + Vector((0, 0, h)) for t in tops], [r] * posts, 5, ["plank"])
    return b, {"height": arch + 2.8, "span": span, "deck": deck, "length": L}


def fence(name, length):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for x in (-length / 2 + 0.2, length / 2 - 0.2):
        cyl(b, Vector((x, 0, -0.8)), 3.3, 0.2, 6, "cart_white")
        clump(b, Vector((x, 0, 2.6)), Vector((0.22, 0.22, 0.18)), rng, ["cart_white"], subdiv=1)
    for z in (0.9, 1.95):
        box(b, Vector((0, 0, z)), Vector((length, 0.14, 0.3)), "cart_white")
    for i in range(int(length / 0.9)):
        x = -length / 2 + 0.6 + i * 0.9
        if x < length / 2 - 0.5:
            box(b, Vector((x, 0.1, 1.1)), Vector((0.32, 0.1, 2.0)), "cart_white")
    return b, {"height": 2.8, "length": length}


def gazebo(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # an octagonal pavilion in the 16 x 16 x 12 footprint: platform, steps, posts, rail, roof
    R = 7.4
    sides = 8
    cyl(b, Vector((0, 0, -0.6)), 1.4, R, sides, "stone_light")
    planks(b, Vector((0, 0, 0.85)), 2 * R * 0.9, 2 * R * 0.78, 12, 0.08, ["plank", "plank_dark"], thick=0.14)
    for k in range(sides):
        a = 2 * math.pi * (k + 0.5) / sides
        p = Vector((math.cos(a) * (R - 0.6), math.sin(a) * (R - 0.6), 0.8))
        cyl(b, p, 7.4, 0.32, 6, "cart_white")
        if k != 0:
            a2 = 2 * math.pi * (k + 1.5) / sides
            q = Vector((math.cos(a2) * (R - 0.6), math.sin(a2) * (R - 0.6), 0.8))
            tube(b, [p + Vector((0, 0, 2.6)), q + Vector((0, 0, 2.6))], [0.12, 0.12], 4, ["cart_white"])
            # a little spandrel bracket under the eave
            tube(b, [p + Vector((0, 0, 6.4)), (p + q) / 2 + Vector((0, 0, 7.6)), q + Vector((0, 0, 6.4))], [0.1, 0.1, 0.1], 4, ["cart_white"])
    for i in range(3):
        box(b, Vector((R + 0.4 + i * 0.7, 0, 0.55 - i * 0.4)), Vector((0.8, 4.0, 0.4)), "stone_light")
    # the roof: eave ring, a flared octagonal cone in alternating colours, and a finial
    eave = ring(Vector((0, 0, 8.1)), Vector((0, 0, 1)), R + 0.9, sides, phase=math.pi / sides)
    mid = ring(Vector((0, 0, 9.6)), Vector((0, 0, 1)), R * 0.55, sides, phase=math.pi / sides)
    tip = Vector((0, 0, 11.4))
    for k in range(sides):
        k2 = (k + 1) % sides
        sw = "cart_red" if k % 2 else "cart_white"
        b.quad(eave[k], eave[k2], mid[k2], mid[k], sw)
        b.tri(mid[k], mid[k2], tip, sw)
        b.quad(eave[k2], eave[k], eave[k] - Vector((0, 0, 0.35)), eave[k2] - Vector((0, 0, 0.35)), "cart_white")
    clump(b, tip + Vector((0, 0, 0.3)), Vector((0.35, 0.35, 0.5)), rng, ["awning_yellow"], subdiv=1)
    return b, {"height": 11.9, "radius": R}


def build_all(emit):
    P = "props/"
    emit(*boulder("BoulderA", Vector((2.4, 2.0, 1.6))), P + "Rock")
    emit(*boulder("BoulderB", Vector((3.6, 2.8, 2.2))), P + "Rock")
    emit(*boulder("BoulderC", Vector((5.0, 3.6, 3.0))), P + "Rock")
    emit(*dock("Dock", 18, 5), P + "Lake")
    emit(*rowboat("Rowboat"), P + "Lake")
    emit(*bench("Bench"), P + "Park")
    emit(*lamp_post("LampPost"), P + "Park")
    emit(*lamp_glass("LampGlass"), P + "Park")
    emit(*food_cart("HotDogCart", "cart_red", "cart_red", "cart_white", "hotdog"), P + "Food")
    emit(*food_cart("PopcornCart", "popcorn_red", "popcorn_red", "awning_yellow", "popcorn"), P + "Food")
    emit(*stand("IceCreamStand", "icecream"), P + "Food")
    emit(*stand("LemonadeStand", "lemonade"), P + "Food")
    emit(*fountain("FountainTiered"), P + "Park")
    emit(*fountain_water("FountainWater"), P + "Park")
    emit(*hedge("HedgeStraight", 8, 2.6, 2.2), P + "Hedge")
    emit(*hedge("HedgeLow", 6, 1.6, 1.6), P + "Hedge")
    emit(*topiary("TopiaryBall", "ball"), P + "Hedge")
    emit(*topiary("TopiaryCone", "cone"), P + "Hedge")
    emit(*car_topiary("CarTopiary"), P + "Hedge")
    emit(*signpost("Signpost", 3), P + "Park")
    emit(*bridge("BridgeAvenue", 16, 18), P + "Bridge")
    emit(*bridge("BridgeLakeside", 16, 12), P + "Bridge")
    emit(*bridge("BridgeGarden", 16, 10), P + "Bridge")
    emit(*fence("FenceSegment", 8), P + "Park")
    emit(*gazebo("Gazebo"), P + "Park")
