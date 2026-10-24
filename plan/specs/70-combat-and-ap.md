# Combat and Action Points (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers live in `data/combat.yaml` and `data/units.yaml`.

## 1. Action points (AP)
- Each unit has a **single AP pool** (`ap_max`). Moving, shooting, building, healing, pushing and capturing all draw from it.
- AP regenerate at a **constant rate** (`ap_regen` per second), always, whether the unit is idle, moving or fighting, up to `ap_max`.
- Movement cost depends on movement class, terrain and slope (`data/terrain.yaml`).
- **What costs AP:** each shot (`ap_per_shot`), each metre moved, picking up a weapon from the ground, and role actions (build, heal, push, capture: values still open, Q-CBT-01).
- **What costs only time:** reloading, unloading and swapping weapons. They take their duration but no AP. (Decision 55)
- **A unit with 0 AP is never frozen.** It keeps moving or acting, but only as fast as its AP come back. Example: a soldier moving at 5 m/s on grass spends 5 AP/s, more than its regen of 1.5 AP/s; once empty it goes on at about 1.5 m/s. (Decision 56)

## 2. Seeing and hitting
### Targets
- A unit fires only at targets **it sees itself**, up to its weapon's range. Seeing is limited by vision range, weather, terrain and height (see `specs/10-map-and-terrain.md`, section 5). Scouts and radios share information for awareness, not for aiming. (Decision 59)

### Hit resolution: hybrid
- When a player is **inside a unit** (first-person control), hits depend on the player's **aim**: projectiles travel in 3D and obstacles block them. The unit's `attack` tightens weapon spread and sway, so an evolved unit still aims better.
- When a unit acts under **orders or section AI** (top-down control or offline-passive), a **hit chance** is computed from the attacker's `attack`, the target's `defense`, distance, cover, line of sight, and target size and speed. Formula: Q-CBT-12.
- Both modes must give comparable average results, so that controlling a unit directly is a choice, not an obligation. (Balancing target.)

### attack and defense
- `attack` is **accuracy**: it raises the hit chance and tightens spread.
- `defense` is **evasion**: it lowers the chance of being hit.
- **Neither changes damage.** (Decision 58)

## 3. Damage: weapon vs armor table
- Each weapon has a **weapon type**; each unit or object has an **armor type** (`armor_type` in `data/units.yaml`).
- **Damage = weapon base damage × multiplier from the weapon-vs-armor table** (× `airborne_factor` when the target is flying). Unit stats never change it; only partial cover may reduce it (section 8, Q-CBT-12). (Decision 57)
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
- **Any unit of any team** whose allowed list includes that weapon type can **pick it up on the spot**, for an AP cost. Its current weapon drops in its place.
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
- The odds depend on the unit's **morale** and its **AP**: **low morale and low AP raise the odds of surrender (prisoner) or defection**. A fresh, confident unit fights to death.
- A unit that **switches side keeps everything** (XP and evolution). The attacker gains an evolved unit.
- A **prisoner** can be **exchanged** between teams or **ransomed** for money.

## 7. Morale
- **Morale** is a unit stat.
- It is changed by:
  - the **commander aura** (section units near their commander gain morale);
  - **nearby fights**: kills raise it, deaths of nearby allies lower it;
  - **being outnumbered** (local force ratio).

## 8. Cover
- Obstacles **block shots** and give **damage reduction** when partial (trees, craters, low walls). Full cover blocks completely.

## 9. Transports
- When a transport is destroyed, carried units are **ejected next to the wreck with heavy damage**.

## 10. Open questions
See `specs/95-open-questions.md`: Q-CBT-01 (AP of role actions), Q-CBT-03 (weapon values), Q-CBT-05 to Q-CBT-10 (morale, 0-HP odds, prisoners, defectors, radio), Q-CBT-11 (artillery and indirect fire), Q-CBT-12 (hit-chance formula and partial cover), Q-CBT-13 (weapon of a prisoner or defector).
