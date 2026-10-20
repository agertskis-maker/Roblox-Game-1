---
title: "0010: vehicle direction: original parody vehicles in a shaped low-poly style"
date: 2026-10-20
tags:
  - decision
  - visual
  - vehicles
status: accepted
---

# 0010: vehicle direction: original parody vehicles in a shaped low-poly style

## Decision (approved by Adam, Lane 3 owner, 2026-10-20)
- **Approved:** replace the old chunky toy-car direction with "original fictional/parody vehicles inspired by real automotive categories, eras, and proportions", using a simplified low-poly presentation. The world stays bright and stylized; the approved HUD is unchanged. Vehicles are modelled as meshes in Blender with the free-tool pipeline, starting with one car.
- **Approved quality bar (Adam's revision brief, 2026-10-20):** cars are polished, stylized low-poly automobiles with believable proportions and shaped surfaces, not stacked boxes; every car, including the cheapest Common, must look intentionally shaped and desirable. The first concept (Pando) was rejected as too blocky.
- **Guardrails** (verbatim from Adam's brief):
  1. No real logos, badges, emblems, manufacturer wordmarks or brand fonts anywhere, including on grilles, wheels, plates and decals.
  2. No real model or brand name used unchanged. Every name has a visible parody twist.
  3. Shapes are inspired by the real car (proportions, era, overall vibe), not exact copies of signature grilles, headlight shapes or body lines.
  4. No names that mock a brand in a mean or adult way, and nothing unsuitable for children.
  5. No police, military or emergency-service vehicles or liveries.
- **Project rule:** `AGENTS.md`, "Visual references and UI styling", gains a **Vehicles** bullet carrying these guardrails. Adam approved the proposed wording as written, plus the sentence "A parody name with a visible twist, as defined in rule 2, is not a copied name under the rules above." The general rules against copying logos, characters, item art, icons, fonts, names and distinctive screens are unchanged.
- **Taxi signs:** ignored completely unless a taxi is explicitly requested later.

## Not established by this decision
- Parody naming and the removal of logos do not establish permission and do not remove intellectual-property risk. That risk is not limited to trademarks or trade dress; copyright or design rights can also apply. No legal clearance is established by this decision, and a commercial release needs a separate review.
- The naming permission does not allow copying badges, logos, exact bodywork or a distinctive vehicle design unchanged.
- No roster, car name, silhouette, rarity tier or economy value is approved by this note. The 24-car roster and the five-tier rarity guide are proposals, recorded in `vault/design/vehicles/rarity-style.md` once drafted, until Adam approves them; economy values also need Brian L (Lane 2).

## Superseded
- The Pip direction approved on 2026-10-19 (a chunky toy hatchback with a cream roof, wheels about 1.3 times realistic, built from parts) is superseded for future vehicles. Its approval record stays in [[visual-direction]] as history and does not approve the revised first car or its name.
- Outline v2.2 section 07 "Car construction standard" (rounded block bodies, oversized wheels, 20 to 40 parts) and section 13 "chunky block cartoon" cars are superseded for vehicles; UI and World styling are unchanged.

## Why
Adam wants cars that look like appealing, simplified real vehicles that players enjoy driving, including the Common starter, rather than toy bricks. Real categories and eras make the cars recognizable to players; parody names and original styling keep them our own.

## Consequences
- Rig, scale and running-gear conventions for vehicles stay provisional until Brian R (Lane 1) agrees; Catalog and economy fields stay with Brian L (Lane 2).
- Source recipes live in `assets/vehicles/<car-id>/` (text only); binary art stays outside Git in `C:\Users\agert\Documents\Car-Hop-Art\` (Adam, 2026-10-20).
