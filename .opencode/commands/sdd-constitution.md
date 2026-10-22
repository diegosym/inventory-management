---
description: SDD · Propose or amend the constitution (principles that cannot be negotiated)
agent: planner
---
The official constitution is `docs/constitution.md` — never create a second one. Use
the sdd skill. This command never modifies any file: propose the changes and return
the proposed text or diff in your answer.

Before proposing anything, read AGENTS.md, MEMORY.md and docs/constitution.md.
Additional context: $ARGUMENTS

Propose short, verifiable principles that cover the project's real risks, keeping the
constitution small — this app is simple; do not generate unnecessary trade-offs (C5).
The constitution is never modified without the user's explicit approval (C4); once
approved, the change is recorded in MEMORY.md — no ADRs in this project. Say so and
wait. Maximum 15 lines per proposal.
