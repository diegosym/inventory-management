# Plan 005 — API Documentation (OpenAPI)

Status: approved

Derived from the approved `spec.md` (RF-1…RF-8, NFR-1…NFR-2, edge cases, DoD).
This increment adds **no API behavior**: the five `/api/v1/products` endpoints are
consumed as merged by specs 001 + 004 (C10, C11 — code remains the source of
truth) and the deliverables are a committed OpenAPI document, its served URL, a
self-contained interactive UI, and the anti-drift verification. The user
decisions **D-17** (doc in repo **and** served at a fixed URL; interactive UI in
scope, self-contained, no CDN; the 500 included and documented as implemented;
supersession of 001 RF-3 / 004 RF-5; C6 gate for any new dependency/asset) are
implemented here, not reopened. It fixes what the spec delegated to the plan:
the document's format and location (RF-1…RF-4), the serving mechanism (RF-4),
the UI mechanism (RF-5), the anti-drift mechanism and replay conventions
(RF-6/RF-7), and how the UI's dynamic behavior is verified (DoD).

Live-stack facts verified in the running compose containers on 2026-10-23 (the
plan-004 precedent): `config.public_file_server.enabled == true` in **both**
development and test; `ActionDispatch::Static` serves `public/<dir>/index.html`
at `/dir` directly (200, no redirect) and a `.yaml` file with content type
`text/yaml`; `Rails.application.routes` in the test env contains the five
product endpoints **plus Rails' internal `/rails/*` and `/cable` entries** (the
route-surface check must filter those out — D-P44).

## Files to create and modify

| File | Responsibility |
|---|---|
| `backend/public/docs/openapi.yaml` (new) | The document (D-P40): OpenAPI 3.0.3 in YAML describing the real API per RF-1…RF-3, with one worked example per endpoint and per error case (RF-3), machine-readable for the replay of RF-6(f) (D-P48). Served raw at `/docs/openapi.yaml` (D-P41). |
| `backend/public/docs/index.html` (new) | The interactive UI page served at `/docs` (D-P42): a small static HTML that loads only the vendored same-origin bundle/CSS and configures `SwaggerUIBundle({ url: '/docs/openapi.yaml', tryItOutEnabled: true, … })` — the served document is the only source (RF-5); no inline rendering logic beyond the config. |
| `backend/public/docs/swagger-ui/{swagger-ui-bundle.js, swagger-ui-standalone-preset.js, swagger-ui.css}` (new — vendored assets) | The UI engine, committed to the repo at a pinned version (D-P42). Fetched **once** from the official `swagger-ui-dist` npm tarball via the documented `docker run --rm -v "$PWD":/w -w /w node:22 …` pattern (host Node is unusable — MEMORY lesson); no `package.json`/lockfile/Gemfile change (C6 — see the flagged decision below). |
| `backend/spec/requests/openapi_spec.rb` (new) | The anti-drift verification of RF-6(a)…(g) plus the served-doc and UI-availability checks (D-P43…D-P48). Runs in the ordinary backend suite → RF-7 is satisfied by construction (no CI change). |
| `README.md` (modify — root README, the documented deliverable) | RF-8: a new section **"Documentación de la API (OpenAPI)"** — repository location of the document, served URL, UI URL, how the anti-drift suite keeps it honest, and the pinned Swagger UI version + how the assets were obtained; add `backend/public/docs/` to the structure tree; flip the "005 — OpenAPI" bullet under **Mejoras Futuras** to entregado (C17 coherence). |

**Nothing else changes:** `backend/config/routes.rb` (the documentation lives in
`public/` and is served statically — it adds **no Rails route**, so the file's
"exactly the five routes" comment stays literally true for the API surface and
the supersession of 001 RF-3 / 004 RF-5 is realized as two static URLs, not new
routes), both controllers, `product.rb`, serializers, `Gemfile`/`Gemfile.lock`,
`docker-compose.yml`, Dockerfiles, `config/environments/*.rb` (static serving is
already enabled in dev and test — verified live), `.github/workflows/ci.yml`
(RF-7: the ordinary suite carries the verification, 003 is consumed as-is),
`frontend/` (spec Out of scope — untouched), seeds, factories, and **every
existing spec file** (C7: the current 124 backend examples stay green untouched).

## The document (D-P40, RF-1…RF-3, NFR-2)

