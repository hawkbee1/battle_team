# Combat and Action Points (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers live in `data/combat.yaml` and `data/units.yaml`.

## 1. Action points (AP)
- Each unit has a **single AP pool** (`ap_max`). Moving, shooting, building, healing, pushing and capturing all draw from it.
- AP regenerate at a **constant rate** (`ap_regen` per second), always, whether the unit is idle, moving or fighting, up to `ap_max`.
- Movement cost depends on movement class, terrain and slope (`data/terrain.yaml`).
- **What costs AP:** each shot (`ap_per_shot`), each metre moved, each metre pushed (relic or HQ), picking up a weapon from the ground (decision 63), and role actions.
- **What costs only time:** reloading, unloading and swapping weapons, landing and taking off. They take their duration but no AP. (Decisions 55, 68)
- **A unit with 0 AP is never frozen.** It keeps moving, but only as fast as its AP come back. Example: a soldier moving at 5 m/s on grass spends 5 AP/s, more than its regen of 1.5 AP/s; once empty it goes on at about 1.5 m/s. A shot or a role action simply waits until the unit has enough AP. (Decision 56)

### Role actions (decisions 66, 67)
- **Build, repair, heal and capture** cost a **fixed AP amount paid up front**, then take their **duration**. A unit must have the AP to start.
- **Pushing** a relic or the HQ is movement: each pusher pays **AP per metre** pushed, with the slope factor of its movement class.
- **Interrupted action** (the unit moves away, an enemy blocks a capture...): the AP already paid are **lost**, the **progress is kept**. Resuming costs the AP of the **remaining part** only.
- Values in `data/combat.yaml` (`actions`, `push`); construction costs per structure: Q-ECO-04.

## 2. Seeing and hitting
### Targets
- A unit fires only at targets **it sees itself**, up to its weapon's range. Seeing is limited by vision range, weather, terrain and height (see `specs/10-map-and-terrain.md`, section 5). Scouts and radios share information for awareness, not for aiming. (Decision 59)
- **Exception: indirect fire** (artillery, `indirect_fire: true`). It may target a **ground position** that a unit of its own section currently sees, or that a scout reports through a radio in range. Its hit chance is lower than direct fire (`indirect_factor`). (Decision 62)
- A unit with **no weapon** (radio, truck) cannot attack. (Decision 64)

### Hit resolution: hybrid
- When a player is **inside a unit** (first-person control), hits depend on the player's **aim**: projectiles travel in 3D and obstacles block them. The unit's `attack` tightens weapon spread and sway, so an evolved unit still aims better.
- When a unit acts under **orders or section AI** (top-down control or offline-passive), a **hit chance** is computed (decision 65):

  `chance = weapon base accuracy × (1 + (attack − defense) / 100) × distance × cover × size × speed × morale factors` (× indirect factor), **clamped to 5–95 %**.
  - distance factor: from 1 at point blank down to 0.5 at maximum range;
  - cover factor: none, partial or full (full = cannot be hit);
  - size factor: by the target's armor type (a tank is easier to hit than a soldier);
  - speed factor: a fast target is harder to hit;
  - morale factor: from 0.9 at morale 0 to 1.1 at morale 100 for the attacker (decision 71).
  All values in `data/combat.yaml` (`hit_chance`).
- Both modes must give comparable average results, so that controlling a unit directly is a choice, not an obligation. (Balancing target.)

### attack and defense
- `attack` is **accuracy**: it raises the hit chance and tightens spread.
- `defense` is **evasion**: it lowers the chance of being hit.
- **Neither changes damage.** (Decision 58)

## 3. Damage: weapon vs armor table
- Each weapon has a **weapon type**; each unit or object has an **armor type** (`armor_type` in `data/units.yaml`).
- **Damage = weapon base damage × multiplier from the weapon-vs-armor table** (× `airborne_factor` when the target is flying). Nothing else changes it: not unit stats, not cover. (Decisions 57, 65)
- Armor types: infantry, light vehicle, heavy vehicle, structure, relic (indestructible), HQ.
- The table lives in `data/combat.yaml`.

### Flying targets
- **Flying is a capability, not an armor type.** A flying unit keeps a normal armor type (for example light vehicle).
- Each weapon has an `airborne_factor` applied when the target is flying. 0 means the weapon cannot hit flying units; anti-air weapons have a high factor. (Decision 57)

## 4. Weapons
### Weapons are items
- A unit has **one weapon slot**. Each unit type lists the **weapon types it may use** (`weapons.allowed`). (Decision 52)
- A newly bought unit comes with its type's **default weapon**, included in its price. Other weapons are **bought with section money** (prices: Q-ECO-01).
- Weapons are equipped or swapped **only while the unit is stored or next to its storage place**. (Decision 53)

