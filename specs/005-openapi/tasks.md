# Tasks 005 — API Documentation (OpenAPI)

Derived from the approved `spec.md` (RF-1…RF-8, NFR-1…NFR-2, edge cases, DoD) and
the user-approved `plan.md` (files/responsibilities, serving/UI/anti-drift
mechanics, D-P40…D-P48, test strategy).

Approvals verified before generating this file:

- `spec.md` → `Status: approved`.
- `plan.md` → `Status: approved` (user's explicit approval; status header updated
  in the session that generated this file).

Rules:

- One task = one task-specific commit (C17). T6 is a verification task with no
  commit (evidence lives in the session/validation — same rationale as spec 003's
  T3–T5).
- All checks use only `MEMORY.md → Development commands` (everything via
  `docker compose`; RSpec is mandatory). Nothing runs node/ruby on the host.
- T3/T4 are test-authoring tasks: the anti-drift verification **is** the
  deliverable, so there is no production code to write red-first; T4's drift
  drill proves the verification goes red when the document lies.
- The vendored assets (T2) come **exclusively** from the official
  `swagger-ui-dist` npm tarball at a pinned version via the plan's documented
  `docker run … node:22` pattern. If that pattern fails, the task stops and
  reports — no improvised source, no CDN, no host node.
- Nothing outside the plan's file surface changes: no `routes.rb`, controllers,
  `product.rb`, serializers, `Gemfile`/lockfile, `docker-compose.yml`,
  Dockerfiles, `config/environments/*`, CI workflow, `frontend/`,
  seeds/factories, or existing spec files (C7/C8; the 124 backend examples and
  57 frontend tests stay green untouched). If the document and the live API
  contradict each other while writing the doc or the replay, **stop and report**
  (C2) — never silently adapt code or document.
- Dependency order: T1 → T2 → T3 → T4 → T5 → T6. The document lands first
  (serving, UI, and anti-drift all consume it); the risky vendoring fetch lands
  before the large verification work, so a fetch failure surfaces early; each
  task leaves the whole suite green (C7).

## Tasks

- [x] **T1. The OpenAPI document: `backend/public/docs/openapi.yaml` (D-P40).**
  One hand-written OpenAPI 3.0.3 YAML file per the plan's content skeleton:
  `info` (title, `version: 1.0.0`, the at-most-one audit note of 004 RF-8);
  `servers` with the compose-delivered dev base URL `http://localhost:3000`
  (NFR-2); the five operations with the `:id` path parameter; listing parameters
  `page` / `q` / `active` with the exact 001 RF-9–RF-12 semantics (10/page
  default page 1, case-insensitive `name` substring, active filter, stable
  order, all server-side — C11); the `{ "product": { … } }` request wrapper; the
  success envelopes `{ data }` / `{ data, meta }` and the statuses 200 / 201 /
  204-empty body; `components.schemas` with `Product` exactly as serialized
  (response `price` a string of exactly 2 decimals, `created_at`/`updated_at`
  ISO-8601 UTC), the product envelope(s), and the shared `Error` (`code` enum
  `not_found`/`validation_failed`/`internal_error`, `details` only on 422);
  every validation rule as the model implements it including `PUT`
  full-replacement semantics (RF-2); 404 / 422 (invalid body **and** malformed
  listing parameters) / 500 per endpoint with worked examples, the
  documented-as-implemented invalid-JSON → 500 `internal_error`, the generic 500
  example, soft-delete `DELETE` semantics (204; repeated DELETE → 404) and the
  empty-listing contract (RF-3). Request `price` documented as a JSON number —
  the one form RF-6(f) then replays (D-P48). No security schemes. RF-1, RF-2,
  RF-3, NFR-2, D-17 (500 included and documented as implemented)
  - Done when: the file exists at that path and parses as OpenAPI 3.0.3 with the
    five documented paths — verified inside the stack (e.g.
    `docker compose exec backend bin/rails runner 'd = YAML.safe_load(File.read(Rails.root.join("public","docs","openapi.yaml"))); puts d["openapi"]; puts d["paths"].keys'`
    prints `3.0.3` and the five paths) — and, with `docker compose up -d
    --build`, `curl -s -o /dev/null -w '%{http_code}\n'
    http://localhost:3000/docs/openapi.yaml` answers `200` with content type
    `text/yaml` (`curl -sI`) and
    `curl -s http://localhost:3000/docs/openapi.yaml | diff - backend/public/docs/openapi.yaml`
    is empty (RF-4/D-P41: byte-identical by construction) — as one
    task-specific commit whose only change is the new file. The document's
    truthfulness against the code is T3/T4's job; here it is well-formedness and
    serving.

