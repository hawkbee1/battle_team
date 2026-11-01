# Milestone 1: section AI and automation

Goal: decide with the game designer what units do when no player controls them directly, which actions happen on their own, and what players can automate. The result is a new spec, `specs/80-ai-and-automation.md` (rule prefix `AI`), with its numbers in `data/*.yaml`, followed by implementation issues added to this file.

This milestone writes rules only (specs and data), so it needs no technical stack and no code. It starts as a discussion, like the spec phase: questions get IDs `Q-AI-NN` in `specs/95-open-questions.md`, and answers become numbered decisions in `specs/00-overview.md`.

## What the rules already say
- Units that are not directly controlled follow simple section AI behaviours: follow commander, hold, patrol... (decision 20).
- Units of an offline player stay passive on the field and can be attacked (decision 29).
- Under orders or AI, hits use the hit chance (COMBAT-15), and both control modes should give comparable results (COMBAT-16).
- Logging off safely is costly (R-07 in `specs/96-design-risks.md`).

## Decided (decisions 156 to 160)
- Player units act only on orders. Nothing happens automatically for them, including units of an offline player.
- AI agents play by the same rules as players, through the API. One API key per account identifies the user.
- Server-managed sections look like other sections. Their units may fire on a chance, checked every 30 minutes.

Key revocation and action history are decisions 161 and 162. Server-managed sections have the same capabilities as a normal section (163), and their shots follow the normal hit rule (164). The rules are in `specs/80-ai-and-automation.md` (`AI-01` to `AI-08`), in review.

The behaviours, targeting, queued orders, waypoints and detailed AI rules of the first draft are dropped: the decisions above make them moot.

## Done when
- `specs/80-ai-and-automation.md` is **ready**, with rule IDs.
- Implementation issues for the AI are written once the stack is chosen (M2). They build on the rules core (M4) and pathfinding (M3).