### Dropped weapons
- A **killed unit drops its weapon** on the ground. (Decision 53)
- **Any unit of any team** whose allowed list includes that weapon type can **pick it up on the spot**, for an **AP cost** (the only weapon handling that costs AP, decision 63). Its current weapon drops in its place.
- Dropped weapons **vanish after a delay**.

### Ammo and reloading
- **Ammo is unlimited.** Only the loaded magazine is limited. (Decision 54)
- A **reload always gives a full magazine**; rounds left in it are discarded. The cost of reloading is its time, not lost ammo.

### Weapon characteristics
Each weapon has, besides damage, range and AP per shot:
| Field | Meaning |
|---|---|
| `rate_of_fire_rpm` | Firing speed: shots per minute while the magazine is not empty. |
| `magazine_capacity` | Cartridge capacity: shots before the weapon must be reloaded. |
| `reload_time_s` | Loading speed: time to load a full magazine. No AP. |
| `unload_time_s` | Unloading speed: time to unload the weapon. No AP. |
| `move_while_loaded` | Whether the unit can move with the weapon loaded. If not, it must unload first (for example artillery). |
| `airborne_factor` | Damage multiplier against flying targets (0 = cannot hit them). |

## 5. Friendly fire
- **On, full damage.** Artillery, explosions and crossfire hurt allies exactly like enemies.
- Consequence with permadeath: careless artillery can kill friendly units for good. Statistics and medals may track friendly kills (to define).

## 6. Reaching 0 HP: death, prisoner or defection
- Normally a unit at 0 HP **dies** (permadeath; the commander resurrects at the HQ).
- **Only a commander can take a prisoner or cause a defection**, and only when he **deals the final blow himself**. When any other unit brings the target to 0 HP, it simply dies.
- When a **commander** brings it to 0 HP, there are **odds of another outcome**:
  - the unit is **taken prisoner**;
  - the unit **switches side**: if the attacking section has room (section size cap), the unit **joins the attacker's section**. The owner loses the unit and the attacker gains it.
- The odds depend on the unit's **morale** and its **AP**: **low morale and low AP raise the odds of surrender (prisoner) or defection**. A fresh, confident unit fights to death. (Decision 72)

  `p(spared) = k × ((100 − morale)/100 + (1 − AP/ap_max)) / 2`, with k = 0.6.

  Example: morale 20 and AP at 10 % → 0.6 × (0.8 + 0.9) / 2 = 51 %. Morale 50 and full AP → 15 %.
  A spared unit **defects** or becomes a **prisoner**, 50/50. Defection needs room in the attacking section; without room it becomes a prisoner.
- A unit that **switches side keeps everything** (XP, evolution and its weapon). The attacker gains an evolved unit.
- A **defector is an ordinary unit** of its new section: it can be killed, captured, or defect again under the same rules. Statistics count a defection for the captor and a loss for the previous owner. (Decision 74)
- **No extra limit on defections** (snowball): limiting them to commanders is considered enough; to watch in playtests. (Decision 75)

### Prisoners (decision 73)
- A prisoner keeps its weapon (decision 64) and goes **instantly to the captor section's storage**. It cannot fight or escape.
- **Exchange and ransom** are negotiated **in game, between section owners**: the captor's owner posts an offer (an exchange for named prisoners, or a price); the prisoner's original owner accepts or refuses. A ransom goes **entirely to the captor section** (no fee). A released prisoner returns to its owner's storage.
- A prisoner never released is **lost at the end of the war**, with the rest of the war's units.

## 7. Morale
- **Morale** is a unit stat from **0 to 100**. A new unit starts at the base value (50). (Decision 70)
- It changes **only through events**; there is no drift back toward the base value.
- It is changed by:
  - the **commander aura** (section units near their commander gain morale);
  - **nearby fights**: kills raise it, deaths of nearby allies lower it;
  - **being outnumbered** (local force ratio).
- Morale slightly scales the unit's **hit chance** (decision 71) and sets the **0-HP odds** (decision 72).
- Values in `data/combat.yaml` (`morale`).

### Radio (decision 76)
- A radio is a **normal unit**: bought with money, it has HP, can be destroyed, taken prisoner or defect, and is stored like any unit. It has no weapon and cannot attack.
- Its relay range starts at the `units.yaml` value and grows through its skill tree.

## 8. Cover
- Obstacles **block shots**. **Partial cover** (trees, craters, low walls) **lowers the chance of being hit**; it does not reduce damage. In first person it physically hides part of the target. **Full cover** blocks completely. (Decision 65, revises 37e)

## 9. Transports
- When a transport is destroyed, carried units are **ejected next to the wreck with heavy damage**.

## 10. Open questions
See `specs/95-open-questions.md`: Q-CBT-15 (do prisoners use storage capacity?), Q-CBT-16 (morale in first-person aim).
