# MEMORY.md

Stable context, decisions, open decisions, and terminology for **Inventory
Management** (Full Stack challenge). The coordinator owns this file — the only agent
that edits it. Review it at the end of every session and update it when there is
relevant new or changed information (decisions, open decisions, project status,
lessons, or development commands); skip routine passes with nothing new.

## Project status

**Inventory Management** — product CRUD challenge (Rails API + React/TS).
**Backend implemented and validated (spec 001); spec 002 (frontend) implementing:
T1–T6 done and committed on `feature/002-frontend-ui`; T7 interrupted mid-task
with uncommitted changes.**

- **Constitution established:** `docs/constitution.md` is official and approved —
  C1–C17, no amendments pending. No ADRs in this project: decisions live here (C4).
- Foundation in place: `AGENTS.md`, `MEMORY.md`, `specs/README.md`, `.opencode/`
  (9 `/sdd-*` commands, 4 agents, 2 skills), `docs/Reto técnico.pdf` (source of
  truth, C2), `.gitignore`.
- **Next (session 2026-10-22):** spec 002 is **complete: validated
  (`VEREDICTO: APROBADO`, 1 correction round → `ad304ac`), docs closed, pushed to
  origin, and the full T9 browser smoke passed 9/9** — flows via the OpenCode
  browser (create/edit/422-aria/confirm/Escape/delete/clamp/backend-down +
  Lighthouse a11y 100) and responsive breakpoints via the `agent-browser` skill
  (`set viewport 480 800` → cards shown/table hidden, `1200 800` → inverse, back
  and forth). **PR #2 is open** (https://github.com/diegosym/inventory-management/pull/2,
  awaiting merge); specs 003–006 start per roadmap after that. React skill per
  NFR-3 throughout.

## Key definitions (what is settled)

- **Source of truth:** the statement `docs/Reto técnico.pdf`; mandatory before
  optional (C2, C7). Core = specs 001–002; bonus = 003–006.
- **Agreed stack:** Rails (API mode) + PostgreSQL + RSpec · React + TypeScript +
  Tailwind CSS · everything through `docker compose`, no local Ruby/Postgres/Node
  (C8).
- **Optional libraries:** React Query, Vitest, component libraries are **not
  requirements** — adopted only when they clearly simplify the work and the decision
  is recorded here *before* code (C6).
- **Process:** SDD spec → plan → tasks → implementation → validation with user
  approval gates; **one task = one specific commit** (C17); traceability requirement →
  spec → task → test → commit (C3).
- **Quality floor:** validations in the model (C9), error contract 404/422/500 (C10),
  server-side pagination/search/filter (C11), frontend mirror rule (C14), UI states +
  confirmations + responsive (C15), no secrets committed (C16).
- **SKU format:** uppercase letters, numbers, **and hyphens** on both sides (D-6,
  closes OD-1).

## Roadmap (specs)

| Spec | Scope | Status |
|---|---|---|
| `001-backend-api` | Product model, validations, 5 endpoints, pagination/search/filter, seeds, RSpec | implemented + validated (PR) |
| `002-frontend-ui` | List, form (modal), delete + confirmation, loading/error/empty states, responsive, Tailwind, README, frontend tests | implemented + validated + browser smoke 9/9 (`ad304ac` fix round; suite 57/57, backend 90/0); **PR #2 open** |
| `003-ci` | GitHub Actions: RSpec + frontend tests (if present) + build | pending (bonus) |
| `004-data-integrity` | Soft delete + change audit | pending (bonus) |
| `005-openapi` | API documentation | pending (bonus) |
| `006-deploy` | Live deployment | pending (bonus) |

A spec starts only when the previous one is `VEREDICTO: APROBADO`.

## Stack (binding)

Rails (API mode) + PostgreSQL + RSpec · React + TypeScript + Tailwind CSS — **all
via `docker compose`** (C8). Additional libraries only per C6, with a decision
recorded here before code.

## Development commands

Binding verification before claiming a task done. Available **once the compose file
exists** (created in spec 001 scaffolding); until then there is nothing to run —
say so instead of inventing commands.