- [x] **T2. The UI page and the vendored Swagger UI assets: `/docs` (D-P42).**
  Fetch **once** the official `swagger-ui-dist` npm tarball at a **pinned
  version** through the documented
  `docker run --rm -v "$PWD":/w -w /w node:22 …` pattern (host node is
  unusable — MEMORY lesson); verify the fetched tarball is that exact pinned
  version (extracted `package.json` matches; version + retrieval command get
  recorded in the README at T5) and commit exactly three files to
  `backend/public/docs/swagger-ui/`: `swagger-ui-bundle.js`,
  `swagger-ui-standalone-preset.js`, `swagger-ui.css`. Create
  `backend/public/docs/index.html`: a small static page loading **only**
  same-origin asset paths and configuring
  `SwaggerUIBundle({ url: '/docs/openapi.yaml', tryItOutEnabled: true, … })` —
  the **served** document as the only source (RF-5), no inline rendering logic
  beyond the config, **no CDN/external reference**. No `package.json`, lockfile,
  or `Gemfile` change: vendored files, not dependencies (C6 — D-18 recorded by
  the coordinator in `MEMORY.md` before code). If the tarball pattern fails,
  stop and report. RF-5 (static leg), NFR-1 (no new dependency), D-17/D-18
  (self-contained UI, no red in build/runtime)
  - Done when: with the stack up, `curl -s -o /dev/null -w '%{http_code}\n'
    http://localhost:3000/docs` answers `200`, each of the three asset URLs
    under `http://localhost:3000/docs/swagger-ui/` answers `200`, a grep over
    the served `/docs` body finds no `http://`/`https://` reference (no CDN —
    the same assertion T3 automates in the suite), `git status` shows only
    additions under `backend/public/docs/`, and the full
    `docker compose exec backend bundle exec rspec` is green (C7) — as one
    task-specific commit.

- [x] **T3. Anti-drift suite, static legs: `backend/spec/requests/openapi_spec.rb`
  — checks (a)–(d), (g) plus UI availability (RF-6, RF-7, RF-5 static).** One new
  request spec that runs in the ordinary `bundle exec rspec` suite (RF-7) and
  parses the committed document **once** (`before(:context)` +
  `YAML.safe_load` — Ruby stdlib, no gem, D-P43). One `describe` per RF-6 item:
  **(a)** the documented operation set is exactly the five `(method, path)`
  product endpoints, and `Rails.application.routes.routes` enumerated **with
  Rails internals filtered out** (`/rails/*`, `/cable` — D-P44) equals the five
  endpoints' route entries (index, show, create, update drawn as `PUT`+`PATCH`
  by `resources` — the document documents `PUT` per RF-1 —, destroy): no more,
  no less; the documentation URLs are asserted as **served URLs**, not routes
  (D-P41): `GET /docs/openapi.yaml` and `GET /docs` answer 200. **(b)** the
  documented parameters per operation equal exactly the implemented ones (`:id`
  on show/update/delete; `page`, `q`, `active` on index) via a small expectation
  table encoding the 001 contract. **(c)** documented success statuses equal the
  implemented ones (200 list/show/update, 201 create, 204 + empty body). **(d)**
  every documented 4xx/5xx response references the shared `Error` schema, the
  `code` enum is exactly `{not_found, validation_failed, internal_error}`, the
  documented error statuses per operation match the implemented contract, and
  `details` appears only on 422. **(g)** `GET /docs/openapi.yaml`'s body equals
  `File.binread(Rails.root.join('public','docs','openapi.yaml'))` —
  byte-identity (RF-6(g)). Plus UI availability: `GET /docs` is 200 HTML whose
  body contains **no `http://`/`https://` reference** and each vendored asset
  URL answers 200. RF-6(a)(b)(c)(d)(g), RF-7, RF-5 (static no-CDN and
  availability legs)
  - Done when: `docker compose exec backend bundle exec rspec
    spec/requests/openapi_spec.rb` is green and the full
    `docker compose exec backend bundle exec rspec` is green with every
    pre-existing example untouched (C7) — as one task-specific commit.

