# Plan 006 — Deploy (Live deployment)

Status: approved

Derived from the approved `spec.md` (RF-1…RF-8, NFR-1…NFR-4, edge cases, DoD). This increment adds **no
application behavior**: specs 001–005 are consumed as-is (C3, C7) — the deliverables are **one production image**
of the whole deployed application (production Vite build + Rails API), its **Render** provisioning and
environment configuration, the README deliverable, and the external verification. The user decisions **D-20
(Render as the single provider; health check on an already-served route)** and **NFR-4 (free tier / minimum plan
without a card; the real 2026 limits verified with the user at signup, stopping if payment is required)** are
implemented here, not reopened. The plan fixes what the spec delegated: serving origin (RF-1/RF-3), deploy
mechanism (RF-5), migrations and seeds (RF-6), health-check route and cold-start time bound (edge cases), boot
key (RF-4), `RAILS_SERVE_STATIC_FILES` (RF-7), README content (RF-8), and the verification split (DoD, NFR-3).

**Why Render (D-20):** the evaluated alternative that hosts frontend, Rails API, and PostgreSQL on one provider
with a free plan — Docker runtime, auto-deploy from GitHub, and a structure equivalent to the one already planned
— chosen after verifying that the originally considered provider was closed to registrations. Not reopened.

**Deploy strategy, in order:** one multi-stage image at the repo root → Render web service (Docker runtime) +
managed PostgreSQL → env vars entered **before the first build** → auto-deploy only from `main` with green CI
(003's required check) → every container start runs `db:prepare db:seed` → health check `GET /api/v1/products` →
public URL `*.onrender.com`.

**Production orchestration (C8):** production does **not** use `docker-compose.yml`; compose stays exactly the
dev/CI flow (NFR-1: dev origins/ports and every documented command unchanged). Render builds and runs the image
from the root `Dockerfile` and supplies PostgreSQL as a managed service. No production orchestration file is
added.

## Facts verified before planning (running containers + image boot, 2026-10-24)

- **Static serving needs no env var (RF-7 resolved):** `config.public_file_server.enabled` defaults `true`
  (railties 8.1.4, `configuration.rb:47`) and `production.rb` never sets it — live proof: `RAILS_ENV=production
  bin/rails runner` → `pfs=true`. 005's hand-off closed with evidence.
- **`/` serves the UI:** `ActionDispatch::FileHandler` serves `path`, `path.html`, `path/index.html` (actionpack
  8.1.4 source; 005 already proved directory `index.html` → 200) → `public/index.html` (the Vite output) answers
  the root URL with no Rails route.
- **Boot requires `SECRET_KEY_BASE` — empirically proven:** the real image booted against a `backend/` copy
  **without** `config/master.key`/`config/credentials.yml.enc` (both gitignored → absent from the repo and any
  Render build) raised `ArgumentError: Missing secret_key_base for 'production' environment` (finisher →
  `message_verifier`); with the var set, the same boot printed OK. **No `RAILS_MASTER_KEY`**:
  `config.require_master_key` is unset and no application code reads credentials.
- **`DATABASE_URL` alone configures production:** live boot with
  `DATABASE_URL=postgres://usr:pw@render-host:5432/proddb` → `connection_db_config` = host/database/username/
  password from the URL — it wins over `database.yml`'s `<<: *default`. **No `database.yml` change** (RF-4 holds).
- **Platform mechanics:** `force_ssl`/`assume_ssl` are already `true` and `ActionDispatch::AssumeSSL` (source)
  forces `X-Forwarded-Proto: https` on every request → the platform's plain-HTTP probe reaches the app as HTTPS
  (200, no 301); `config.hosts` is `[]` in production (live check) → the Render domain is not blocked; Puma binds
  a routable interface (`port ENV.fetch("PORT", 3000)`, proven by the compose mapping) and honors a
  platform-provided `PORT`.
- **`VITE_API_BASE_URL` has no code fallback:** `frontend/src/api/products.ts:10` is
  `const BASE_URL = import.meta.env.VITE_API_BASE_URL` — an omitted build-time value bakes `undefined` (the
  spec's "fails loudly" edge case) → the image build gets a fail-fast guard (D-P53).
- **Build context:** `frontend/package-lock.json` exists → `npm ci`; a stale host `frontend/dist` must be
  excluded; no `.dockerignore` today while `.env` (root) and `config/master.key` + `config/credentials.yml.enc`
  (backend) are gitignored — a repo-based build carries none of them, a local root-context build *would* (C16,
  D-P49).
- **The production cache header is wrong for a SPA entry:** `public_file_server.headers` sets `max-age=1.year`
  for *every* `public/` file — a cached `index.html` would reference hashed assets the next deploy removed
  (RF-5/US-2) → D-P55.
- Production boot prints one **non-fatal** Active Storage `image_processing` warning — log noise only.

## Files to create and modify

| File | Responsibility |
|---|---|
| `Dockerfile` (root, new) | The single production image (D-P49): stage 1 `node:22` runs `npm ci` + `npm run build` with `ARG VITE_API_BASE_URL` and a fail-fast guard (D-P53); stage 2 `ruby:3.3` is the API plus `COPY --from` of `dist/` into `public/`; `CMD` runs the boot chain (D-P52) and execs puma. Render builds this file on push to `main` (auto-deploy, D-P51). |
| `.dockerignore` (root, new) | Build-context hygiene (D-P49): excludes `.git`, `.env`/`.env.*`, `**/node_modules`, `frontend/dist`, `backend/tmp`, `backend/log`, `backend/config/master.key`, `backend/config/credentials.yml.enc` — keeps secrets out of the image (C16), prevents host (darwin) `node_modules` from overwriting the linux ones, and shrinks the context. |
| `backend/config/environments/production.rb` (modify, 3 lines — D-P55) | (1) `cache-control` → `public, max-age=0, must-revalidate` so a deploy is visible immediately while assets still revalidate via 304; (2) `silence_healthcheck_path` → `/api/v1/products` (the real probe path; `"/up"` does not exist — `routes.rb` has exactly five routes); (3) `active_storage.variant_processor = :disabled` — Rails' own suggested value for the observed boot warning (this API generates no variants). Nothing else: `assume_ssl`/`force_ssl`/STDOUT logging already correct; static serving enabled by default (facts above). |
| `.env.example` (modify) | RF-4/NFR-2: add the **names** of the two production-only variables not yet present — `SECRET_KEY_BASE` (required, D-P54) and `RAILS_ENV=production` — with placeholder values and a "production deploys only" comment, as `DATABASE_URL` already has. Values live only in Render's dashboard. |
| `README.md` (modify) | RF-8: new section **"Despliegue (spec 006 — Render)"**: the public URL (one origin: UI `/`, API `/api/v1/products`, docs `/docs`), update flow (merge to `main` → automatic deploy; CI gate of 003 unchanged), provisioning from scratch, the **names** of `RAILS_ENV` / `DATABASE_URL` / `FRONTEND_ORIGIN` / `VITE_API_BASE_URL` / `SECRET_KEY_BASE` (never values), and Render's free-tier limits — the pricing-page figures **already verified by the user (render.com/pricing
2026-10-24: 5 GB bandwidth/mo, 500 build minutes/mo, 512 MB / 256 MB, overages $0.15/GB and $5/1K, no card at
signup)** plus the signup-verified behaviors (NFR-4: spin-down/cold starts, free-Postgres expiry, any hours/card
terms). Also: retire the known limitation "the frontend is served with the Vite dev server" (now false), flip the `006 — Deploy` bullet under *Mejoras Futuras* to entregado, add `Dockerfile`/`.dockerignore` to the structure tree. Local `docker compose` instructions stay exactly as they are (RF-8). |

**Nothing else changes:** `docker-compose.yml`, `backend/Dockerfile` and `frontend/Dockerfile` (dev-only,
consumed as-is — the production image is a new file precisely so compose contexts/commands stay untouched),
`frontend/vite.config.ts`, `frontend/package.json`, `backend/config/database.yml` (URL precedence proven),
`backend/config/initializers/cors.rb` (already `FRONTEND_ORIGIN`-driven, exact origin), `backend/config/puma.rb`,
`backend/config/routes.rb` (five routes — the health check **reuses** one; 005's anti-drift route assertion stays
green), `backend/db/seeds.rb` (idempotent per 001 RF-15/004 D-16a), `.github/workflows/ci.yml` (**zero edits** —
RF-5/NFR-1: the deploy is post-CI, 003's branch protection remains the gate), and every existing spec file (C7:
the current 181 backend examples + 57 frontend tests stay green untouched).

## The production image (D-P49; RF-1, RF-2, RF-4, RF-6, RF-7)

One multi-stage `Dockerfile` at the repo root builds the whole deployed application. Sketch (final form during
implementation):

```dockerfile
# stage 1 — the production frontend build (RF-1)
FROM node:22 AS frontend
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
ARG VITE_API_BASE_URL
RUN test -n "$VITE_API_BASE_URL" || { echo "VITE_API_BASE_URL build arg is required (spec 006 RF-3)" >&2; exit 1; }
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build                      # tsc -b + vite build — the exact CI/local build

# stage 2 — the API + the built frontend (RF-1, RF-7)
FROM ruby:3.3
RUN apt-get update -qq && apt-get install -y --no-install-recommends libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY backend/Gemfile backend/Gemfile.lock ./
RUN bundle install
COPY backend/ .
COPY --from=frontend /app/dist ./public/   # index.html at /, assets at /assets/* — served by
                                           # Rails' static middleware (enabled by default)
EXPOSE 3000
CMD ["sh", "-c", "bin/rails db:prepare db:seed && exec bundle exec puma -C config/puma.rb"]
```

- `ActionDispatch::Static` serves `public/index.html` at `/` and `public/assets/*` at `/assets/*` (verified source
  + 005's live dev proof of the same middleware) — **no nginx, no asset pipeline, no new serving route**; the
  committed `backend/public/docs/` ships untouched inside the image (RF-7: assets served by the application
  itself, no CDN).
- The boot chain runs **`db:prepare db:seed` — the same commands dev and CI already run** (parity) — then `exec`
  puma so it receives container signals (graceful shutdown on redeploy).
- Discarded: reusing/extending `backend/Dockerfile` or `frontend/Dockerfile` (both are compose-bound: `build:
  ./backend` / dev-server CMD — changing them alters the delivered dev flow, NFR-1); committing `frontend/dist/`
  (build artifacts in the repo, stale by the next deploy); nginx or a second container (an extra service + config
  file for what Rails' static middleware already does — C5); hand-built images pushed to a registry (platform
  builds from the repo — simpler, no tokens, C16).

## One origin for UI, API, and docs (D-P50; RF-1, RF-3, RF-8)

**The plan picks ONE public origin**: the Render web-service URL serves the UI at `/`, the API at `/api/v1/*`,
and the docs at `/docs` — one URL to document (RF-8), one service to health-check, one URL in front of every
external verification. `VITE_API_BASE_URL` (build time) and `FRONTEND_ORIGIN` (runtime) **both equal that public
URL**: the CORS allowlist stays env-driven and exact — never a wildcard — satisfying RF-3's "even if UI and API
share one origin"; same-origin calls never trip CORS, and the exact-origin echo is still asserted externally
(`curl -H "Origin: $URL"` → `access-control-allow-origin: $URL`).

Discarded: **two origins** (backend service + Render Static Site for the frontend) — mirrors dev's 5173/3000
split but doubles the platform surface that cannot be verified offline (static-site build/env mechanics, second
domain, deploy ordering), splits the health check, and buys nothing the spec requires (it allows one origin);
**third-party hosting of the frontend** (provider split — NFR-4).

## Render layout: services, environment, auto-deploy, health check (D-P51; RF-4, RF-5)

Two pieces in one Render project (the chosen provider, D-20 — not reopened):

1. **Web service** (Docker runtime) — builds the root `Dockerfile` from the GitHub repo. Environment (values
   entered in Render's dashboard, never in the repo — C16):

   | Variable | When | Value source |
   |---|---|---|
   | `RAILS_ENV=production` | runtime (boot chain + puma) | fixed, non-secret |
   | `DATABASE_URL` | runtime | Render's PostgreSQL instance (same project), injected automatically by Render |
   | `FRONTEND_ORIGIN` | runtime (CORS, `cors.rb`) | the assigned public URL |
   | `VITE_API_BASE_URL` | **build** (stage 1 ARG) | the assigned public URL — Render passes service env vars as Docker build args (~2024 assumption, to verify at signup); set **before** the first build |
   | `SECRET_KEY_BASE` | runtime (boot key, D-P54) | generated secret (user), value only in Render |
   | `PORT` | runtime | platform-provided — puma already honors it |

2. **PostgreSQL (Render-managed)** — its managed volume is the persistent storage of RF-2 (data survives
   redeploys/restarts); the app container needs **no volume** (no runtime-written files: logs → STDOUT, assets →
   image). The free tier's instance expiry (~90 days assumed) → verify at signup, document in the README (RF-8);
   RF-2's persistence holds for the instance's lifetime.

**Auto-deploy from `main` (RF-5):** the user connects the GitHub repository through Render's GitHub integration
(repo access = user action) with **Auto Deploy on and the deploy branch fixed to `main`**; PR preview
environments stay **disabled** — a commit on a feature branch or an unmerged PR never reaches the public URL. The
merge is already gated by 003's required `CI` check (branch protection, active) — **no workflow edit**; the
merge commit's push-CI run may still be in flight while Render deploys — fine, the same code passed the PR check
(exactly RF-5's wording). The service config points at the root `Dockerfile` (repo root, Docker runtime); start
command and port live in the image CMD — **discarded:** a Render "start command" override and dashboard-only
scripts (the provisioning recipe must live in the repo to be reproducible and RF-8 documentable; dashboard config
drifts).

**Health check (edge case — zero new routes):** the service's health-check path (Render: Health & Metrics →
Health Check Path) is set to `GET /api/v1/products` — chosen over the spec's other allowed reuse, `GET /docs`,
because it executes a real database query (liveness *and* readiness) while `/docs` is a static file; and over
`/up`/a new `/health` because `routes.rb` must stay exactly five routes (005's anti-drift test, NFR-1, D-20). The
AssumeSSL fact means the plain-HTTP probe is answered 200, not redirected. Exact fields (path/interval/threshold)
are platform-side → to verify at signup.

## Database in production: schema, migrations, seeds (D-P52; RF-2, RF-6)

The image CMD runs **`bin/rails db:prepare db:seed` on every container start** (deploy, restart, cold start):

- **First deploy (provisioning):** `db:prepare` creates the database (the attached `DATABASE_URL` credentials can
  create it — to verify at signup), loads `db/schema.rb`, seeds the spec-001 demo dataset → the public URL opens
  populated (RF-6). Provisioning is "a deploy like any other" (Definitions).
- **Later deploys:** `db:prepare` applies pending migrations, then seeds — idempotent by contract (001 RF-15, 004
  D-16(a)): no duplicate visible demo products, API-created data never removed, a soft-deleted demo product
  resurrected under a **new id**. Seeds on every start make the DoD's reseed checks verifiable **from outside** by
  triggering a redeploy — no console access needed.
- Discarded: migrations-only (`db:migrate`) — the DoD's external "reseed → resurrection" proof would need
  provider console access; a Render release (pre-deploy) command or one-off job for seeds — must be verified
  anyway and adds a second execution path for the exact commands dev/CI already run; seeding in CI — the CI
  database is ephemeral, the deploy seeds the deployed one.

## Frontend build: where and with what (D-P53; RF-1, RF-3, RF-5, NFR-1)

**The deploy builds the frontend** (Render runs the root Dockerfile on push to `main`, passing service env vars
as Docker build args — to verify at signup); `VITE_API_BASE_URL` is a Docker build ARG and the stage-1 guard
makes an omitted value **fail the build loudly** instead of shipping the `undefined`-based bundle (the spec's
edge case). **If Render does not expose env at build time → STOP and report** (RF-3 would need a user decision).
CI keeps building the same `npm run build` on every PR as pre-merge proof that the identical build works — but CI
produces nothing for production.

Discarded: **CI builds the artifact for the deploy** — requires editing `.github/workflows/ci.yml` (NFR-1/RF-5
forbid changes), cross-workflow artifact plumbing, and CI runs on PRs where deploy output would be meaningless;
**runtime configuration** (fetching the API base URL at page load) — rewrites spec-002 code against RF-3's letter
("provided at build time"); **relative same-origin fetch** (`BASE_URL = ''`) — same deviation, and the client has
no fallback today.

## Boot key and secrets (D-P54; RF-4, NFR-2, C16)

`SECRET_KEY_BASE` is a **required provider env var — proven by boot** (facts above): generated by the user at
signup (e.g. `openssl rand -hex 64`), its value lives only in Render; the **name** goes to `.env.example` and
README (RF-4's provision, NFR-2). `RAILS_MASTER_KEY` stays **not required** (`require_master_key` unset; no app
code reads credentials; the credential files are gitignored and absent from any Render build). Discarded:
committing `credentials.yml.enc`+`master.key` or a generated secret (C16); `SECRET_KEY_BASE_DUMMY` (bakes a
per-image throwaway secret — signed material would change every deploy; the spec wants the boot key in the
provider environment).

## Implications to prepare on Render (NFR-4; assigned to tasks, done with the user)

1. **Render account — create the Hobby workspace WITHOUT adding a credit card** (the free tier is verified:
   $0 Hobby + Compute Free + Postgres Free, user evidence render.com/pricing 2026-10-24). Add a card only if
   Render concretely demands it for something — **if a card or a paid plan is demanded → STOP and return to the
   user before any further deploy work (NFR-4); never a silent upgrade.**
2. **GitHub connection:** repo access through Render's GitHub integration (user authorizes; the repo is public
   per the statement); Auto Deploy on, deploy branch `main`, PR preview environments off.
3. **Environment variables** (values only in Render — C16; names in `.env.example`/README), on services created
   **before the first build** (web service + PostgreSQL in one project; Render injects `DATABASE_URL` and assigns
   the `*.onrender.com` domain): `SECRET_KEY_BASE` (user-generated, D-P54), `RAILS_ENV=production`,
   `FRONTEND_ORIGIN`, `VITE_API_BASE_URL` — the last two = the assigned URL.
4. **Health check:** `GET /api/v1/products` on the web service.
5. **Free-tier limits → README (RF-8):** the pricing-page-verified numbers — 5 GB bandwidth/mo (then
   $0.15/GB), 500 build minutes/mo (then $5/1K), 512 MB RAM/<1 CPU (Compute Free), 256 MB RAM/100 connections
   (Postgres Free) — plus the still-open platform behaviors: spin-down ~15 min → cold start ≤ **90 s**; free
   PostgreSQL expiry ~90 days; hours/card terms beyond the pricing page verified at signup.

Then: feed the verified limits into the README (RF-8) and record the outcome (including any STOP) for `MEMORY.md`
— coordinator's hand-off.

## To verify at signup with the user (platform facts nobody can confirm offline — assumptions, NOT facts)

| Item | Verify | If it differs / fails |
|---|---|---|
| Free plan, 2026 | **VERIFIED (user, render.com/pricing 2026-10-24): $0 with no card at signup** — Hobby workspace $0 (5 GB bandwidth/mo, then $0.15/GB; 500 build minutes/mo, then $5/1K; 2 custom domains; up to 25 services), Compute Free $0 (512 MB RAM, <1 CPU), Postgres Free $0 (256 MB RAM, 100 connections); Docker builds included; the only card-related item is a $1 refundable charge *after* adding a card → without a card, **no charge is possible** → NFR-4 budget gate **met** | Residual risk only: bandwidth/build-minute overage → document the concrete limits in README (RF-8); a card/plan demanded later → **STOP** (NFR-4) |
| Spin-down / cold start | Inactivity spin-down (~15 min assumed) and real first-request latency | Measured against the fixed **90 s** bound (D-P56); value → README (RF-8) |
| Free PostgreSQL expiry | Instance/data lifetime (~90 days assumed) | → README (RF-8); RF-2 persistence holds for the instance's lifetime |
| Env as Docker build args | Whether Render passes service env into the Dockerfile build (`VITE_API_BASE_URL` mechanism) | Env not available at build time → **STOP**, report (RF-3 decision) |
| Env var names per service | `DATABASE_URL` injected into same-project services; `RAILS_ENV`/`FRONTEND_ORIGIN`/`SECRET_KEY_BASE`/`VITE_API_BASE_URL` entered manually | Enter the rest in the dashboard before the first build |
| Domain | One `*.onrender.com` hostname per web service; stability across redeploys | One service → one origin (D-P50) |
| Release command | Whether Render offers a pre-deploy release command and what it runs | D-P52's CMD chain stays the mechanism; if Render requires migrations in a release command → deviation to **report**, never a silent change (RF-6's idempotent re-seed and the DoD's external reseed proof must keep holding) |
| Health check | Exact fields (path/interval/threshold) and probe behavior (plain HTTP) | AssumeSSL fact → answered 200, not redirected |
| Static serving (005 hand-off, RF-7) | `RAILS_SERVE_STATIC_FILES` proven unnecessary; `/`, `/assets/*`, and `/docs` served **by the app** | No platform static/CDN layer in front (the matrix covers it) |
| GitHub integration flow | Repo access, auto-deploy toggle, deploy-branch selection, PR preview environments | `main` only, previews off (RF-5) |
| Runtime mechanics | Render honors the Dockerfile `CMD` and assigns the port (`PORT` — puma already honors it); the injected Postgres user can run `CREATE DATABASE` | First-deploy `db:prepare` needs CREATE DATABASE |

## External verification (D-P56; DoD, RF-1…RF-7, NFR-3, NFR-4)

Plain HTTP against the public URL + the existing suites (NFR-3 — no new tool); run by whoever has outbound
network in that session (implementer, else coordinator/user — the 005 browser-smoke precedent); evidence lands in
the tasks.

| RF | External check (public URL unless noted) |
|---|---|
| RF-1 | `curl -s $UI` → 200 HTML referencing `/assets/…` hashed files, **no** `/@vite/client`, **no** `localhost` (production build, dev server absent); `curl -s $API/api/v1/products` → 200 `{ data, meta }` |
| RF-2 | Full curl CRUD against `$API`: 201 → 200 → 422 with per-field `details` → 404 C10 shape on bad id → 204 delete; listing `page`/`q`/`active` server-side; a product created through the **UI** (coordinator browser) still GETs 200 after a redeploy; UI confirmations/states checked in the coordinator smoke (C15) |
| RF-3 | `curl -sI -H "Origin: $UI" $API/api/v1/products` → `access-control-allow-origin: $UI` (never `*`); coordinator browser: operations from the UI complete with an **empty console** (no CORS errors) |
| RF-4 | Repo grep: no secrets/`.env` with values; README + `.env.example` carry names only; the Render dashboard env panel (user) holds the values |
| RF-5 | Merge a PR to `main` → a deploy runs and the URL shows the change; a commit pushed only to a feature branch → no deploy listed, URL unchanged |
| RF-6 | Soft-delete a demo product via the public UI → trigger a redeploy → it reappears under a **new id**; name search shows **no duplicates**; an API-created product is untouched |
| RF-7 | `curl -o /dev/null -w '%{http_code}' $API/docs` and `$API/docs/openapi.yaml` → 200; try-it-out executes a real request (coordinator browser); no CDN/external refs (005's suite already asserts it) |
| NFR-1 | Before/after: suites + build green via the binding commands; `git diff` shows `.github/workflows/ci.yml` and `docker-compose.yml` untouched |
| NFR-4 | README limits = the pricing-page figures verified by the user (2026-10-24) plus what the user verified at signup; recorded STOP if a card/plan was required |
| Edge (cold start) | After a spin-down, `curl --max-time 90 -s -o /dev/null -w '%{http_code}' $UI` → 200 — **time bound fixed here: 90 s** (the spec delegates it to plan/tasks; rationale in D-P56) |

## Test strategy (C7, C12, NFR-1, NFR-3)

**No new test suites or test dependencies.** The spec changes no application behavior — nothing new to unit-test
in-repo; NFR-3 frames verification as plain HTTP plus the existing suites, and the anti-drift/CRUD suites already
guard the API contract. Binding commands, unchanged, via `docker compose`:

```sh
docker compose up -d --build
docker compose exec backend bundle exec rspec     # 181 examples, must stay green
docker compose run --rm frontend npm test         # 57 tests, must stay green
docker compose exec frontend npm run build        # tsc + vite, must stay green
```

**Local rehearsal of the whole production path (offline, before touching Render)** — proves image, boot chain,
seeds, serving, CORS, and cache policy against a throwaway PostgreSQL:

```sh
docker network create inv-prod-sim
docker run -d --name pg-sim --network inv-prod-sim \
  -e POSTGRES_PASSWORD=sim -e POSTGRES_USER=postgres -e POSTGRES_DB=inventory_production postgres:16
docker build -t inventory-prod-sim --build-arg VITE_API_BASE_URL=http://localhost:3999 .
docker run -d --name app-sim --network inv-prod-sim -p 3999:3000 \
  -e RAILS_ENV=production -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e DATABASE_URL=postgres://postgres:sim@pg-sim:5432/inventory_production \
  -e FRONTEND_ORIGIN=http://localhost:3999 inventory-prod-sim
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3999/            # 200, production index.html
curl -sI http://localhost:3999/ | grep -i cache-control                    # no long-lived index cache (D-P55)
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3999/api/v1/products   # 200 (seeded), no 301 (force_ssl fact)
curl -sI -H 'Origin: http://localhost:3999' http://localhost:3999/api/v1/products | grep -i access-control-allow-origin   # exact origin
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3999/docs        # 200 (RF-7 in the prod image)
docker rm -f app-sim pg-sim && docker network rm inv-prod-sim
```

The missing `VITE_API_BASE_URL` case must fail the `docker build` (guard check). Everything Render-specific then
reduces to the signup-verification table above.

## Technical decisions (discarded alternative included)

- **D-P49 — One root multi-stage `Dockerfile` = the single production image (Vite build copied into
  `backend/public/` + Rails API + boot-chain CMD), plus a root `.dockerignore` (seeds `.env`, keys,
  `node_modules`, `dist` out of the context — C16).** Discarded: two services with a static frontend (D-P50), an
  nginx container (extra service for Rails' built-in static middleware), modifying the dev Dockerfiles (breaks
  compose contexts — NFR-1), committing `dist/` (stale artifacts in git), image registry pushes (tokens = C16).
- **D-P50 — One public origin serves `/`, `/api/v1/*`, and `/docs`; `VITE_API_BASE_URL` = `FRONTEND_ORIGIN` =
  that URL, exact allowlist kept.** Discarded: two origins (second service/domain, deploy ordering, CORS under
  load — doubles the unverifiable platform surface for zero spec gain: RF-3 explicitly tolerates one origin),
  third-party frontend hosting (provider split — NFR-4).
- **D-P51 — Render: web service (Docker runtime, root Dockerfile) + managed PostgreSQL; env vars per the D-P51
  table; auto-deploy from `main` via the GitHub integration (PR previews off); health check
  `GET /api/v1/products`; no app volumes.** Discarded: health path `/docs` (static file — no DB signal), `/up` or
  `/health` (new routes — forbidden: zero new routes), dashboard start commands/scripts (provisioning must live
  in the repo — RF-8), custom volumes (the app writes nothing; Postgres persistence belongs to the managed
  instance). Vercel was discarded at spec time (no native Rails runtime, no bundled Postgres) — not reopened.
- **D-P52 — `db:prepare db:seed` runs in the image CMD on every start: migrate + idempotent re-seed every deploy;
  the first deploy provisions.** Discarded: migrations-only (the DoD's external reseed proof becomes unreachable),
  platform release jobs (a second path for the exact commands dev/CI already run), seeding in CI (ephemeral DB).
- **D-P53 — The deploy builds the frontend; CI stays untouched; the build ARG fails fast when
  `VITE_API_BASE_URL` is missing.** Discarded: CI-built artifacts for deploy (workflow edit — NFR-1 — plus
  artifact plumbing), runtime-fetched API base URL or relative same-origin fetch (both rewrite spec-002 code
  against RF-3's build-time wording).
- **D-P54 — `SECRET_KEY_BASE` is a required Render env var, proven by a real boot without credentials; names only
  in `.env.example`/README.** Discarded: committing credentials/master key (C16), `SECRET_KEY_BASE_DUMMY`
  (per-image throwaway secret), baking `RAILS_ENV` into the image (RF-4 assigns it to the provider environment).
- **D-P55 — `production.rb`: three one-line adjustments — cache-control `public, max-age=0, must-revalidate`
  (RF-5/US-2: a merge must be visible; hashed assets revalidate cheaply via 304), `silence_healthcheck_path =
  "/api/v1/products"` (the line exists exactly for this; `"/up"` does not exist),
  `active_storage.variant_processor = :disabled` (Rails-suggested value for the observed per-boot warning; no
  variants are ever generated).** Discarded: keeping `max-age=1.year` (stale `index.html` → old hashed assets 404
  after the next deploy — the evaluator could see a blank page), a custom per-path caching middleware (extra code
  for one header — C5), a short TTL (still a stale window), silencing nothing (health probes polluting logs
  forever). `RAILS_SERVE_STATIC_FILES`: verified **unnecessary** — no variable, no line (facts above; RF-7
  resolved).
- **D-P56 — Verification split and bound: implementer/coordinator run the curl matrix + the existing suites; the
  user performs signup/permissions/env-entry; the coordinator runs the browser legs (CORS console, UI CRUD,
  try-it-out); the cold-start first-request bound is fixed at 90 s** (Render's ~2024 "~60 s" spin-up estimate
  plus image pull/boot/TLS margin; the real measured latency is documented in the README, RF-8). Discarded:
  automated deploy tests in-repo (nothing production-specific is testable outside production — NFR-3), user-only
  manual QA (suites + curl must run first), leaving the time bound open (the spec delegates fixing it).

## RF coverage map

| Part | Covers |
|---|---|
| Root `Dockerfile` stage 1 (+ ARG guard) | RF-1 (production build), RF-3 (value baked from provider env; missing value fails loudly), RF-5 (deploy builds current `main`) |
| Root `Dockerfile` stage 2 + CMD (D-P52) | RF-2 (boot + managed Postgres = persistence), RF-4 (runtime env), RF-6 (provision + idempotent re-seed), RF-7 (static `public/` served by default) |
| `.dockerignore` | RF-4, NFR-2, C16 (no secret/key/env file in the image) |
| One origin + env pair (D-P50) | RF-1 (URL serves the UI), RF-3 (exact allowlist, no wildcard), RF-8 (one URL to document) |
| Render services/env/auto-deploy/health check (D-P51) | RF-4, RF-5 (main-only deploy, CI gate untouched, failed boot detectable), edge cases (probe not redirected; zero new routes), NFR-1 |
| `production.rb` (D-P55) | RF-5 (latest code visible on merge), RF-7 (serving verified; health-path silence), edge (HTTPS facts) |
| `.env.example` + README section (RF-8) | RF-4, RF-8 (URLs, update/provision, env **names**, retired limitation, local flow intact), NFR-2, NFR-4 (limits documented after signup) |
| Implications to prepare + to-verify table | NFR-4 (budget gate, limits), RF-3/RF-5 mechanics on the platform |
| External verification matrix (D-P56) | RF-1, RF-2, RF-3, RF-5, RF-6, RF-7, DoD, NFR-1, NFR-4, cold-start edge (90 s) |
| Existing suites (unchanged commands) | NFR-1, NFR-3, C7, C12 |
| Local production rehearsal (Test strategy) | RF-1, RF-3, RF-4, RF-6, RF-7 mechanisms proven offline before signup |

## Out of scope for this plan

Everything under the spec's Out of scope: custom domains/DNS/TLS, autoscaling, monitoring/alerting/log
aggregation, backups/PITR, staging/promotion, blue-green/zero-downtime deploys, CDN/caching layers (the docs
assets stay same-origin per D-17b/D-18); any change to specs 001–005 behavior or contracts (routes, error
contract, seeds — reality contradicting this plan stops and reports, C2); authentication; any provider besides
Render or any multi-provider setup (D-20/NFR-4); any edit to `.github/workflows/ci.yml`, `docker-compose.yml`,
the dev Dockerfiles, or the documented local commands (NFR-1); paying beyond what the user accepts at signup
(NFR-4); new dependencies or test tools (C6/C8 — this plan adds **none**: same base images `ruby:3.3`/`node:22`,
no gems, no npm packages, no nginx); committing any secret (C16); and `MEMORY.md` (recording stays with the
coordinator: the D-20 Render decision + signup outcomes).
