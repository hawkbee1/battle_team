# Combat and Action Points (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers live in `data/combat.yaml` and `data/units.yaml`.

## 1. Action points (AP)
- Each unit has a **single AP pool** (`ap_max`). Move, attack, build, heal, push, capture all draw from it.
- AP regenerate at a **constant rate** (`ap_regen` per second), always, whether the unit is idle, moving or fighting, up to `ap_max`.
- Movement cost depends on movement class, terrain and slope (`data/terrain.yaml`).

## 2. Hit resolution: hybrid
- When a player is **inside a unit** (first-person control), hits depend on the player's **aim**: projectiles travel in 3D and obstacles block them.
- When a unit acts under **orders or section AI** (top-down control or offline-passive), a **hit chance** is computed (distance, cover, line of sight, target size/speed, attacker skill/XP).
- Both modes must give comparable average results, so that controlling a unit directly is a choice, not an obligation. (Balancing target.)

## 3. Damage: weapon vs armor table
- Each weapon has a **weapon type**; each unit or object has an **armor type**.
- Damage = weapon base damage × multiplier from the **weapon-vs-armor table**.
- Draft armor types: infantry, light vehicle, heavy vehicle, building/structure, relic (indestructible), HQ.
- The table lives in `data/combat.yaml`.

### Flying targets
- **Flying is a capability, not an armor type.** A flying unit keeps a normal armor type (for example light vehicle).
- Proposal (to confirm): each weapon has an `airborne_factor` applied when the target is flying. 0 means the weapon cannot hit flying units; anti-air weapons have a high factor.

### Weapon characteristics
Each weapon has, besides damage, range and AP per shot:
| Field | Meaning |
|---|---|
| `rate_of_fire_rpm` | Firing speed: shots per minute while the magazine is not empty. |
| `magazine_capacity` | Cartridge capacity: shots before the weapon must be reloaded. |
| `reload_time_s` | Loading speed: time to load a full magazine. |
| `unload_time_s` | Unloading speed: time to unload the weapon. |
| `move_while_loaded` | Whether the unit can move with the weapon loaded. If not, it must unload first (for example artillery). |

## 4. Friendly fire
- **On, full damage.** Artillery, explosions and crossfire hurt allies exactly like enemies.
- Consequence with permadeath: careless artillery can kill friendly units for good. Statistics and medals may track friendly kills (to define).

## 5. Reaching 0 HP: death, prisoner or defection
- Normally a unit at 0 HP **dies** (permadeath; the commander resurrects at the HQ).
- **Only a commander can take a prisoner or cause a defection**, and only when he **deals the final blow himself**. When any other unit brings the target to 0 HP, it simply dies.
- When a **commander** brings it to 0 HP, there are **odds of another outcome**:
  - the unit is **taken prisoner**;
  - the unit **switches side**: if the attacking section has room (section size cap), the unit **joins the attacker's section**. The owner loses the unit and the attacker gains it.
- The odds depend on the unit's **morale** and its **AP**: **low morale and low AP raise the odds of surrender (prisoner) or defection**. A fresh, confident unit fights to death.
- A unit that **switches side keeps everything** (XP and evolution). The attacker gains an evolved unit.
- A **prisoner** can be **exchanged** between teams or **ransomed** for money.

## 6. Morale
- **Morale** is a unit stat.
- It is changed by:
  - the **commander aura** (section units near their commander gain morale);
  - **nearby fights**: kills raise it, deaths of nearby allies lower it;
  - **being outnumbered** (local force ratio).

Open:
- Base odds and formula (morale, AP → death / prisoner / defection).
- Where prisoners are held, and what happens to them at the end of a battle or of the war if never exchanged.
- Exchange and ransom flow: who negotiates (HQ manager? section owner?), in game or on Discord, ransom paid to whom?
- Can a defector's previous owner recapture it? Does defection count in statistics/medals?
- Morale range and recovery over time.

## 7. Cover
- Obstacles **block shots** and give **damage reduction** when partial (trees, craters, low walls). Full cover blocks completely.

## 8. Transports
- When a transport is destroyed, carried units are **ejected next to the wreck with heavy damage**.

## 9. Open questions
- AP cost of each action (shot, reload, unload, build per second, heal per second, push per second, capture per second).
- Weapons: is a partly used magazine kept or lost on reload? Can a unit carry several weapons, and how does a unit get its weapon (link between `data/units.yaml` and `data/combat.yaml`)?
- Flying targets: confirm the `airborne_factor` approach.
- Weapon values (rate of fire, magazine, reload and unload times); artillery splash and terrain deformation.
- Defection gives evolved units to the attacker: watch the snowball effect (strong teams get stronger), especially with newcomers placed in the weakest team. Limiting prisoners and defections to commanders already reduces this risk a lot.
