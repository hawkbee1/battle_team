# Combat and Action Points

Status: **ready**. Decisions come from the Q&A with the game designer; changes go through `specs/95-open-questions.md`. Each rule has a stable ID (`COMBAT-NN`).

## 1. Action points (AP)
- **COMBAT-01** Each unit has a **single AP pool** of at most **30 AP** (`ap_max`, the same for every unit, decision 167). Moving, shooting, building, healing, pushing and capturing all draw from it.
- **COMBAT-02** AP recover at a **constant rate**, for every unit, always, whether it is idle, moving, fighting or stored, up to `ap_max` (30, decision 167). The default rate is **1 AP per hour**. It is a battle setting (`ap.recovery_per_hour` in `data/battle.yaml`), so special events can use another rate (decisions 168, 172).
- **COMBAT-03** Movement cost: each unit has an **AP per metre** (`ap_per_m` in `data/units.yaml`): 1 for infantry, 0.2 for a tank, 0.1 for a jeep. The movement class and the terrain multiply it (`ap_multiplier` in `data/terrain.yaml`), and the slope multiplies it too (decision 169). They change only the AP cost, never `move_speed` (decision 180).
- **COMBAT-04** **What costs AP:** each shot (`ap_per_shot`), each metre moved (COMBAT-03), each metre pushed, paid from the team's push pot (COMBAT-08), picking up a weapon from the ground (decision 63), contributions to a capture (COMBAT-07), and role actions.
- **COMBAT-05** **What costs only time:** reloading, unloading and swapping weapons, landing and taking off. They take their duration but no AP; a weapon swap takes **5 s** (`weapon_swap` in `data/combat.yaml`). (Decisions 55, 68, 134)
- **COMBAT-06** **A unit with 0 AP is never frozen.** It keeps moving, but only as fast as its AP come back. Example: an infantry unit (1 AP per metre) starts with 30 AP, so it covers 30 m on grass; after that it recovers 1 AP per hour (the default rate, COMBAT-02), so it moves 1 m per hour. A shot or a role action simply waits until the unit has enough AP. An action the unit cannot do (not in its actions, UNIT-38) is refused. (Decisions 56, 132, 167, 168)

### Role actions (decisions 66, 67)
- **COMBAT-07** **Build and repair** cost a **fixed AP amount paid up front**, then take their **duration**. A unit must have the AP to start. **Capture** is paid into a **team pot**, 5 AP per contribution (RELIC-05, decision 170). **Healing is instant** (decision 91). Heal and repair work on every friendly unit except the HQ (decision 139). Construction AP and build time per structure: `data/terrain.yaml` (decision 113).
- **COMBAT-08** **Pushing** a relic is paid by its **push pot** (the HQ is not pushed, HQ-14): pushers add **5 AP** per action, as often as they like, and each metre pushed costs **10 AP** from the pot (`push.pot_ap_per_m`), times the ground and signed slope multipliers of the `push` profile (decisions 133, 175). A partly filled pot stays until it is used up or control is lost (decisions 173, 176). An empty pot stops the push (RELIC-24). (Decisions 171, 173, 175, 176, 177)
- **COMBAT-09** **Interrupted action** (for example the unit moves away): the AP already paid are **lost**, the **progress is kept**. Resuming costs the AP of the **remaining part** only. **Exception:** a capture interrupted by an enemy entering the capture radius **loses its progress and its pot** (decisions 97, 170). Capture progress belongs to the team (RELIC-29, decision 140).
- **COMBAT-10** Values in `data/combat.yaml` (`actions`, `push`); construction AP and build time per structure: `data/terrain.yaml` (decision 113).

## 2. Seeing and hitting
### Targets
- **COMBAT-11** A unit fires only at targets **it sees itself**, up to its weapon's range. Seeing is limited by vision range, weather, terrain and height (see `specs/10-map-and-terrain.md`, section 5). Scouts and radios share information for awareness, not for aiming. (Decision 59)
- **COMBAT-12** **Exception: indirect fire** (artillery, `indirect_fire: true`). It may target a **ground position** that a unit of its own section currently sees, or that a scout reports through a radio in range. Its hit chance is lower than direct fire (`indirect_factor`). (Decision 62) Splash: COMBAT-55.
- **COMBAT-57** A section whose unit is **hit by a shooter it does not see** learns the hit and its damage, **not the shooter nor where the shot came from**. The shooter shows only once one of the section's units sees it. (Decision 234)
- **COMBAT-58** **The unseen leaves no clue.** A unit the section sees, hit by a shooter it does not see, shows its hit and damage only, as in COMBAT-57, not even whether the shooter is a friend. A unit it sees that fires at a target it does not see, or whose outcome it does not see, shows as firing, outcome unknown, with only the hits on units it sees. A weapon dropped where none of its units sees is not shown. (Decision 237)
- **COMBAT-13** A unit with **no weapon** (radio, truck) cannot attack. (Decision 64)

