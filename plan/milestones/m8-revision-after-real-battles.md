# Milestone 8: revision after real battles

Goal: after a few real battles, review the rules using what the battle logs and statistics show and what players need. The results are new decisions in `specs/00-overview.md`, changes to `data/*.yaml`, and issues for the changes.

## Topics
1. **Moderation and blocking tools** (Q-SOC-11): reporting and blocking players, abuse of pings, map markers and team chat (SOC-37).
2. **Risks accepted for now** (`specs/96-design-risks.md`): R-01 (a commander's death as a recall and money top-up), R-02 (money per hit), and whether the battles confirm the open risks.
3. **Points to watch in playtests**: the snowball effect of defections (decision 75), comparable results between first-person control and orders or AI (COMBAT-16), money from the transfer and safety-net loop (ECO-14), build-and-destroy farming (ECO-22).
4. **Tuning** of the placeholder numbers in `data/*.yaml` from the logs (decision 69).
5. **Units along their paths on the host** (decision 236, Q-MAP-26): the host keeps each move's path with its times, so sight, shots and the update stream follow a moving unit, at 5 Hz in the stream (stack decision 3), instead of placing it at its destination as its move starts.
6. **One unit per place on the host** (decision 240, MAP-50): an occupancy index by cell width, bridge `width_m`, the airborne layer, nearest free place for deployment and purchases, refusal for a seen blocker and the stop short of an unseen one; with topic 5, the width check along the path. Later, exact footprints with `package:scene`'s pure-Dart shape queries (the same `Shape` per unit type as the client): a stack record for the designer to confirm then. The map builder warns on corridors narrower than a width.

## Done when
- Each topic has a decision (change or keep) recorded in `specs/00-overview.md`.
