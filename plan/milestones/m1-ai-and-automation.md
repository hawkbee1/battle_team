# Milestone 1: section AI and automation

Goal: decide with the game designer what units do when no player controls them directly, which actions happen on their own, and what players can automate. The result is a new spec, `specs/80-ai-and-automation.md` (rule prefix `AI`), with its numbers in `data/*.yaml`, followed by implementation issues added to this file.

This milestone writes rules only (specs and data), so it needs no technical stack and no code. It starts as a discussion, like the spec phase: questions get IDs `Q-AI-NN` in `specs/95-open-questions.md`, and answers become numbered decisions in `specs/00-overview.md`.

## What the rules already say
- Units that are not directly controlled follow simple section AI behaviours: follow commander, hold, patrol... (decision 20).
- Units of an offline player stay passive on the field and can be attacked (decision 29).
- Under orders or AI, hits use the hit chance (COMBAT-15), and both control modes should give comparable results (COMBAT-16).
- Logging off safely is costly (R-07 in `specs/96-design-risks.md`).

## Principles stated by the designer (2026-10-31)
- No automatic fire and no automatic action for player units; they act only on an order.
- An API exposes the game's actions to the app and to AI agents. Each call identifies its user.
- The server creates and runs some sections. They have a limited, chance-based automaticity: a unit that sees an enemy in range fires with a chance checked periodically, not at each entry into range.

## Topics to discuss, top level first
1. **Units without an order**: player units and units of an offline player (`Q-AI-01`, `Q-AI-02`).
2. **AI agents and the API**: the rules that apply to them, and the keys that identify users (`Q-AI-03`, `Q-AI-04`).
3. **Server-managed sections**: their purpose, their units, and the chance-based firing (`Q-AI-05`, `Q-AI-06`).

Only after these three, in this order: behaviours, targeting, queued orders and waypoints, and the server load (an input for the simulation host, M2 Issue 1).

## Done when
- `specs/80-ai-and-automation.md` is **ready**, with rule IDs.
- Implementation issues for the AI are written once the stack is chosen (M2). They build on the rules core (M4) and pathfinding (M3).