- [ ] **T4. Anti-drift suite, live legs: check (e), the example replay (f), and
  the simulated 500 (RF-6(e)(f), D-P45, D-P48).** Added to
  `backend/spec/requests/openapi_spec.rb`: **(e)** a real `GET` against fixtures
  created **through the API in the same example** — the response product's keys
  equal the documented `Product` schema's `properties` keys, and `price` matches
  the documented 2-decimal-string pattern. **(f)** a replay loop that iterates
  the **document's** examples (D-P48: examples live in the standard OpenAPI
  fields; `:id` examples use the documented sentinel `"<existing-id>"`,
  substituted by the replay with the id of a product it creates via the
  documented `POST` example) and executes each as a real
  `ActionDispatch::Integration` request (transactional, CI-safe): the response
  status equals the documented status; deterministic bodies (errors, envelopes'
  keys, `meta`) are compared deeply; volatile values (`id`, timestamps) by
  presence/type. Coverage: one worked success request per endpoint; 422 on
  invalid body (per-field `details` keys the model really emits) and on
  malformed listing parameters (`page`/`q`/`active` keys); 404 unknown id,
  non-numeric id, and repeated `DELETE`; empty listing (out-of-range page
  echoing `current_page`; no-match `q`); the documented invalid-JSON body
  replayed **as-is → 500 `internal_error`**; `DELETE` semantics (204 empty; the
  product gone from listings). **Generic 500 by simulation (D-P45):** stub a
  model call to raise, perform the request, and assert the live response equals
  the document's 500 example (001 RF-16 precedent). Self-contained and
  hermetic: fixtures via the API, no new factory, no seeds dependency. If a
  replay exposes a doc-vs-code contradiction, stop and report (C2) — adapt
  neither silently. RF-6(e)(f), RF-3 (500 replayed as implemented), D-17
  (reproducible examples replayed; generic 500 simulated)
  - Done when: the new examples pass
    (`docker compose exec backend bundle exec rspec
    spec/requests/openapi_spec.rb`) and the full suite is green, **and** the
    drift drill proves the safety net: a temporary local drift (e.g. deleting
    the documented `page` parameter or changing one documented status) turns the
    corresponding example red, and reverting it restores green — the breakage is
    never committed — all landed as one task-specific commit.

- [ ] **T5. README: the OpenAPI section (RF-8, D-P46).** New section
  **"Documentación de la API (OpenAPI)"**: where the document lives in the
  repository (`backend/public/docs/openapi.yaml`), its served URL
  (`/docs/openapi.yaml`) and the UI URL (`/docs`), how the anti-drift suite
  keeps it honest (the RF-6 checks run in the ordinary backend suite, so any
  code change that breaks the document fails the suite/CI), and the pinned
  Swagger UI version with how the assets were obtained (official npm tarball,
  vendored in the repo — C6/D-18). Add `backend/public/docs/` to the
  repository-structure tree and flip the "005 — OpenAPI" bullet under
  **Mejoras Futuras** to delivered (C17 coherence). Documentation only; no test
  or code changes. RF-8, C17
  - Done when: the section is coherent with what T1–T4 delivered (same URLs,
    same pinned version, same mechanism), every `docker compose` command printed
    in the README still matches `MEMORY.md → Development commands`, and
    `git diff --stat` shows `README.md` as the only modified file — as one
    task-specific commit.

- [ ] **T6. Browser smoke: rendering, try-it-out, and network log (user /
  coordinator action — D-P47; no commit).** The implementer has no browser
  (MEMORY lesson), so everything HTTP-reachable is already proven by T3/T4; the
  **dynamic** smoke is performed by the coordinator (D-13 `agent-browser` +
  the built-in OpenCode browser, the proven 002 pattern) or the user: open
  `http://localhost:3000/docs`, confirm the five operations render **from the
  served document** (spot-check one example against the YAML), execute one
  try-it-out request and see the real API response, and confirm the browser's
  network log shows **only same-origin requests** (no CDN — RF-5's runtime
  leg). RF-5 (dynamic leg), DoD (browser item)
  - Done when: the coordinator/user confirms the three checks with evidence
    (screenshot or session note) recorded before `/sdd-validate 005-openapi`
    runs — no repo commit; verification only. If the smoke fails, report and
    fix through the SDD flow; never bend the document's meaning ad hoc.

## Final check (before `/sdd-validate`)

The DoD battery runs together as the last gate (004's pattern — verification
without a code change would have no commit); CI (spec 003) repeats the three
suites automatically on the PR with run-all semantics; the required check is
`CI`.

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec     # 124 today → grows; must be green
docker compose run --rm frontend npm test         # 57/57, unchanged (C7)
docker compose exec frontend npm run build        # tsc + vite, unchanged
curl -s http://localhost:3000/docs/openapi.yaml | diff - backend/public/docs/openapi.yaml  # empty diff = byte-identical (RF-6(g), DoD)
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/docs                        # 200 (DoD)
```

The browser item of the DoD is T6's evidence (D-P47).

## RF coverage

| Task | RFs / NFRs / DoD |
|---|---|
| T1 | RF-1, RF-2, RF-3, NFR-2, D-17 (500 documented as implemented) |
| T2 | RF-5 (static leg), NFR-1 (no new dependency), D-17/D-18 (self-contained UI) |
| T3 | RF-6(a)(b)(c)(d)(g), RF-7 (ordinary suite), RF-5 (static no-CDN + availability) |
| T4 | RF-6(e)(f) incl. simulated generic 500 and invalid-JSON replay, RF-3 (replay leg), D-17 |
| T5 | RF-8, C17 coherence |
| T6 | RF-5 (dynamic leg), DoD (browser item) |
