# AGENTS.md

Entry point and behavior contract for AI coding sessions.

**Read in this order:**

1. `AGENTS.md` (here)
2. `MEMORY.md` — stable context, decisions, open decisions, terminology
3. `docs/constitution.md` — non-negotiable principles (C1–C17)
4. As needed: `specs/README.md` and `specs/NNN-name/`

## Project status

**Inventory Management** — Full Stack challenge: product CRUD with a Rails API
(PostgreSQL) backend and a React + TypeScript + TailwindCSS frontend, everything
running in Docker. Constitution drafted, no application code yet.

Do not assume tooling, commands, versions, or layout beyond what `MEMORY.md`
documents.

## Hard rules (details in `docs/constitution.md`)

- **SDD gate:** no feature code without an approved spec in `specs/NNN-name/`.
- **Keep it simple (C5–C6):** the simplest code that satisfies the spec; a dependency
  only when it makes the implementation shorter or safer, recorded in `MEMORY.md`
  when the decision is relevant (C6).
- **Binding stack (C8):** Rails API + PostgreSQL + RSpec · React + TypeScript +
  Tailwind CSS, all via `docker compose`. Extra libraries (React Query, Vitest, …)
  only when they justify their complexity (C6); otherwise they stay out. New
  dependency or runtime outside
  Docker → record a decision in `MEMORY.md` **before** code.
- **Validations live in the model (C9)**; the frontend mirrors them exactly (C14).
- **Error contract (C10):** 404 / 422 / 500, one JSON shape.
- **Server-side listing (C11):** pagination (10/page), name search, `active` filter.
- Do not invent requirements — mark undecided items `OPEN DECISION` in `MEMORY.md`.

## SDD workflow (skill + commands)

The `sdd` skill (`.opencode/skills/sdd/SKILL.md`) is the **single source of truth**
for the SDD flow and templates (spec/plan/tasks, EARS, "Done when:"). All artifacts
are written in **English**; the user communicates in Spanish. The `ruby-rails` skill
holds Rails conventions.

| Command | Runs as | Does |
|---|---|---|
| `/sdd-constitution <text>` | `planner` | proposes an amendment to `docs/constitution.md` (user approval only; no ADRs, recorded in `MEMORY.md`) |
| `/sdd-spec 001-name <idea>` | `planner` | interviews (≤5 questions, batched) → drafts `spec.md` |
| `/sdd-clarify 001-name` | `reviewer` | QA review of the spec (detect only) |
| `/sdd-plan 001-name` | `planner` | drafts `plan.md` from the approved spec |
| `/sdd-tasks 001-name` | `planner` | drafts `tasks.md` from the approved plan (risk-, dependency- and coherence-sized; each with RFs and a `Done when:`) |
| `/sdd-implement 001-name T1` | `implementer` | implements ONE task, tests first, then stops |
| `/sdd-validate 001-name` | `reviewer` | RF-by-RF validation → VEREDICTO |
| `/sdd-change 001-name <need>` | `planner` | updates spec for a requirement change |
| `/sdd-status 001-name` | `coordinator` | current phase + exact next command |

**Approval gates are the user's:** spec, plan, and the final validation. Tasks are
generated from the approved plan — there is no separate task approval: before
implementing, the coordinator checks that `tasks.md` corresponds to that plan and that
its tasks are coherent and verifiable. Agents never skip them. Specs run in roadmap
order (`specs/README.md`): a spec starts only when the previous one is approved.

## Session protocol

1. **Start:** read the files above in order.
2. **Gate check before writing code:** approved spec exists in `specs/`?
   If no → do not implement; propose the spec first.
3. **Decision check:** does the change add a dependency, alter the API contract, or
   change the validation rules? If yes → record the decision in `MEMORY.md` **before**
   code.
4. **End of session:** review whether anything relevant changed — decisions, open
   decisions, project status, lessons, or development commands — and update
   `MEMORY.md` only when it did (the coordinator is its only editor; no routine
   passes with nothing new). Report per the format below.

## Rules of work

- **Mirror the validations.** Model rules are canonical; the UI repeats them exactly.
- **Server decides.** Pagination, search, and filters are computed by the API.
- **Keep it small.** No microservices, cloud infra, queues, or integrations beyond
  what the spec states; core before bonus (C7).
- **Small dependency set.** Justify every addition in `MEMORY.md` when it is relevant
  (C6).
- **No secrets in the repo.** Environment variables only (C16).
- **Documentation is a deliverable.** Specs and MEMORY updates land with the code
  they describe.

## Scope discipline

Constitution drafted; specs not started. Explicitly out-of-bounds until a spec says
otherwise:

- Any architecture change or dependency outside the binding stack (C8)
- Any feature not covered by an approved spec — including bonus items: they live in
  `003`–`006`, never sneaked into core

If asked to jump ahead, cite this section, explain the SDD gate, and propose the
missing specification instead.

While implementing: follow the spec exactly; if reality contradicts the spec, **stop
and ask** — deviations become recorded decisions in `MEMORY.md`. Match existing
structure and naming; keep diffs minimal.

## Report format (end of session)

```
Files created/modified:
Decisions established (with spec refs):
Open decisions changed:
Verification performed (commands run + results):
Blocked / needs approval:
```
