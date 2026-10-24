# Tasks 006 — Deploy (Live deployment)

Derived from the approved `spec.md` (RF-1…RF-8, NFR-1…NFR-4, edge cases, DoD) and
the user-approved `plan.md` (file surface, deploy strategy, D-P49…D-P56, local
rehearsal, Render implications, external verification matrix).

Approvals verified before generating this file:

- `spec.md` → `Status: approved`.
- `plan.md` → `Status: approved` (user's explicit approval; status header updated
  in the session that generated this file).

Rules:

- One task = one task-specific commit (C17). T3, T6, and T7 are verification/user
  tasks with no commit (evidence lives in the session/validation — same rationale
  as spec 003's T3–T5 and spec 005's T6).
- Repo-side checks use only `MEMORY.md → Development commands` (everything via
  `docker compose`; RSpec mandatory). Nothing runs node/ruby on the host. The
  root-image build/rehearsal (T1/T3) uses plain `docker build`/`docker run`
  against **ephemeral** containers, a dedicated network, and host port **3999** —
  never the compose project, its containers, or the `db_data` dev volume (NFR-1/C7).
- Nothing outside the plan's file surface changes: no edits to
  `docker-compose.yml`, `backend/Dockerfile`, `frontend/Dockerfile`,
  `frontend/vite.config.ts`, `frontend/package.json`, `backend/config/database.yml`,
  `backend/config/initializers/cors.rb`, `backend/config/puma.rb`,
  `backend/config/routes.rb` (five routes stay — the health check reuses one),
  `backend/db/seeds.rb`, `.github/workflows/ci.yml` (zero edits — 003's required
  check stays the deploy gate), or any existing test (the 181 backend examples and
  57 frontend tests stay green untouched). If reality contradicts the plan (e.g. a
  platform mechanic can't work as planned), **stop and report** (C2) — never
  silently adapt.
- Hard STOP conditions (report to the user, never work around): Render demands a
  card or a paid plan (NFR-4); Render does not pass service env as Docker build
  args so `VITE_API_BASE_URL` cannot reach the image build (RF-3 needs a user
  decision); Render requires migrations in a release command (deviation from
  D-P52 → report, never a silent change).
- Dependency order: T1 → T2 → T3 → T4 → T5 → T6 → T7. The riskiest piece (the
  production image) lands first and is proven offline (T3) **before** any Render
  action (T6); documentation (T4/T5) needs no platform access; the first deploy
  only happens after the repo deliverables exist; the external matrix (T7) is the
  last gate.

## Tasks

- [ ] **T1. Root multi-stage `Dockerfile` + `.dockerignore` — the single production
  image (D-P49, D-P53; RF-1, RF-2, RF-3, RF-4, RF-6, RF-7, NFR-2/C16).**
  New `Dockerfile` at the repo root per the plan's sketch: stage 1 `node:22`
  (`npm ci` from `frontend/package-lock.json`, `ARG VITE_API_BASE_URL` with the
  fail-fast guard that fails the build loudly when the value is missing, then the
  exact `npm run build` — `tsc -b` + Vite); stage 2 `ruby:3.3` (`libpq-dev`,
  `bundle install`, `COPY backend/`, `COPY --from=frontend /app/dist ./public/`,
  `EXPOSE 3000`, `CMD` = `bin/rails db:prepare db:seed && exec bundle exec puma
  -C config/puma.rb`). New root `.dockerignore`: `.git`, `.env`/`.env.*`,
  `**/node_modules`, `frontend/dist`, `backend/tmp`, `backend/log`,
  `backend/config/master.key`, `backend/config/credentials.yml.enc` — secrets and
  host artifacts never reach the image or the build context (C16). The dev
  Dockerfiles and compose stay untouched (NFR-1). RF-1 (production build),
  RF-3 (build-time value + loud failure), RF-2/RF-4 (boot chain + runtime env),
  RF-6 (`db:prepare db:seed` on every start), RF-7 (`public/` served by the app),
  NFR-2
  - Done when: from the repo root
    `docker build -t inventory-prod-sim --build-arg VITE_API_BASE_URL=http://localhost:3999 .`
    succeeds, and the guard drill `docker build .` (no build arg) **fails** with
    the `VITE_API_BASE_URL build arg is required` message; `git status` shows only
    the two new files; and the binding battery is green with compose untouched —
    `docker compose up -d --build`,
    `docker compose exec backend bundle exec rspec` (181 examples),
    `docker compose run --rm frontend npm test` (57),
    `docker compose exec frontend npm run build` — as one task-specific commit.

- [ ] **T2. `production.rb`: three one-line adjustments (D-P55; RF-5, RF-7, edge
  cases).** In `backend/config/environments/production.rb`, exactly three
  changes: (1) `public_file_server.headers` cache-control →
  `public, max-age=0, must-revalidate` (a merge must be visible immediately;
  hashed assets revalidate cheaply via 304 — keeps a cached `index.html` from
  pointing at removed hashed assets); (2) `silence_healthcheck_path` →
  `/api/v1/products` (the real probe path; `/up` does not exist); (3)
  `active_storage.variant_processor = :disabled` (Rails-suggested value for the
  observed per-boot warning; no variants are generated). Nothing else:
  `assume_ssl`/`force_ssl`/STDOUT logging/static serving are already correct per
  the plan's verified facts. RF-5 (latest code visible on merge), RF-7
  (health-path silence, serving verified), edge cases (probe answered 200, no 301)
  - Done when: `git diff` on `backend/config/environments/production.rb` shows
    only those three adjustments, dev is unaffected (`RAILS_ENV`/compose configs
    untouched), and `docker compose exec backend bundle exec rspec` is green —
    as one task-specific commit. The header's live effect is proven in T3.

- [ ] **T3. Local rehearsal of the whole production path, offline (plan's Test
  strategy; RF-1, RF-3, RF-4, RF-6, RF-7, D-P52/D-P55 mechanisms; no commit).**
  Before touching Render, prove the image, boot chain, seeds, serving, CORS, and
  cache policy against a throwaway PostgreSQL — exactly the plan's sequence,
  isolated from the dev stack: `docker network create inv-prod-sim`; ephemeral
  `postgres:16` container `pg-sim` on that network; build the T1 image; run
  `app-sim` on host port **3999** with `RAILS_ENV=production`, a generated
  `SECRET_KEY_BASE`, `DATABASE_URL` pointing at `pg-sim`, and
  `FRONTEND_ORIGIN=http://localhost:3999`; then the curl battery. Also re-run the
  T1 guard drill (missing build arg → build fails). Tear down everything
  (`app-sim`, `pg-sim`, `inv-prod-sim`) and confirm the dev stack is intact.
  RF-1, RF-3, RF-4, RF-6 (boot-time provision + idempotent seed), RF-7
  - Done when: against `http://localhost:3999` the plan's checks all answer as
    expected — `/` → `200` (production `index.html`); `curl -sI /` cache-control
    is the must-revalidate policy, **not** `max-age=31536000`; `/api/v1/products`
    → `200` seeded with **no** `301`; `curl -sI -H 'Origin: http://localhost:3999'`
    on the API echoes `access-control-allow-origin: http://localhost:3999`
    (never `*`); `/docs` → `200`; cleanup commands
    run clean and `docker compose ps` shows the dev stack unaffected (dev data
    intact) — verification recorded in the session, **no repo commit**.

- [ ] **T4. `.env.example`: the two production-only variable names (D-P54; RF-4,
  NFR-2/C16).** Add `SECRET_KEY_BASE` (required at production boot — proven by
  the plan's boot evidence) and `RAILS_ENV=production` as **names with placeholder
  values** and a "production deploys only" comment, matching how `DATABASE_URL`
  is already documented. No real values anywhere (they live only in Render's
  dashboard). RF-4 (provision leg), NFR-2
  - Done when: `.env.example` lists both names with placeholders and the
    production-only note, contains no real value, and `git diff --stat` shows
    `.env.example` as the only modified file — as one task-specific commit.

- [ ] **T5. README: the deployment section (RF-8, C17; D-P50/D-P51/D-P56).**
  New section **"Despliegue (spec 006 — Render)"**: the public URL pattern (one
  origin: UI `/`, API `/api/v1/products`, docs `/docs`); the update flow (merge
  to `main` → automatic deploy, gated by 003's required `CI` check — no manual
  steps); provisioning from scratch (services, env vars before the first build,
  health check path); the **names** (never values) of `RAILS_ENV`, `DATABASE_URL`,
  `FRONTEND_ORIGIN`, `VITE_API_BASE_URL`, `SECRET_KEY_BASE`; Render's free-tier
  limits with the figures the user already verified (render.com/pricing
  2026-10-24: 5 GB bandwidth/mo then $0.15/GB, 500 build minutes/mo then $5/1K,
  512 MB RAM / <1 CPU Compute Free, 256 MB RAM / 100 connections Postgres Free,
  no card at signup → no charge possible) **plus the signup-verification gates
  still open** (spin-down/cold start with the fixed **90 s** bound, free-Postgres
  expiry, env-as-build-args, release-command/health-check-field mechanics —
  documented as the plan's to-verify table, updated after T6/T7 with the measured
  values). Retire the known limitation "the frontend is served with the Vite dev
  server" (now false), flip the `006 — Deploy` bullet under *Mejoras Futuras* to
  delivered, and add `Dockerfile`/`.dockerignore` to the structure tree. Local
  `docker compose` instructions stay exactly as they are (RF-8/NFR-1). Documentation
  only; no code or test changes. RF-8, NFR-2, NFR-4 (documented limits), C17
  - Done when: the section is coherent with T1–T4 and the plan (same names, same
    flow, same limits figures, open gates listed as open until T6/T7 close them),
    the Vite-dev-server limitation is gone, every `docker compose` command printed
    in the README still matches `MEMORY.md → Development commands`, and
    `git diff --stat` shows `README.md` as the only modified file — as one
    task-specific commit. If T6/T7 verify measured values that differ (cold start,
    expiry), a small follow-up README commit records them (C17).

- [ ] **T6. Render signup, provisioning, and first deploy (user action with the
  coordinator — D-P51 plan implications; RF-4, RF-5, NFR-4; no commit).**
  Done with the user, in the plan's order: (1) create the Render Hobby workspace
  **without adding a credit card** — if a card or paid plan is demanded, **STOP
  and return to the user** (NFR-4, never a silent upgrade); (2) connect the
  GitHub repository through Render's GitHub integration with **Auto Deploy on,
  deploy branch `main`, PR preview environments off**; (3) create the web service
  (Docker runtime, root `Dockerfile`) and the managed PostgreSQL in one project,
  and enter the env vars **before the first build**: `SECRET_KEY_BASE`
  (user-generated, e.g. `openssl rand -hex 64`; value only in Render — C16),
  `RAILS_ENV=production`, `FRONTEND_ORIGIN` and `VITE_API_BASE_URL` (= the
  assigned `*.onrender.com` URL; `DATABASE_URL` injected by Render); (4) set the
  health-check path `GET /api/v1/products`; (5) trigger/allow the **first deploy
  from `main` with green CI** (003's required check). While at it, confirm the
  signup-verification gates: env vars passed as Docker build args (if not →
  **STOP**, RF-3 decision), platform-provided `PORT` honored, release-command
  behavior (a required release-command migration → **report**, D-P52), health
  check fields, spin-down/cold start, free-Postgres expiry. Record every outcome
  (including any STOP) for the coordinator's `MEMORY.md` hand-off. RF-4, RF-5,
  NFR-4, edge cases (URL assigned; probe mechanics)
  - Done when: the user confirms with evidence (panel screenshots or session
    notes) that the account exists with **no card and no charge**, GitHub is
    connected with auto-deploy `main`-only and previews off, both services exist
    with the four env vars set before the first build, the health-check path is
    `/api/v1/products`, the first deploy from `main` completed with green CI, and
    every to-verify gate is confirmed or a STOP is reported — before `/sdd-validate
    006-deploy` runs; no repo commit.

- [ ] **T7. External verification matrix and DoD battery (coordinator/user —
  D-P56; RF-1…RF-7, DoD, NFR-1, NFR-4, cold-start edge; no commit).** Run the
  plan's external matrix against the public URL: RF-1 (UI 200 production build —
  references `/assets/…` hashed files, **no** `/@vite/client`, **no** `localhost`;
  API 200 `{ data, meta }`); RF-2 (full curl CRUD: 201 → 200 → 422 with per-field
  `details` → 404 C10 shape → 204 delete; server-side `page`/`q`/`active`;
  coordinator browser: a UI-created product still GETs 200 after a redeploy, with
  confirmations/states — C15); RF-3 (exact `access-control-allow-origin` echo,
  never `*`; coordinator browser: UI operations complete with an **empty
  console**); RF-4 (repo grep: no secrets/values; names only in README and
  `.env.example`; dashboard holds the values); RF-5 (merge to `main` → deploy
  reaches the URL; a feature-branch commit → no deploy, URL unchanged); RF-6
  (soft-delete a demo product via the UI → redeploy → it reappears under a **new
  id**; search shows no duplicates; an API-created product untouched); RF-7
  (`/docs` and `/docs/openapi.yaml` → 200; try-it-out executes a real request —
  coordinator browser, D-13); NFR-1 (binding battery green, and `git diff` shows
  `ci.yml`/`docker-compose.yml` untouched); NFR-4 (README limits = the verified
  figures plus what T6 verified; any STOP recorded); cold-start edge (after a
  spin-down, `curl --max-time 90 … $UI` → **200** within the fixed 90 s bound).
  Then the binding local battery on the final state and CI green on the PR.
  RF-1, RF-2, RF-3, RF-4, RF-5, RF-6, RF-7, RF-8 (coherence), NFR-1, NFR-4,
  DoD, edge cases
  - Done when: every matrix row has recorded evidence (curl outputs/screenshots)
    meeting the plan's expectations, the cold start answered 200 within 90 s, the
    binding battery
    (`docker compose up -d --build` · rspec · `npm test` · `npm run build`) is
    green, the required `CI` check is green on the PR with `ci.yml` untouched —
    and any measured figure that differs from the plan's assumption (cold start,
    expiry) has a follow-up README commit (T5's rule) — all recorded before
    `/sdd-validate 006-deploy`; **no repo commit of its own** (verification only).

## Final check (before `/sdd-validate`)

The DoD battery runs together as the last gate (004/005's pattern — verification
without a code change has no commit); CI (spec 003) repeats the suites on the PR
with run-all semantics; the required check is `CI`.

```sh
docker compose up -d --build
docker compose exec backend bundle exec rspec     # 181 examples, must stay green
docker compose run --rm frontend npm test         # 57/57, unchanged (C7/NFR-1)
docker compose exec frontend npm run build        # tsc + vite, unchanged
```

The external legs (public URL, browser, redeploy, cold start) are T6/T7's
evidence (D-P56).

## RF coverage

| Task | RFs / NFRs / DoD |
|---|---|
| T1 | RF-1 (production image), RF-2/RF-4 (boot + runtime env), RF-3 (build ARG + loud guard), RF-6 (`db:prepare db:seed` CMD), RF-7 (static `public/`), NFR-2/C16 |
| T2 | RF-5 (merge visible immediately), RF-7 (health-path silence), edge cases (probe 200 not 301; boot-warning noise) |
| T3 | RF-1, RF-3, RF-4, RF-6, RF-7 mechanisms proven offline (plan rehearsal), D-P52/D-P55 live legs |
| T4 | RF-4 (provision leg: names only), NFR-2/C16 |
| T5 | RF-8 (URLs, flow, provisioning, env names, retired limitation, limits + open gates), NFR-4 (documented limits), C17 |
| T6 | RF-4 (provider env), RF-5 (main-only auto-deploy, first deploy, CI gate), NFR-4 (budget gate, signup verification), edge cases (URL, build args, release command, health check) |
| T7 | RF-1…RF-7 external matrix, RF-8 coherence, NFR-1 (suites + untouched `ci.yml`/compose), NFR-4, DoD, cold-start edge (90 s) |