```sh
# run everything
docker compose up -d --build

# backend
docker compose exec backend bundle exec rspec
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bin/rails console

# frontend
docker compose run --rm frontend npm test       # frontend suite, when it exists
docker compose exec frontend npm run build      # tsc + vite build

# responsive / browser smoke (skill `.agents/skills/agent-browser`; CLI global
# installed under ~/.local/node-v24.22.1-darwin-x64 — host Node 13 unusable)
export PATH="$HOME/.local/node-v24.22.1-darwin-x64/bin:$PATH"
agent-browser open http://localhost:5173
agent-browser set viewport 480 800     # mobile: cards shown, table hidden
agent-browser set viewport 1200 800    # desktop: inverse
agent-browser eval "<js>"
agent-browser close

# stop
docker compose down
```

Environment notes:

- **First run:** `cp .env.example .env` — compose requires `POSTGRES_PASSWORD` (no
  secrets committed, C16).
- Images: `ruby:3.3` (already local), `postgres:16` and `node:22` (to pull).
- **Never run `ruby`, `bundle`, `rails`, `node`, or `npm` on the host**: host Ruby is
  2.6 and host Node is 13 — both unusable. Everything goes through compose.
- Docker Desktop must be running.

## Decisions

- **D-1:** runtime is 100% Docker (`docker compose`: db + backend + frontend).
  Discarded: `brew` Ruby/PostgreSQL (Intel/macOS Tier 3, host pollution) and native
  `~/.local/node22` (fallback only, outside compose).
- **D-2:** TailwindCSS as the CSS framework (the statement allows any; Tailwind is
  the lightest to set up with Vite).
- **D-3:** frontend libraries (Vitest, React Query) are optional candidates, not
  requirements: adopt only if a spec justifies them and the decision is recorded here
  before code (C6).
- **D-4:** iterative delivery: core (001–002) first, then bonus from simplest to most
  complex (003 CI → 004 data integrity → 005 OpenAPI → 006 deploy); each spec starts
  only after the previous one is approved.
- **D-5:** repo layout `backend/` + `frontend/` with `docker-compose.yml` at the root
  — delivery requirement of the statement.
- **D-6 (closed — closes OD-1):** the SKU is **required and unique**. It is
  **normalized to uppercase before validation and storage** and may only contain
  ASCII letters `A-Z`, digits `0-9`, and hyphens `-` (no spaces): `\A[A-Z0-9-]+\z`,
  applied with the **same rule in backend and frontend** (C14) — Rails is the final
  authority, and uniqueness is backed by a unique index in PostgreSQL. Normalization
  example: `abc-123` → `ABC-123`. Valid: `ABC123`, `ABC-123`, `A-1`. Invalid:
  `ABC 123`, `abc@123`, `ÁBC123`.
- **D-7 (spec 001, approved with the plan):** API contract details that spec 002 must
  mirror — error shape `{ "error": { code, message, details } }` (`details` only on
  422, keyed by field); listing/search params `q` (+ `page`, `active`), success
  envelope `{ data, meta: { current_page, total_count, total_pages } }`; `price`
  serialized as a decimal string (`"49.99"`); compose ships `db` + `backend` in 001,
  with the `frontend` service added in 002; gems: `pg`, `rack-cors`, `rspec-rails`,
  `factory_bot_rails` (no Kaminari/Pagy/Faker — C6).
- **D-8 (branch workflow):** each spec is implemented on its own branch
  `feature/<spec-name>` (first: `feature/001-backend-api`); when the spec is fully
  implemented and validated, the branch goes to `main` via a pull request.