- **Format: OpenAPI 3.0.3, YAML, one hand-written file** at
  `backend/public/docs/openapi.yaml`. Discarded: OpenAPI 3.1 (its JSON-Schema
  alignment buys nothing for this API while 3.0.3 is the most broadly supported
  dialect for UIs and validators); OpenAPI 2.0/Swagger (obsolete); JSON (no
  comments for a hand-maintained file, noisier diffs — the doc is committed and
  human-edited, YAML is the community source format); generating the document
  from the code or tests (rswag-style: a different production model, heavier
  dependency, and it would replace the "committed file verified against code"
  approach the spec fixes).
- **Content skeleton:** `info` (title, `version: 1.0.0`, description noting the
  audit table has no endpoints — at most a note, per 004 RF-8); `servers` with
  the compose-delivered dev base URL `http://localhost:3000` (NFR-2); the five
  operations with the `:id` path parameter, the listing parameters `page` / `q` /
  `active` described with the exact C11 semantics (10/page default page 1,
  case-insensitive `name` substring, active filter, stable order, all
  server-side — RF-1); the `{ "product": { … } }` request wrapper; the success
  envelopes `{ data }` / `{ data, meta }` and statuses 200 / 201 / 204-empty
  (RF-1); `components.schemas` for `Product` exactly as serialized —
  `price` a string of exactly 2 decimals in responses, `created_at`/`updated_at`
  ISO-8601 UTC (RF-2) — the product envelope(s), and the `Error` schema
  (`code` enum `not_found`/`validation_failed`/`internal_error`, `details` only
  on 422); every validation rule as the model implements it including
  `PUT` full-replacement semantics (RF-2); 404 / 422 (body **and** malformed
  listing params) / 500 responses per endpoint with worked examples, the
  documented-as-implemented invalid-JSON → 500 `internal_error`, the generic 500
  example, soft-delete DELETE semantics (204; repeated DELETE → 404) and the
  empty-listing contract (RF-3). No security schemes (the API has none).
- **Request `price` is documented as a JSON number** (e.g. `49.99`, with the
  ≤ 2-decimals rule stated); the response `price` is the 2-decimal string.
  Discarded: numeric string in requests (mirrors the response, but the numeric
  bounds read worse in the schema and the API casts either form); the doc picks
  the one form RF-6(f) then replays, as the spec's edge case requires.

## Serving (D-P41, RF-4)

