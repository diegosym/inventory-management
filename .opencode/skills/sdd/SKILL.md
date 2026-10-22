---
name: sdd
description: Always use when working with Spec-Driven Development in this project (docs/constitution.md or anything inside specs/) - drafting, reviewing or changing specs, plans and tasks, or implementing and validating tasks of a spec.
---
# Spec-Driven Development (SDD)

## Flow

Constitution → Spec → Clarification → Approval → Plan → Approval → Tasks →
Implementation → Validation.

- Never move to the next phase without the user's explicit approval when it applies.
- Clarification gate: run `/sdd-clarify` on every spec before its approval. It only
  reports findings — it never edits files or resolves decisions on its own. With no
  blocking issues, the spec goes to the user's review and approval; if it finds
  ambiguities, contradictions, or uncovered behavior that affect required behavior,
  acceptance criteria, scope, or a significant decision, they are resolved with the
  user and reflected in the spec before approving. No extra rounds when there is
  nothing to resolve: the final approval is always the user's.
- Statuses are distinct stages: `draft` → `approved` → `implemented`. `approved` comes
  only from the user's explicit approval — never confuse it with completion. A spec
  may be marked `implemented` only when all its tasks are done, the required
  validations have actually passed, and every mandatory requirement has been verified;
  if any mandatory requirement is unverified or any validation failure is pending, do
  not mark it — report what is missing.
- The spec rules: if it is not in the spec, it is not implemented. If a decision is
  missing, stop and ask the user — never invent requirements.
- Change is a return flow, not a final phase: a requirement change starts at the spec
  and follows Spec → Plan → Tasks → Code, re-approving the affected artifacts before
  touching code. First identify which parts actually need updating; do not
  automatically regenerate the whole plan and tasks when the change does not affect
  them.
- Every spec lives in its own folder: `specs/NNN-name/`. Its `spec.md`, `plan.md` and
  `tasks.md` are created progressively as the flow and its approvals advance — never
  require all three to exist from the start.
- `MEMORY.md` (owned by the coordinator) records approved decisions, relevant state
  changes, and development commands when they change. Do not duplicate spec content
  there or update it for every routine step.
- All artifacts (spec, plan, tasks) are written in **English**; identifiers and code
  are in English. The user communicates in Spanish.

## Spec template (spec.md)

```
# Spec NNN — <Name>
Status: draft | approved | implemented

## Context and goal
## Users
## User stories
- US-1. As a <role>, I want <action> so that <benefit>.
## Definitions (only for terms open to interpretation)
## Functional requirements
## Non-functional requirements
## Edge cases
## Out of scope
## Definition of done
## Open questions
- [NEEDS CLARIFICATION] <question>
```

The spec describes the WHAT and the WHY. No stack, architecture, or file names
(conscious exception: scaffolding/tooling increments may name concrete files and
commands).

## Size discipline (norm)

**Specs must be proportional to the increment's risk:**

- Target ~100 lines maximum. Tooling/scaffolding increments = checklist, not prose:
  the Definition of Done IS the spec; keep RFs minimal.
- An edge case enters the spec ONLY IF it changes the required behavior. If it only
  affects how the implementation is done, it belongs in `plan.md`.
- QA rounds may SIMPLIFY (remove, merge, shorten) — not only add. A review round that
  only grows the spec is a smell.
- If a spec exceeds ~150 lines, stop and propose a split or a trim before continuing.

## Requirements in EARS

- RF-x: WHEN <event>, THE SYSTEM <response>.
- RF-x: IF <undesired condition>, THEN THE SYSTEM <response>.
- RF-x: WHILE <state>, THE SYSTEM <response>.
- RF-x: THE SYSTEM <perpetual behavior>.

Every RF must be verifiable: nothing like "fast" or "nice" without a measurable
criterion.

## Plan (plan.md)

Files and responsibilities · API surface (endpoints, params, response shapes) when the
spec requires it · algorithm in pseudocode where it actually helps · test strategy with **RSpec** (backend) and,
when the spec includes frontend tests, that suite — using the binding commands in
`MEMORY.md → Development commands` (everything runs through `docker compose`) ·
technical decisions justified with the discarded alternative · which RF each part
covers. Keep the design as simple as the RFs allow; add a dependency only if it makes
the implementation shorter or safer.

## Tasks (tasks.md)

```
- [ ] **T1. <Description>.** RF-x, RF-y
  - Done when: <verifiable check>.
```

Tasks are coherent units of work in dependency order, sized **proportionate to the
increment's risk**: a low-risk increment (tooling, simple logic) needs few, slightly
larger tasks; a risky one (security, data integrity, integrations) needs more, smaller
ones.
Never split work just to hit a count — split when a task stops having a crisp,
single "Done when". As a guardrail, more than ~10 tasks usually means the spec
should be split.

## Implementation

One task at a time (C17): inspect Git first and never overwrite existing work; write
the tests first (red), then the code; run build, typecheck, and tests **only** with the
commands documented in `MEMORY.md → Development commands` (RSpec on the backend; the
frontend suite only if one exists — never assume it). When the task's criteria are met
and the relevant validations have actually passed, update `tasks.md`, then create a
single task-specific commit including the implementation, its tests, and the tasks.md
update. If a validation fails, foreign changes appear, or it is unclear which files
belong to the task, stop without committing and explain the problem. Never start the
next task.
