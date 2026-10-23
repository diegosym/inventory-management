# MEMORY.md

Stable context, decisions, open decisions, and terminology for **Inventory
Management** (Full Stack challenge). The coordinator owns this file — the only agent
that edits it. Review it at the end of every session and update it when there is
relevant new or changed information (decisions, open decisions, project status,
lessons, or development commands); skip routine passes with nothing new.

## Project status

**Inventory Management** — product CRUD challenge (Rails API + React/TS).
**Core complete: specs 001 (backend) and 002 (frontend) both implemented,
validated, and merged to `main`.**

- **Constitution established:** `docs/constitution.md` is official and approved —
  C1–C17, no amendments pending. No ADRs in this project: decisions live here (C4).
- Foundation in place: `AGENTS.md`, `MEMORY.md`, `specs/README.md`, `.opencode/`
  (9 `/sdd-*` commands, 4 agents, 3 skills: `sdd`, `ruby-rails`,
  `vercel-react-best-practices`), `.agents/skills/agent-browser` (D-13),
  `docs/Reto técnico.pdf` (source of truth, C2), `.gitignore`.
- **Next (session 2026-10-23):** spec **005-openapi validated — `VEREDICTO:
  APROBADO`** (T1–T6 + fix `c173a3f` from the browser smoke; RSpec **181/0**
  incl. the 57-example anti-drift suite with 25 live replays and the drift drill;
  UI try-it-out smoke done with a real 422 and a same-origin-only network log).
  **Remaining: push + PR (CI runs there) + merge**, then MEMORY final sync; an
  optional `/sdd-change` could fix spec RF-2:65's `stock`-in-POST wording (settled
  by D-19 as an erratum — user's call). Next spec: `006-deploy` (last bonus;
  OD-3 provider decision there). React skill NFR-3; agent-browser for smoke.

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
| `001-backend-api` | Product model, validations, 5 endpoints, pagination/search/filter, seeds, RSpec | **done — merged to `main` (PR #1)** |
| `002-frontend-ui` | List, form (modal), delete + confirmation, loading/error/empty states, responsive, Tailwind, README, frontend tests | **done — merged to `main` (PR #2, `f351a0a`)**: validated + browser smoke 9/9 (suite 57/57, backend 90/0) |
| `003-ci` | GitHub Actions: RSpec + frontend tests (if present) + build | **done — merged to `main` (PR #3, `c44e83b`)**: validated `VEREDICTO: APROBADO` (T1–T5: live runs incl. run-all drill, required check `CI` active, push-trigger run green) |
| `004-data-integrity` | Soft delete + change audit | **done — merged to `main` (PR #5, `372f995`)**: validated `VEREDICTO: APROBADO` (124/0; 1 authorized 001 adaptation; frontend untouched; push-trigger CI green) |
| `005-openapi` | API documentation | **validated `VEREDICTO: APROBADO`** (T1–T6 + post-smoke fix `c173a3f`; suite 181/0 incl. 57 anti-drift; UI self-contained try-it-out smoke done) — PR pending |
| `006-deploy` | Live deployment | pending (bonus) |

A spec starts only when the previous one is `VEREDICTO: APROBADO`.

## Stack (binding)

Rails (API mode) + PostgreSQL + RSpec · React + TypeScript + Tailwind CSS — **all
via `docker compose`** (C8). Additional libraries only per C6, with a decision
recorded here before code.

## Development commands

Binding verification before claiming a task done — all via `docker compose`
(the compose file exists since spec 001's scaffolding).

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

- **First run:** `cp .env.example .env` **only if `.env` does not exist yet** —
  a copy would overwrite `POSTGRES_PASSWORD` and break auth against the existing
  `db_data` volume (README T8 documents this caveat). No secrets committed (C16).
- Images (`ruby:3.3`, `postgres:16`, `node:22`) are already local.
- **Never run `ruby`, `bundle`, `rails`, `node`, or `npm` on the host**: host Ruby is
  2.6 and host Node is 13 — both unusable. Everything goes through compose (the
  documented `~/.local` Node installs are tooling-only fallbacks, see D-13/Lessons).
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
- **D-12 (spec 002, mirror source of truth):** the frontend mirrors the **live
  backend messages of 001** (`backend/app/models/product.rb` + its specs), not the
  prose examples of the plan (erratum found in plan D-P18 during T2 and corrected):
  blank `price`/`stock` → `"is not a number"`, `name` >100 → `"is too long (maximum
  is 100 characters)"`, negative price → `"must be greater than 0"` (validation
  order: numeric → >0 → ≤2 decimals). C14/RF-6 prevail over plan examples.
- **D-13 (tooling, 2026-10-22, user-requested):** the **`agent-browser` skill**
  (vercel-labs/agent-browser) is the project's browser-automation/responsive-smoke
  tool — installed via the `skills` CLI (`.agents/skills/agent-browser` +
  `skills-lock.json`, committed) with its global CLI + Chrome for Testing under
  `~/.local/node-v24.22.1-darwin-x64` (PATH prepend). It does not touch the app
  stack (C8 unaffected): verification tooling only, used for T9's viewport checks.
- **D-14 (spec 003, approved with the plan):** CI executes the **same documented
  `docker compose` commands as local** (RSpec · Vitest · build — local/CI parity,
  C8; referenced by RF-4) with **non-secret `POSTGRES_*` literals in the workflow's
  `env:`** (NFR-1/C16; no `.env` on the runner, no GitHub `secrets`, compose `:?`
  untouched). The only delta in CI: `exec`/`run` carry `-T` because runners have no
  TTY (plan D-P29) — same images, same compose, same suites. Run-all on failure is
  a spec requirement (RF-3, mechanism D-P26).
- **D-15 (closes OD-2; user decision, spec 004):** the audit actor is the constant
  `"system"` for every change — API-driven and server-side (seeds) alike: with no
  authentication (C2) the audit targets the action, the date, and what changed, not
  a faked identity (C5); the `actor` field stays ready to carry a real actor if
  authentication ever arrives. Recorded in `specs/004-data-integrity/spec.md` RF-7.
- **D-16 (user decisions at spec 004 QA):** (a) re-running `db:seed` **resurrects
  a soft-deleted demo product with a new id** — 001 RF-15's idempotence is scoped
  to non-deleted products (004 supersedes 001 in two points, C3); (b) a **delete
  audit entry carries only product id, action, timestamp, and actor** — no field
  values or snapshot (C5); (c) "changed" for updates is judged on **persisted
  values** (equivalent payloads record no entry — exact before/after
  representation deferred to `plan.md`); (d) only spec-001 tests encoding the
  superseded permanent-delete semantics may be adapted; every other test of
  001/002/003 must stay green untouched (C7).
- **D-17 (spec 005, user decisions approved with the spec):** (a) the OpenAPI
  document lives in the **repo and is served raw by the API** at a fixed URL
  (RF-4); (b) an **interactive docs UI is in scope** at a fixed backend-origin
  path (plan proposes; `/docs` referenced) rendering the served document — single
  source of truth — with real try-it-out requests, **self-contained: assets served
  by the application, no CDN/external network in the browser at runtime** (RF-5);
  (c) the document **includes a 500 example** (generic C10 shape) and documents a
  syntactically invalid JSON body **as implemented — 500 `internal_error`**
  (observed live); RF-6 replay covers reproducible examples only, with the generic
  500 verified by simulation (001 RF-16 precedent) and the served document
  byte-identical to the committed file. **Supersession (C3):** 001 RF-3 and 004
  RF-5 ("five routes") superseded one point each — route surface grows by the doc
  route (RF-4) + UI route (RF-5). **Gate (C6):** the UI mechanism and ANY new
  dependency or asset bundle require a MEMORY decision **before code** — plan
  proposes, coordinator records.
- **D-18 (spec 005, C6 gate approved with the plan):** **vendor the
  `swagger-ui-dist` bundle — 3 static assets, pinned version, committed under
  `backend/public/docs/swagger-ui/`** — for the self-contained interactive docs
  UI (RF-5). Why: real try-it-out rendering with **zero changes to
  Gemfile/package.json**, no network at build or runtime (no CDN), frontend
  untouched; obtained once from the official npm tarball via `docker run …
  node:22`. Discarded: gems `swagger-ui`/`rswag` (dependency + coupling),
  `swagger-ui-react` (wrong origin), CDN (user veto, D-17b), hand-rolled
  renderer (fallback only). Rest of plan: D-P40…D-P48 (OpenAPI 3.0.3 YAML at
  `backend/public/docs/openapi.yaml`, static serving, anti-drift spec with stdlib
  YAML + integration replay, UI smoke assigned to the coordinator — D-13).
  **Plan note (T4):** the anti-drift spec parses the YAML **twice per run**
  (load-time, to define one example per documented example — keeps failure
  granularity — plus `before(:context)`) instead of D-P43's single parse; both
  stdlib, no perf concern. **Vendor note (T2):** `swagger-ui-dist` ≥5.34 tarballs
  are flat (`package/`, no `package/dist/`), and since 5.34 the standalone preset
  no longer auto-registers — `index.html` must pass
  `presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset]` (found by
  the T6 browser smoke, fixed in `c173a3f`).
- **D-19 (spec 005 RF-2 erratum, user decision during T1):** in **`POST`**, the
  genuinely required fields are **`name`, `sku`, `price`** — `stock` is
  **optional with column default `0`** (sending `null` → 422 `"is not a number"`).
  The live code and 001's approved suite are the source of truth (C9/
  Definitions: `stock integer, default: 0, null: false`); RF-2:65 enumerates
  `stock` as required in one wrong word while mandating "as the model implements
  it" — the document documents the code. **`PUT` is unchanged**: omitted required
  field → 422 (full replacement). Verified live during T1's stop (C2), settled by
  the user; no `/sdd-change` — this note is the erratum.

## Open decisions (OPEN DECISION)

- **OD-3.** Deploy provider (spec 006): Railway vs Render vs Vercel. Deferred to 006.
- ~~OD-1.~~ **Closed by D-6** (SKU charset: uppercase + digits + hyphens on both sides).
- ~~OD-2.~~ **Closed by D-15** (audit actor: the constant `"system"`, user decision).

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
- The implementer's `edit` allowlist lacked `.github/**` (spec 003 created a new
  workflow file): the agent fell back to `shell` heredocs with the user's approval.
  Works, but future specs that create files in new top-level dirs should extend the
  allowlist first (user-approved) instead of relying on shell fallback.
- Rails 8.1 gotcha (verified live in the container during spec 004's planning):
  `UniquenessValidator#build_relation` starts from `klass.unscoped`, so a
  `default_scope` does **not** constrain uniqueness validation — scoped uniqueness
  needs an explicit `conditions:` option (plan D-P34).