The document is served **statically by the Rails app from `public/`** at the
fixed URL **`/docs/openapi.yaml`**: `ActionDispatch::Static` returns the file
byte-identical with content type `text/yaml` (verified live in dev; the same
middleware runs in test and in CI's compose stack). Discarded: a
`DocsController` + `send_file` route (an extra controller and route producing
exactly what static serving already provides — byte-identical body, fixed URL —
and complicating the RF-6(a) "no more, no less" route assertion for zero gain);
`Rack::Sendfile`/nginx-level serving (infrastructure beyond this app — C5, and
006's concern); rendering the YAML through a controller action (introduces
formatting/buffering between the committed bytes and the response that RF-6(g)
would then have to police). Byte-identity is **by construction**: the served
file *is* the committed file. Production-mode static serving needs
`RAILS_SERVE_STATIC_FILES` — a one-variable hand-off note to spec 006, out of
scope here (dev and test are enabled today — verified).

## Interactive UI (D-P42, RF-5)

A static page at **`/docs`** (`backend/public/docs/index.html`, served by the
same static middleware — verified live: a directory's `index.html` answers 200
without a redirect) that loads **vendored Swagger UI assets committed in the
repo** and configures them with `url: '/docs/openapi.yaml'` — the UI renders
the **served** document (single source of truth, RF-5) and its try-it-out issues
real same-origin requests against the API (no CORS involved, D-9 untouched).
The page references only same-origin asset paths: **no CDN, no external network
at runtime** — and the suite asserts that statically (below).

**C6 flag — a new asset bundle enters the repo** (see the decision section
below): three committed files from the official `swagger-ui-dist` npm tarball,
pinned version, fetched once at implementation time through the documented
`docker run … node:22` pattern — **no runtime or build-time dependency, no
lockfile change**; the coordinator must record the decision in `MEMORY.md`
before any code, per D-17's gate.

Discarded alternatives: the **`swagger-ui` Ruby gem** (adds a gem and asset-
pipeline coupling to deliver files we can commit directly — C5/C6);
**`rswag`** (generates the document from test definitions — replaces the
hand-written-document-verified-against-code model of RF-6 with a different
architecture and a heavy dependency); **`swagger-ui-react` inside the 002
frontend** (forbidden twice: the frontend must not change, and RF-5 fixes the UI
on the **backend** origin); **CDN `<script src=…>`** (explicitly forbidden by
RF-5); **a hand-rolled vanilla HTML/JS renderer** (zero third-party assets —
the legitimate fallback **if the user rejects the asset-bundle decision** — but
it reimplements OpenAPI rendering and try-it-out in custom JS: more custom code,
worse UX, and its own bugs to maintain — C6 is exactly for this case: the
dependency makes the implementation shorter and safer).

## Anti-drift verification (D-P43…D-P45, D-P48; RF-6, RF-7)

One new request spec, `backend/spec/requests/openapi_spec.rb`, runs inside the
ordinary `bundle exec rspec` suite (RF-7) and parses the document with **Ruby
stdlib `YAML.safe_load`** (Ruby 3.3/Psych 4 safe-by-default) — **no gem**: the
stdlib parses OpenAPI's YAML fine, while generic validator gems
(`committee`, `openapi_parser`, `rswag`) would add dependencies to re-derive
checks this spec states more precisely against the live API (C5/C6). Discarded
also: replaying examples with `curl` against the running dev stack (not hermetic
— needs a seeded DB, cannot run in CI's isolated test env) and a doc lint
service/action (network dependency outside the documented commands — C8).

### Checks (a)…(g), one per RF-6 item

- **(a) Operation and route surface.** Parse the doc: the documented operation
  set is exactly the five `(method, path)` product endpoints. Enumerate
  `Rails.application.routes.routes`, **filter out Rails internals** (`/rails/*`,
  `/cable` — verified present in the test env): the remainder is exactly the
  route entries of those five endpoints (`GET` index, `GET` show, `POST`
  create, `PUT`+`PATCH` update — `resources` draws both verbs for the one
  update action; the document per RF-1 documents `PUT` —, `DELETE` destroy);
  no more, no less. The documentation URLs are asserted as **served URLs**,
  not routes (D-P41): `GET /docs/openapi.yaml` and `GET /docs` answer 200.
  Discarded: parsing `bin/rails routes` output (string scraping of what the
  routes API already returns structurally).
- **(b) Parameters.** The documented parameters per operation equal exactly the
  implemented ones (`:id` on show/update/delete; `page`, `q`, `active` on
  index) — none invented, none missing — asserted against a small expectation
  table in the spec that encodes the 001 contract the controller implements.
- **(c) Success statuses.** Documented success statuses equal the implemented
  ones (200 list/show/update, 201 create, 204 + empty body delete), and the
  replays below confirm them live.
- **(d) Error contract.** Every documented 4xx/5xx response references the
  shared `Error` schema; the `code` enum is exactly
  `{not_found, validation_failed, internal_error}`; documented error statuses
  per operation match the implemented contract; `details` appears only on 422.
- **(e) Product shape.** Replay a real `GET` against fixtures created through
  the API in the same example: the response product's keys equal the documented
  `Product` schema's `properties` keys, and `price` matches the documented
  2-decimal-string pattern. Discarded: calling `serialize_product` directly
  (private method; bypasses routing/HTTP — a live request covers the whole
  path).
- **(f) Replay of the documented examples.** Iterate the document's examples
  (conventions in D-P48) and execute each as a **real
  `ActionDispatch::Integration` request** (the same session every 001/004
  request spec uses, transactional and CI-safe): assert the response status
  equals the documented status; deterministic bodies (errors, envelopes' keys,
  `meta`) are compared deeply; volatile values (`id`, timestamps) by
  presence/type. Coverage: one worked success request per endpoint, 422 on
  invalid body (per-field `details` keys the model really emits) and on
  malformed listing params (`page`/`q`/`active` keys), 404 unknown and
  non-numeric id and repeated DELETE, empty listing (out-of-range page echoing
  `current_page`; no-match `q`), the **documented invalid-JSON body replayed
  as-is → 500 `internal_error`** (reproducible — D-17), and DELETE semantics
  (204 empty; the product gone from listings; SKU reusable is asserted by the
  already-delivered 004 suite, not duplicated here).
- **(g) Byte-identity.** `GET /docs/openapi.yaml`'s body equals
  `File.binread(Rails.root.join('public', 'docs', 'openapi.yaml'))` — in CI
  that file is, by definition, the committed one.

### The generic 500 (simulation, 001 RF-16 precedent)

The documented generic-500 example cannot be *reproduced* on demand, so it is
**verified by simulation**: stub a model call to raise, perform the request,
and assert the live response equals the document's 500 example — the same
mechanism and precedent as 001 RF-16's error-contract spec (D-17).

### UI availability (static part, in the same suite)

`GET /docs` answers 200 HTML that references only same-origin asset paths (a
regex over the body finds no `http://`/`https://` reference — the static
"no CDN" guarantee under CI), and each vendored asset URL answers 200. The
dynamic behavior (rendering, try-it-out) is verified in the browser — next
section.

## UI verification and smoke split (D-P47, DoD)

The implementer has **no browser** (MEMORY lesson): its Done-when items are
HTTP-only — suite green, `curl` checks below, no-external-refs assertion. The
**dynamic browser smoke is assigned to the coordinator/user** (D-13
`agent-browser` + the coordinator's built-in browser, the proven 002 pattern):
open `http://localhost:3000/docs`, confirm the five operations render **from
the served document** (spot-check one example against the YAML), execute one
try-it-out request and see the real API response, and confirm the browser's
network log shows **only same-origin requests**. That smoke is a task-level
item of the final tasks, not an implementer gate.

## Test strategy (RF-7, C12)

RSpec only; this spec adds no frontend suite (Vitest stays 57/57) and no CI
change — the new spec joins the ordinary backend suite 003 already runs.
Commands from `MEMORY.md → Development commands`, all via docker compose:

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec     # 124 today → grows; must be green
docker compose run --rm frontend npm test         # 57/57, unchanged
docker compose exec frontend npm run build        # tsc + vite, unchanged
curl -s http://localhost:3000/docs/openapi.yaml | diff - backend/public/docs/openapi.yaml  # empty diff = byte-identical (RF-6(g), DoD)
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/docs                        # 200 (DoD)
```

- **`openapi_spec.rb`** is organized as one `describe` per RF-6 item with the
  doc loaded **once** (`before(:context)` — `YAML.safe_load` of the committed
  file), then: static assertions (a)–(d), (g); live-shape (e); the replay loop
  (f) with its own fixtures created through the API (no new factory, no seeds
  dependency — the replay is self-contained and hermetic); the simulated-500
  comparison; the UI-availability examples.
- No new gems, no DatabaseCleaner (transactional tests suffice), no frontend
  test changes (C7: all pre-existing suites stay green untouched).

## Verification of this plan

Run the command block before/implementation and after. The plan's risky
assumptions were already proven live in the compose stack (dev **and** test env):
static serving enabled; directory `index.html` served at the clean path; YAML
content type; the routes enumeration and its Rails-internal entries. CI parity
comes for free: the suite runs in the same containers locally and on the runner
(D-14). The DoD's browser item is the coordinator smoke of D-P47.

## Technical decisions (discarded alternative included)

- **D-P40 — OpenAPI 3.0.3 in YAML, one hand-written file at
  `backend/public/docs/openapi.yaml`.** Discarded: 3.1 (no needed feature vs
  3.0.3's tool support), 2.0 (obsolete), JSON (comments/diffs — the file is
  hand-maintained), and code/test-generated documents (different model than the
  spec's committed-file-verified-against-code; heavier — rswag).
- **D-P41 — Served statically from `public/` at `/docs/openapi.yaml`
  (`text/yaml`, byte-identical by construction); no controller, no new route.**
  Discarded: `DocsController` + `send_file` (same result, more code, muddier
  route assertion) and controller-side rendering (buffers the bytes RF-6(g)
  then must police). Production enabling (`RAILS_SERVE_STATIC_FILES`) is a
  hand-off note to 006.
- **D-P42 — `/docs` static HTML + vendored, committed `swagger-ui-dist` assets
  (pinned) rendering the served document.** Discarded: `swagger-ui` gem
  (dependency for committable files), `rswag` (architecture change), CDN
  (forbidden), `swagger-ui-react` (frontend must stay untouched, wrong origin),
  hand-rolled renderer (more custom code, worse UX — the fallback only if the
  C6 asset decision is rejected). **C6: record in MEMORY before code.**
- **D-P43 — Anti-drift = one RSpec request spec parsing the YAML with the Ruby
  stdlib; replay via `ActionDispatch::Integration`.** Discarded: validator gems
  (`committee`/`openapi_parser`/`rswag` — dependencies re-deriving less precise
  checks), external `curl` replay (not hermetic/CI-safe), and a doc-lint
  network service (outside the documented commands — C8).
- **D-P44 — Route-surface check enumerates `Rails.application.routes.routes`
  filtered of Rails internals (`/rails/*`, `/cable` — verified live).**
  Discarded: counting all routes unfiltered (Rails internals would make it
  permanently red) and scraping `bin/rails routes` output (the routes API is
  the same source, structurally usable).
- **(e)-mechanism — Product-shape check via a live request against
  API-created fixtures; compare keys to the schema and the price format.**
  Discarded: invoking `serialize_product` directly (private, bypasses HTTP).
- **D-P45 — The generic 500 is verified by simulation (stub-raise) compared
  against the document's 500 example** (001 RF-16 precedent, D-17). Discarded:
  replaying a *real* unexpected error on demand (by definition unreproducible —
  hence "reproducible examples only" in D-17).
- **D-P46 — README: one new section + structure-tree entry + flipped
  "Mejoras Futuras" bullet.** Discarded: a separate docs README (the root
  README is the documented deliverable since 002/004 — RF-8 coherence, C17).
- **D-P47 — Browser smoke (rendering + try-it-out + network log) assigned to
  the coordinator/user; the implementer proves everything HTTP-reachable.**
  Discarded: user-run manual QA as the only check (the static no-CDN and
  availability assertions already run in CI) and assuming the implementer has a
  browser (MEMORY lesson: it does not).
- **D-P48 — Replay conventions: examples live in standard OpenAPI fields
  (`parameters[].example`, `requestBody…example`, `responses.<status>…example`);
  the `:id` examples use the documented sentinel `"<existing-id>"`, which the
  replay substitutes with the id of a product it creates via the documented
  POST example; deterministic fields compared deeply, volatile ones by
  presence/type; listing/error replays run against those fixtures.**
  Discarded: hard-coded numeric ids in the examples (unreplayable against a
  fresh DB — the example would lie everywhere but one seeded box) and
  replay-spec-side hardcoded requests (then (f) would not iterate the
  *document* — editing a doc example would not be exercised, which is the
  whole point of RF-6).

## RF coverage map

| Part | Covers |
|---|---|
| `backend/public/docs/openapi.yaml` | RF-1, RF-2, RF-3 (all coverage/content items), NFR-2, D-17 (500 + supersession) |
| Served statically at `/docs/openapi.yaml` (D-P41) | RF-4 (fixed URL, raw content type, discoverable via README) |
| `backend/public/docs/index.html` + vendored assets (D-P42) | RF-5 (interactive UI at `/docs`, served document only, self-contained, no CDN) |
| `openapi_spec.rb` — (a)–(d), (g) + UI availability | RF-6(a)(b)(c)(d)(g), RF-5 (static no-CDN), RF-7 (ordinary suite) |
| `openapi_spec.rb` — (e) live shape | RF-6(e) |
| `openapi_spec.rb` — (f) replay loop + invalid-JSON 500 replay | RF-6(f), RF-3 (500-as-implemented), D-17 |
| `openapi_spec.rb` — simulated 500 vs doc example | RF-6(f) generic-500 leg (001 RF-16 precedent), D-17 |
| `README.md` (RF-8 section, tree, bullet) | RF-8, C17 coherence |
| Coordinator browser smoke (D-P47) | RF-5 dynamic leg, DoD |

## Out of scope for this plan

Everything under the spec's Out of scope: spec `006-deploy` (including the
`RAILS_SERVE_STATIC_FILES` production hand-off note above), authentication/
authorization docs, any audit API or audit documentation beyond the at-most-one
note, **any change to the five endpoints' behavior/shapes/error contract** (this
spec documents them; if reality contradicts the document during implementation,
stop and report — C2), changes to the delivered React frontend (spec 002 — the
docs UI is separate and backend-origin), new business endpoints, API versioning
beyond `/v1`, new gems or npm dependencies (the vendored assets are files, not
dependencies — the flagged C6 decision covers them), and any edit to existing
spec files or the CI workflow (C7).
