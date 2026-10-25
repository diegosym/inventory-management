# Spec 006 — Deploy (Live deployment)

Status: approved

## Context and goal

Final bonus increment (D-4; last roadmap item): "Deploy funcional (Heroku, Railway, Vercel, etc.)" of the
statement (`docs/Reto técnico.pdf`, C2) — the CD half spec 003 deferred here (C3 pointers from 001/002/005, no
supersession). Today the frontend runs on the Vite dev server (README limitation: the production build "arrives
with spec 006"). This spec delivers it: the exact application specs 001–005 validated, now **publicly reachable,
served as a production frontend build, against a persistent database, configured only through the deploy
provider's environment** (C16). **User decisions (this spec): the deploy provider is Render — settling `OD-3` in
`MEMORY.md` (coordinator records it, suggested D-20) — and the budget is free tier or minimum plan without a card
(NFR-4).**

**Why Render:** the evaluated alternative that hosts the frontend, the Rails API, and PostgreSQL on a single
provider with a free plan — Docker runtime, automatic deploys from GitHub, and a structure equivalent to the one
already planned for this deployment — chosen after verifying that the originally considered provider was closed
to registrations.

**Deploy shape:** one production image (production Vite build + Rails API) run on Render as a web service with
managed PostgreSQL; deploys flow from `main` with green CI (spec 003's required check); Render assigns the
public URL (`*.onrender.com`). The step-by-step strategy and the implications to prepare for this platform
(account and budget gate, GitHub connection, environment variables, health check, free-tier limits) live once in
the plan.

## Users

- Evaluator: opens a public URL and exercises the full CRUD without installing anything.
- Developer: ships to the public URL by merging to `main`, CI gate of spec 003 intact.

## User stories

- US-1. As an evaluator, I want the app live at a public HTTPS URL — production UI, real database — so I can test
  the challenge end to end.
- US-2. As a developer, I want merges to `main` to reach the deployment automatically, so the public URL always
  shows the latest approved code.
- US-3. As a maintainer, I want deployment configuration in provider environment variables, so the repository
  never carries secrets (C16).

## Definitions

- **The deployed application**: the React app served as a static production build, the Rails API in production
  configuration, and the PostgreSQL backing it — specs 001–005 unchanged plus a production frontend serving mode
  (the only new "what").
- **Public URL**: HTTPS origin(s) reachable from outside the developer machine — UI origin and API origin; one
  origin or two (plan, Render).
- **Deploy**: an application update reaching the public URL from `main` (RF-5); provisioning (first deploy: schema
  + seeds) is a deploy like any other.

## Functional requirements

- RF-1 (live production frontend): THE SYSTEM exposes the deployed application at a public HTTPS URL: WHEN an
  external client opens the UI's public URL, THE SYSTEM serves the frontend **as a production build** — the static
  output of `npm run build` (`tsc -b` + Vite) — never the Vite dev server; WHEN a client requests `GET
  /api/v1/products` on the public API, THE SYSTEM answers 200 with the standard success envelope of 001 RF-9.
- RF-2 (full CRUD against the deployed database): WHEN a product is created, edited, or soft-deleted through the
  public URL, THE SYSTEM runs the complete delivered flow — server-side pagination (10/page), name search,
  active/inactive filter, confirmations, and the C10 error contract (404/422/500, one JSON shape) — against the
  deployed database, and persists it: the change is still present after a restart or redeploy (persistent
  storage).
- RF-3 (browser integration / CORS in production): THE SYSTEM serves the UI pointing at the public API through
  environment configuration provided at build time in the provider's environment (`VITE_API_BASE_URL` — its value
  lives there and never in the repo; the resulting public URLs are non-secret and are documented per RF-8) and
  accepts exactly that origin on the API (`FRONTEND_ORIGIN`), so every operation started from the UI completes
  with **no CORS error in the browser console** — never a wildcard allowlist, even if UI and API share one origin.
- RF-4 (configuration without secrets, C16): THE SYSTEM takes every deployment configuration from the provider's
  environment (Render): at least `DATABASE_URL` (already supported by `database.yml`'s production section),
  `RAILS_ENV`, `FRONTEND_ORIGIN`, and `VITE_API_BASE_URL` — the same names on Render, each confirmed at signup
  (NFR-4) — plus any boot key the plan verifies necessary; no other variable is assumed in this spec. Verified
  while drafting: no backend code reads Rails credentials (`config.require_master_key` unset) — **no
  `RAILS_MASTER_KEY` is required by the current code**; if a production boot proves a secret key base or master
  key is needed, it is a provider env var, never committed (names → `.env.example`, NFR-2).
- RF-5 (deploy from `main`, gated by CI — coherent with 003): THE SYSTEM updates the public deployment from
  `main`: WHEN a commit reaches `main` (through a PR that passed the required `CI` check — 003 RF-6), THE SYSTEM
  deploys it to the public URL; WHEN a commit exists only on a feature branch or an unmerged PR, THE SYSTEM never
  exposes it publicly. Provisioning is one-time and user-assisted; updates are documented (RF-8). The plan chooses
  the mechanism — Render deploys automatically from GitHub, wired so only `main` deploys publicly — and it must
  keep spec-003 CI green and unchanged (NFR-1).
- RF-6 (initial data): THE SYSTEM seeds the deployed database with the spec-001 demo dataset (001 RF-15) as part
  of provisioning, so the public URL opens on a populated list; seeding is idempotent (001 RF-15): re-running it
  never duplicates visible demo products and never removes API-created data; when a demo product is soft-deleted,
  re-seeding **deterministically resurrects it under a new id** — the decided 004 D-16(a) contract, identical in
  production and in dev.
- RF-7 (public API documentation; consumes 005's hand-off): THE SYSTEM serves the OpenAPI documentation publicly
  on the deployed API: the served document (005 RF-4 URL) and the interactive UI (005 RF-5 URL) answer 200 from an
  external client, assets still served by the application itself — no CDN (D-17b/D-18) — with try-it-out executing
  real requests against the deployed API. The plan verifies whether production static serving needs
  `RAILS_SERVE_STATIC_FILES` (or equivalent) and sets it as an env var if so.
- RF-8 (README, C17): THE SYSTEM's `README.md` documents the delivery: public URL(s) of UI and API (non-secret —
  C16 governs variable names and secret values, not public URLs; the configuration values stay in the provider's
  environment, RF-3), how the deployment is updated and how to provision it from scratch, the **names** of the
  deployment environment variables (never values), and Render's applicable free-tier limits; it **retires the
  known limitation "the frontend is served with the Vite dev server"** — now false — while keeping the local
  `docker compose` instructions exactly as they work today.

## Non-functional requirements

- NFR-1 (no regression, C7): `.github/workflows/ci.yml` keeps running green **untouched** and every command in
  `MEMORY.md → Development commands` keeps working exactly as documented — the deployment does not replace local
  compose: dev origins/ports (localhost:5173/3000) stay unchanged, and no deployment setting leaks into compose,
  tests, or CI.
- NFR-2: No secret, credential, `.env` with real values, or provider token in the repository (C16): values live on
  the provider; names are documented in README and `.env.example`.
- NFR-3: Deployment verification uses plain HTTP requests against the public URL plus the existing suites and
  commands; no new dependency, service, or tool unless the plan justifies it and `MEMORY.md` records it before
  code (C6; C8: the stack is unchanged).
- NFR-4 (user decisions): Render is the single provider for Rails + Postgres + the static frontend (C5) — no
  provider split. Budget: free tier or minimum plan without a card; neither agent can verify 2026 pricing, so the
  plan verifies Render's real free-tier limits with the user at signup — if a payment method or a paid plan is
  required, the work stops and returns to the user before continuing. Every applicable limit (trial hours, cold
  starts/spin-down, expiry) is documented in the README (RF-8) before the deployment goes live on that free tier.

## Edge cases

- Render assigns a new URL, or `VITE_API_BASE_URL` is omitted at build time (it is baked into the bundle) → the
  configured origins must match the real ones; a mismatch surfaces as CORS errors or production calls to
  `localhost` — the external verification of RF-1/RF-3 (the DoD's external check) fails loudly; README records
  where the values live.
- Free-tier limits: an instance that spins down answers the first request slowly but must still answer 200 within
  the time bound the plan/tasks fix; the 2026 limits are verified with the user at Render's signup — a required
  payment stops the work and returns to the user (NFR-4), never a silent upgrade.
- Production forces HTTPS (`force_ssl`/`assume_ssl`) and serves `public/` only with the right setting (RF-7):
  Render's health check path (configurable in the service) **reuses an already-served route** — e.g. `GET
  /api/v1/products` or `GET /docs`, whichever the plan picks — with **zero new routes**: 005 RF-6(a)'s exact route
  surface and its anti-drift test stay intact, NFR-1 keeps CI green untouched, no supersession (C3). A deploy that
  fails to boot leaves the URL down — detection is the post-deploy external check of the Definition of done.
- Provider outage → the public URL is unavailable: out of scope to prevent or mitigate; local compose remains the
  documented fallback (README limitation).

## Out of scope

- Custom domains/DNS and custom TLS certificates; autoscaling/replicas; monitoring, alerting, log aggregation;
  managed backups/PITR and disaster recovery; staging environments and promotion; blue-green/zero-downtime
  deploys; CDN/caching layers — each only ever by explicit user decision.
- Any change to application behavior or contracts: the deployed app is exactly specs 001–005 (behavior changes
  belong to those specs, C3); authentication (C2).
- Changes to the spec-003 CI workflow and to the delivered local compose flow (NFR-1): 003 supplies CI and its
  required check; this spec only adds the deploy consuming `main`.
- Paying for infrastructure beyond what the user accepts at Render's signup (NFR-4); any provider other than
  Render, and any multi-provider setup — one single provider was chosen.

## Definition of done

- From an external client: the public UI URL loads the production build and runs the full CRUD with confirmations
  and UI states (002/C15) against the deployed database; a bad id → the C10 404 shape (RF-2); `/docs` and
  `/docs/openapi.yaml` → 200 (RF-7); a product created through the UI survives a restart/redeploy; reseeding adds
  no duplicates and resurrects a soft-deleted demo product under a new id (RF-2/RF-6, 004 D-16(a)).
- A merge to `main` reaches the public URL without manual steps beyond one-time provisioning (RF-5); a commit on a
  feature branch never does.
- CI green on `main` with `.github/workflows/ci.yml` untouched, and the three documented local verifications
  (RSpec, Vitest, production build) pass unchanged (NFR-1); README updated per RF-8 with Render's limits verified
  with the user at signup (NFR-4); no secrets committed; each task lands as one commit (C17).

## Open questions

- None — both open points are settled by user decisions (recorded below).
- **OQ-1 (deploy provider, `OD-3`) — resolved by the user: Render** (Context). One single provider for the Rails
  API, PostgreSQL, and the static frontend (C5): Dockerfile-backed backend, managed Postgres fed as
  `DATABASE_URL`, static frontend hosting, automatic GitHub deploys (RF-5); no provider split — Vercel remains
  discarded for this stack (no native Rails runtime, no bundled Postgres). Coordinator: record it in `MEMORY.md`
  (suggested **D-20**).
- **OQ-2 (cost) — resolved by the user: free tier or minimum plan without a card.** Neither agent has web access
  to verify 2026 pricing, so the plan verifies Render's real free-tier limits **with the user at signup** (an
  assignable task) and, if Render requires a payment method or a paid plan, stops and returns to the user before
  continuing (NFR-4). The limits that apply — cold starts/spin-down, trial hours, expiry — are documented in the
  README (RF-8).
