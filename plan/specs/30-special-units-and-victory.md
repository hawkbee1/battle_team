# Special Units and Victory (working draft)

Status: draft. Decisions come from the Q&A with the game designer.

## 1. The 8 special units: ancient relics
- The 8 special units are **ancient relics / artifacts**. Their exact name and lore are to be written.
- They are placed on solid ground when a battle starts.
- They are **movable objects**, but move very slowly and are too big to be carried by a transport.
- They are different from radios (radios are purchasable units that relay scout information).

## 2. Capture
- **Any unit next to a relic** can start a **capture action**. It costs AP and takes time.
- A capture is **blocked while enemy units are near** the relic (within a radius to be defined). Defenders can therefore protect a relic by standing next to it.
- When a relic changes owner, the **previous owner team is alerted** at once.
- Once captured, the relic is **owned** by the capturing team until another team captures it.
- No protection time after a capture: a relic can be retaken as soon as no enemy of the attacker is near.
- All nearby units are taken into account. The radius is a battle parameter.

Open:
- Capture duration and AP cost; "near" radius.
A: 30 min and 50 AP (battle parameters)
- Can a relic be captured if its current owner has units near it but they are offline/passive?
A: no, offline/passive is not a parameter in the game rules

## 3. Benefits
- Owning a relic gives **nothing besides the victory timer**. It is a pure objective: no income, vision or combat bonus.

## 4. Victory
- A battle ends when only one HQ remains, OR when one team owns **5 of the 8 relics for 24 hours**.
- **The 24-hour timer resets fully** as soon as the team drops below 5 relics, even for a moment.

Open:
- Is timer progress visible to all teams (countdown, alerts)?
- No tie is possible: with 8 relics, only one team can hold 5 at a time.
- Fairness across time zones: with a full reset, attackers need only one successful capture to reset 24 hours of holding. Expected effect: battles mostly end by HQ destruction or by a team strong enough to defend 5 points around the clock. To validate in playtests.

## 5. Movement of relics
- A relic moves only when it is **pushed** by units of the team that **controls** it (owns it). It moves very slowly.
- A relic **cannot fly** and **cannot cross water, forests, towns or walls**. These are obstacles for relics.
- Consequence: engineers can **block a relic's path by building walls**, and roads/open ground become the relic routes.
- A relic **can fall from a floating island** when pushed over its edge.
- A relic **crushes units in its path if it is pushed hard enough**.

- **Push**: a minimum number of pushers is needed; the relic then moves at a **fixed slow speed**. Pushing **costs AP per metre** to each pushing unit, like movement (decision 66).
- **Crushing**: units in the path take **heavy damage** (they may survive), whatever their team.
- **Falling** from a floating island: the relic **lands on the ground below, intact, keeps its owner**, and crushes (heavy damage) what is under it.
- **Water**: relics cross water only on **reinforced bridges**, a special heavy bridge built by engineers (more cost and time than a normal bridge).

- **Crush rule**: a relic crushes only when pushed with **more than the minimum number of pushers** (extra pushers). With just the minimum, it stops at units blocking its path.
- **Slopes** change the **effort** needed to push: going uphill needs more push (pushers and/or AP), going downhill needs less.
- Relics are **indestructible**.
- A relic with no possible path (e.g. walled in) **stays stuck**. Destroying the walls frees it. It can still be captured where it stands.

Open:
- Minimum number of pushers; AP cost per metre of pushing (placeholder in `data/combat.yaml`); how much the slope changes the effort (formula, data file).
- Number of extra pushers needed to crush.
- Reinforced bridge: cost, build time, hit points; can enemies destroy it while a relic is on it (relic falls into the water? stays stuck in the river?).

## 6. Open questions (summary)
- Name and lore of the relics.
- Capture numbers (time, AP, radius).
- Push numbers (minimum pushers, AP cost, slope effort, extra pushers to crush).
- Timer visibility.