- **D-9 (spec 001, mirror notes for 002):** frontend must replicate exactly — the
  `price` validation message `"must have at most 2 decimal places"` (key `price`);
  `active` must be sent as a JSON boolean (raw-value validation rejects `"yes"`);
  **precision (T9 gate, 2026-10-22):** the 422 "no `{ "product": … }` envelope"
  applies to an **empty/absent body** (validated by spec 001's RSpec); a JSON body
  with top-level product keys is accepted as 201/200 because Rails API mode's
  default `wrap_parameters` folds them into `params[:product]` — behavior of the
  approved spec 001 backend, unchanged; the frontend always sends the envelope so
  the mirror rule is unaffected; CORS is restricted to `/api/v1/*` with
  `FRONTEND_ORIGIN` (default `http://localhost:5173`).
- **D-10 (spec 002, approved with the spec):** frontend test stack = **Vitest +
  React Testing Library** (RF-14, suite via `docker compose run --rm frontend npm
  test`) — recorded before code per C6/D-3; **React Query and react-router are NOT
  adopted**: plain `fetch` and a single-view modal UI (C6, user decision). Also from
  the spec approval: search debounce ~300 ms (server-side `q`, resets to page 1),
  literal save-confirmation dialog before every create/edit, and RF-12 accessibility
  (labels/error association/keyboard) in scope (user).
- **D-11 (spec 002, interpretation of NFR-4):** NFR-4 is satisfied with the
  **env-driven API base URL** (`VITE_API_BASE_URL`) plus the **documented fixed
  dev-server origin default `http://localhost:5173`** — RF-1 of the same spec pins
  that default and CORS already defaults to it (D-9). The dev-server host/port stays
  in `vite.config.ts` and does not go through env vars. User-approved ruling; no
  plan amendment needed.
- **D-13 (tooling, 2026-10-22, user-requested):** the **`agent-browser` skill**
  (vercel-labs/agent-browser) is the project's browser-automation/responsive-smoke
  tool — installed via the `skills` CLI (`.agents/skills/agent-browser` +
  `skills-lock.json`, committed) with its global CLI + Chrome for Testing under
  `~/.local/node-v24.22.1-darwin-x64` (PATH prepend). It does not touch the app
  stack (C8 unaffected): verification tooling only, used for T9's viewport checks.
- **D-12 (spec 002, mirror source of truth):** the frontend mirrors the **live
  backend messages of 001** (`backend/app/models/product.rb` + its specs), not the
  prose examples of the plan (erratum found in plan D-P18 during T2 and corrected):
  blank `price`/`stock` → `"is not a number"`, `name` >100 → `"is too long (maximum
  is 100 characters)"`, negative price → `"must be greater than 0"` (validation
  order: numeric → >0 → ≤2 decimals). C14/RF-6 prevail over plan examples.

## Open decisions (OPEN DECISION)

- **OD-2.** Audit "who" (spec 004): there is no authentication in this challenge, so
  the actor must be defined (IP, `X-User` header, or system). Deferred to 004.
- **OD-3.** Deploy provider (spec 006): Railway vs Render vs Vercel. Deferred to 006.
- ~~OD-1.~~ **Closed by D-6** (SKU charset: uppercase + digits + hyphens on both sides).

## Terminology

- **Core** — specs 001–002, the mandatory challenge scope.
- **Bonus iteration** — specs 003–006, additive and individually deliverable.
- **Binding verification** — the commands above; a task is not done until they pass
  and its commit exists (C17).
- **Mirror rule** — frontend validations replicate the backend exactly (C14).

## Lessons learned

- Do not edit `MEMORY.md` in parallel with an implementer task: the uncommitted note
  blocks the implementer's git-status check (it stopped T2 correctly); batch MEMORY
  updates between tasks or into the task's own docs commit.
- Agent permission allowlists (`edit: * → deny` + explicit allows in
  `.opencode/agents/*.md`) can stall a task when its file surface exceeds the
  allowlist (T8 needed root `README.md`, initially denied). When a task needs a
  path outside the allowlist, fix the agent frontmatter first (user-approved) —
  neither coordinator nor subagents can edit agent config themselves (by design).
- The implementer cannot run visual browser smoke (no desktop browser connected);
  UI-heavy Done-when items should plan for a user-run smoke or an explicit waiver —
  or use the tooling that solves it: the coordinator's smoke completed 9/9 with the
  built-in OpenCode browser (flows) + `agent-browser set viewport` (breakpoints);
  no user window resizing was needed after all.
- Host tooling limits: Node 13 on PATH is unusable and `~/.local/node22`'s npm is
  broken; `~/.local/node-v24.22.1-darwin-x64` works with a PATH prepend. Modern
  CLIs that need Node ≥22 (e.g. the `skills` installer) run inside
  `docker run --rm -v "$PWD":/repo -w /repo node:22 npx -y …` with
  `--agent '*' -y` for non-interactive installs.
