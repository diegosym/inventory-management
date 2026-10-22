# Specs — SDD flow

Single source of truth for **what** gets built. The skill `.opencode/skills/sdd/SKILL.md`
holds the templates and size rules; this file describes how the flow runs here.

## Order

```
Constitution → Spec → Clarification → Plan → Tasks → Implementation → Validation
   /sdd-constitution   /sdd-spec   /sdd-clarify   /sdd-plan   /sdd-tasks   /sdd-implement   /sdd-validate
```

Each arrow is an **approval gate owned by the user**. Agents never skip one.

## Folder layout

```
specs/
├── README.md              ← this file
├── 001-backend-api/
│   ├── spec.md            ← WHAT and WHY (EARS requirements, ≤ ~100 lines)
│   ├── plan.md            ← HOW (files, decisions with discarded alternative)
│   └── tasks.md           ← ordered units, each with RFs + "Done when:"
├── 002-frontend-ui/
└── …
```

## Roadmap (see MEMORY.md for the rationale)

| Spec | Scope | When |
|---|---|---|
| `001-backend-api` | Product model, validations, 5 endpoints, pagination/search/filter, seeds, RSpec | Core — first |
| `002-frontend-ui` | List, product form, delete with confirmation, states, Tailwind (extra libraries only if justified — C6) | Core — after 001 |
| `003-ci` | GitHub Actions: RSpec + frontend tests (if present) + build | Bonus — simplest first |
| `004-data-integrity` | Soft delete + change audit (together: same model, same endpoints) | Bonus |
| `005-openapi` | API documentation | Bonus |
| `006-deploy` | Live deployment | Bonus — last |

Rules:

- A spec only starts when the previous one is `VEREDICTO: APROBADO`.
- Core specs list the bonus items under **Out of scope**, pointing at their future
  spec — never implemented opportunistically.
- Statuses: `draft` → `approved` → `implemented`.

## Who does what

| Phase | Agent | Command |
|---|---|---|
| Coordinate the flow, update `MEMORY.md` | `coordinator` | `/sdd-status` |
| Draft spec / plan / tasks, propose constitution | `planner` | `/sdd-spec`, `/sdd-plan`, `/sdd-tasks`, `/sdd-change`, `/sdd-constitution` |
| QA review of spec, RF-by-RF validation | `reviewer` | `/sdd-clarify`, `/sdd-validate` |
| Implement ONE task, tests first | `implementer` | `/sdd-implement` |
