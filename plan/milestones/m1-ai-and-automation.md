# Milestone 1: section AI and automation

Goal: decide with the game designer what units do when no player controls them directly, which actions happen on their own, and what players can automate. The result is a new spec, `specs/80-ai-and-automation.md` (rule prefix `AI`), with its numbers in `data/*.yaml`, followed by implementation issues added to this file.

This milestone writes rules only (specs and data), so it needs no technical stack and no code. It starts as a discussion, like the spec phase: questions get IDs `Q-AI-NN` in `specs/95-open-questions.md`, and answers become numbered decisions in `specs/00-overview.md`.

## What the rules already say
- Units that are not directly controlled follow simple section AI behaviours: follow commander, hold, patrol... (decision 20).
- Units of an offline player stay passive on the field and can be attacked (decision 29).
- Under orders or AI, hits use the hit chance (COMBAT-15), and both control modes should give comparable results (COMBAT-16).
- Logging off safely is costly (R-07 in `specs/96-design-risks.md`).

## Topics to discuss
1. **Behaviours**: the list (follow, hold, patrol, guard a relic, guard the camp or the HQ...), who sets them (the player, the HQ manager), per unit or per group.
2. **Rules of engagement**: whether AI units fire on their own at the enemies they see, how they choose targets, how they avoid friendly fire (full damage, COMBAT-34), whether artillery fires at relayed targets by itself.
3. **Automatic actions**: medics healing, engineers repairing, scouts observing, units capturing or pushing, without an order.
4. **Offline players**: what "passive" means (return fire, stay, retreat), and whether units are stored or recalled automatically when a player goes offline.
5. **Automation by players**: queued orders, waypoints, timed orders (for example a recall started at a set time), and the limits that keep automation from replacing play.
6. **Server cost**: how much AI a battle of 100+ players needs (an input for the simulation host, M2 Issue 1).

## Done when
- `specs/80-ai-and-automation.md` is **ready**, with rule IDs.
- Implementation issues for the AI are written once the stack is chosen (M2). They build on the rules core (M4) and pathfinding (M3).