### Hit resolution: hybrid
- **COMBAT-14** When a player is **inside a unit** (first-person control), hits depend on the player's **aim**: projectiles travel in 3D and obstacles block them. The unit's `attack` tightens weapon spread and sway, so an evolved unit still aims better. A shot flies at its weapon's `projectile_speed_mps` and hits the first **hit volume** (`hit_box_m` of a unit or the HQ) or obstacle on its path, so a moving target can leave the line before it arrives. Artillery and the explosive charge do not fly (decision 183).
- **COMBAT-15** When a unit acts under **orders or section AI** (top-down control or offline-passive), a **hit chance** is computed (decision 65):

  `chance = weapon base accuracy × (1 + (attack − defense) / 100) × distance × cover × size × speed × morale factors` (× indirect factor), **clamped to 5–95 %**.
  - distance factor: from 1 at point blank down to 0.5 at maximum range;
  - cover factor: none, partial or full (0); with full cover the clamp still leaves 5 % (decision 135);
  - size factor: by the target's armor type (a tank is easier to hit than a soldier);
  - speed factor: a fast target is harder to hit;
  - morale factor: from 0.9 at morale 0 to 1.1 at morale 100 for the attacker (decision 71). The same factor scales weapon spread in first-person aim (decision 95).
  All values in `data/combat.yaml` (`hit_chance`).
- **COMBAT-16** Both modes must give comparable average results, so that controlling a unit directly is a choice, not an obligation. (Balancing target.)

### attack and defense
- **COMBAT-17** `attack` is **accuracy**: it raises the hit chance and tightens spread.
- **COMBAT-18** `defense` is **evasion**: it lowers the chance of being hit.
- **COMBAT-19** **Neither changes damage.** (Decision 58)

