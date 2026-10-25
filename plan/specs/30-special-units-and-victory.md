# Special Units and Victory

Status: **ready**. Decisions come from the Q&A with the game designer; changes go through `specs/95-open-questions.md`. Each rule has a stable ID (`RELIC-NN`).

## 1. The 8 special units: relics
- **RELIC-01** The 8 special units are **relics: huge statues of the gods of war from different mythologies** (decision 96). Detailed lore is to be written.
- **RELIC-02** They are placed on solid ground when a battle starts.
- **RELIC-03** They are **movable objects**, but move very slowly and are too big to be carried by a transport.
- **RELIC-04** They are different from radios (radios are purchasable units that relay scout information).

## 2. Capture (decision 97)
- **RELIC-05** **Any unit within the capture radius** of a relic can start a **capture action**. It costs **50 AP** and takes **30 minutes**.
- **RELIC-06** A capture is **blocked while enemy units are within the same radius**. Defenders can therefore protect a relic by standing next to it.
- **RELIC-07** **Every unit inside the radius counts**, whatever its state: carried, flying, offline or passive. (Stored units are not on the map.) An owner's offline units still block a capture.
- **RELIC-08** If an enemy enters the radius during a capture, the capture stops and **its progress is lost** (exception to decision 67).
- **RELIC-09** Capture duration, AP and radius (default **30 m**) are **battle settings** (`data/battle.yaml`).
- **RELIC-10** When a relic changes owner, the **previous owner team is alerted** at once.
- **RELIC-11** Once captured, the relic is **owned** by the capturing team until another team captures it.
- **RELIC-12** No protection time after a capture: a relic can be retaken as soon as no enemy of the attacker is near.

## 3. Benefits
- **RELIC-13** Owning a relic gives **nothing besides the victory timer**. It is a pure objective: no income, vision or combat bonus.

## 4. Victory
- **RELIC-14** A battle ends when only one HQ remains, OR when one team owns **5 of the 8 relics for 24 hours**.
- **RELIC-15** **The 24-hour timer resets fully** as soon as the team drops below 5 relics, even for a moment.
- **RELIC-16** The **countdown is visible** (decision 100).
- **RELIC-17** No tie is possible: with 8 relics, only one team can hold 5 at a time.
- **RELIC-18** With a full reset, attackers need only one successful capture to reset 24 hours of holding. The designer accepts this; no special playtest is planned (decision 100).

## 5. Movement of relics
- **RELIC-19** A relic moves only when it is **pushed** by units of the team that **controls** it (owns it). It moves very slowly.
- **RELIC-20** A relic **cannot fly** and **cannot cross water, forests, towns or walls**. These are obstacles for relics.
- **RELIC-21** Consequence: engineers can **block a relic's path by building walls**, and roads/open ground become the relic routes.
- **RELIC-22** A relic **can fall from a floating island** when pushed over its edge (decision 46d, confirmed by decision 117). It lands intact below, keeps its owner and crushes what is under it.
- **RELIC-23** A relic **crushes units in its path if it is pushed hard enough**.

- **RELIC-24** **Push** (decision 98): at least **10 pushers**; the relic then moves at a **fixed slow speed**. Each pusher pays **AP per metre** pushed, and **slope changes the effort exactly as for movement**.
- **RELIC-25** **Crushing**: units in the path take **heavy damage** (they may survive), whatever their team. A relic crushes only when pushed with **more than the minimum number of pushers**: with 10 + *n* pushers it crushes **up to *n* units** in its path; if more units block it, it stops. (Decision 115)
- **RELIC-26** **Water**: relics cross water only on **reinforced bridges** (decision 99): **20 AP**, **10 min** to build, **400 HP**. If the bridge is destroyed while a relic or an HQ is on it, that relic or HQ is **lost** (decision 116):
  - a lost relic **leaves the battle**; a team still needs **5 relics** for the timer, so with fewer than 5 relics left only the HQ victory remains;
  - a lost HQ **eliminates its team**, as if destroyed (decision 46j).
- **RELIC-27** Relics are **indestructible**.
- **RELIC-28** A relic with no possible path (e.g. walled in) **stays stuck**. Destroying the walls frees it. It can still be captured where it stands.

## 6. Open questions
None. See `specs/95-open-questions.md`.