## 3. Damage: weapon vs armor table
- **COMBAT-20** Each weapon has a **weapon type**; each unit or object has an **armor type** (`armor_type` in `data/units.yaml`; objects: `data/terrain.yaml`, decision 137).
- **COMBAT-21** **Damage = weapon base damage × multiplier from the weapon-vs-armor table** (× `airborne_factor` when the target is flying). Nothing else changes it: not unit stats, not cover. (Decisions 57, 65)
- **COMBAT-22** Armor types: infantry, light vehicle, heavy vehicle, structure, relic (indestructible), HQ.
- **COMBAT-23** The table lives in `data/combat.yaml`.
- **COMBAT-55** **Bombard attacks** (decisions 136, 152): weapons with a `splash_radius_m` (artillery, the engineer's explosive charge). Every unit within `splash_radius_m` of the impact point is hit at once, without its own hit roll, friend or foe; damage decreases with the distance from the impact point and does not depend on the weapon's range (`splash` in `data/combat.yaml`). An artillery shot uses the hit chance (COMBAT-12); a missed shot lands away from the aimed point, in a random direction, at a distance proportional to how much it missed (`miss_scatter`); the landing point always stays within the weapon's range from the artillery (decision 154). The explosive charge **never misses**, like a trap (decision 152).

### Flying targets
- **COMBAT-24** **Flying is a capability, not an armor type.** A flying unit keeps a normal armor type (for example light vehicle).
- **COMBAT-25** Each weapon has an `airborne_factor` applied when the target is flying. 0 means the weapon cannot hit flying units; anti-air weapons have a high factor. (Decision 57)

## 4. Weapons
### Weapons are items
- **COMBAT-26** A unit has **one weapon slot**. Each unit type lists the **weapon types it may use** (`weapons.allowed`). (Decision 52)
- **COMBAT-27** A newly bought unit comes with its type's **default weapon**, included in its price. Other weapons are **bought with section money** (prices: `data/economy.yaml`). Bought and swapped-out weapons are kept in the section's **storage** until a unit takes one (decision 151).
- **COMBAT-28** Weapons are equipped or swapped **only while the unit is stored or next to its storage place**. A weapon taken from storage arrives **unloaded** (decisions 53, 187).

### Dropped weapons
- **COMBAT-29** A **killed unit drops its weapon** on the ground. (Decision 53)
- **COMBAT-30** **Any unit of any team** whose allowed list includes that weapon type can **pick it up on the spot**, for an **AP cost** (the only weapon handling that costs AP, decision 63). Its current weapon drops in its place. The picked-up weapon arrives **unloaded** (decision 187).
- **COMBAT-31** Dropped weapons **vanish after a delay**.

### Ammo and reloading
- **COMBAT-32** **Ammo is unlimited.** Only the loaded magazine is limited. (Decision 54)
- **COMBAT-33** A **reload always gives a full magazine**; rounds left in it are discarded. The cost of reloading is its time, not lost ammo.
- **COMBAT-56** A **1-round weapon** (`magazine_capacity: 1`) fires once per reload: the time between two shots is its `reload_time_s` (decision 150).

### Weapon characteristics
Each weapon has, besides damage, range and AP per shot:
| Field | Meaning |
|---|---|
| `rate_of_fire_rpm` | Firing speed: shots per minute while the magazine is not empty. Not used by 1-round weapons (COMBAT-56). |
| `magazine_capacity` | Cartridge capacity: shots before the weapon must be reloaded. |
| `reload_time_s` | Loading speed: time to load a full magazine. No AP. |
| `unload_time_s` | Unloading speed: time to unload the weapon. No AP. |
| `move_while_loaded` | Whether the unit can move with the weapon loaded. If not, it must unload first (for example artillery). |
| `airborne_factor` | Damage multiplier against flying targets (0 = cannot hit them). |
| `projectile_speed_mps` | Speed of a first-person shot (decision 183). Not set for artillery or the explosive charge. |

## 5. Friendly fire
- **COMBAT-34** **On, full damage.** Artillery, explosions and crossfire hurt allies exactly like enemies.
- **COMBAT-35** Consequence with permadeath: careless artillery can kill friendly units for good. Statistics and medals track friendly kills (decision 143).

## 6. Reaching 0 HP: death, prisoner or defection
- **COMBAT-36** Normally a unit at 0 HP **dies** (permadeath; the commander resurrects in storage).
- **COMBAT-37** **Only a commander can take a prisoner or cause a defection**, and only when he **deals the final blow himself**. When any other unit brings the target to 0 HP, it simply dies. The target must be an **enemy**: friendly fire never takes a prisoner or causes a defection (decision 131). An enemy commander or a guild camp is never spared (decision 149).
- **COMBAT-38** When a **commander** brings it to 0 HP, there are **odds of another outcome**:
  - the unit is **taken prisoner**;
  - the unit **switches side**: if the attacking section has room under its cap (UNIT-39, UNIT-40), the unit **joins the attacker's section**. The owner loses the unit and the attacker gains it.
- **COMBAT-39** The odds depend on the unit's **morale** and its **AP**: **low morale and low AP raise the odds of surrender (prisoner) or defection**. A fresh, confident unit fights to death. (Decision 72)

  `p(spared) = k × ((100 − morale)/100 + (1 − AP/ap_max)) / 2`, with k = 0.6.

  Example: morale 20 and AP at 10 % → 0.6 × (0.8 + 0.9) / 2 = 51 %. Morale 50 and full AP → 15 %.
  A spared unit **defects** or becomes a **prisoner**, 50/50. Defection needs room in the attacking section; without room it becomes a prisoner.
- **COMBAT-40** A unit that **switches side keeps everything** (XP, evolution and its weapon). The attacker gains an evolved unit.
- **COMBAT-41** A **defector is an ordinary unit** of its new section: it can be killed, captured, or defect again under the same rules. Statistics count a defection for the captor and a loss for the previous owner. (Decision 74)
- **COMBAT-42** **No extra limit on defections** (snowball): limiting them to commanders is considered enough; to watch in playtests. (Decision 75)

### Prisoners (decision 73)
- **COMBAT-43** A prisoner keeps its weapon (decision 64) and goes **instantly to the captor section's prisoner storage**: separate from unit storage, **unlimited**, never counted in storage capacity (decision 94). It cannot fight or escape.
- **COMBAT-44** **Exchange and ransom** are negotiated **in game, between section owners**: the captor's owner posts an offer (an exchange for named prisoners, or a price); the prisoner's original owner accepts or refuses. A ransom goes **entirely to the captor section** (no fee). A released prisoner returns to its owner's storage.
- **COMBAT-45** A prisoner never released is **lost at the end of the war**, with the rest of the war's units.

## 7. Morale
- **COMBAT-46** **Morale** is a unit stat from **0 to 100**. A new unit starts at the base value (50). (Decision 70)
- **COMBAT-47** It changes **only through events**; there is no drift back toward the base value.
- **COMBAT-48** It is changed by:
  - the **commander aura** (section units near their commander gain morale);
  - **nearby fights**: kills raise it, deaths of nearby allies lower it;
  - **being outnumbered** (local force ratio).
- **COMBAT-49** Morale slightly scales the unit's **hit chance** (decision 71) and sets the **0-HP odds** (decision 72).
- **COMBAT-50** Values in `data/combat.yaml` (`morale`).

### Radio (decision 76)
- **COMBAT-51** A radio is a **normal unit**: bought with money, it has HP, can be destroyed, taken prisoner or defect, and is stored like any unit. It has no weapon and cannot attack.
- **COMBAT-52** Its relay range starts at the `units.yaml` value and grows through its skill tree.

## 8. Cover
- **COMBAT-53** Obstacles **block shots**. **Partial cover** (trees, craters, low walls) **lowers the chance of being hit**; it does not reduce damage. In first person it physically hides part of the target. **Full cover** blocks completely in first person; under orders or AI it leaves the 5 % minimum (decision 135). (Decision 65, revises 37e)

## 9. Transports
- **COMBAT-54** When a transport is destroyed, carried units are **ejected next to the wreck with heavy damage**: a share of their maximum HP (`transport` in `data/combat.yaml`, decision 137).

## 10. Open questions
None. See `specs/95-open-questions.md`.
