# Spec 005 — API Documentation (OpenAPI)

Status: approved

## Context and goal

Penultimate bonus increment (D-4): "Documentación de API (Swagger/OpenAPI)" of the
statement (`docs/Reto técnico.pdf`, C2). Delivers a machine-readable OpenAPI document
describing the **real, current API** — the five `/api/v1/products` endpoints as merged
by specs 001 and 004 (soft delete, audit not exposed) — an interactive UI to explore
it (user decision), and a guarantee that the document cannot silently lie about the
code (anti-drift). Supersedes spec 001 RF-3 ("exactly the five routes") and spec 004
RF-5 ("same five routes") in one point each (C3): the route surface grows by the
documentation routes of RF-4 and RF-5; every other 001/004 contract stays exactly as
documented (C10, C11).

## Users

- API consumers integrating or evaluating the API, and future maintainers who need
  the contract to stay truthful.

## User stories

- US-1. As an API consumer, I want a complete OpenAPI document of every endpoint,
  parameter, body, success shape, and error with examples, so that I can integrate
  without reading the backend code.
- US-2. As an evaluator, I want the document in the repository, served by the API,
  and through an interactive UI, so that I can inspect and try the API in seconds.
- US-3. As a maintainer, I want an automated check that fails whenever the code and
  the document diverge, so that the documentation never goes stale.

## Definitions

- **The document**: one OpenAPI 3 description (minor version and YAML/JSON fixed by
  the plan) of the complete API; the code remains the source of truth.
- **Anti-drift verification**: the automated check comparing the document against the
  implemented routes and contracts (RF-6).
- **Served document**: the document retrievable over HTTP from the running API at a
  fixed URL as raw OpenAPI content (raw by design; the interactive UI of RF-5 is a
  separate route).

## Functional requirements

### Coverage — the document describes the real API (C2, C10, C11)

- RF-1: THE SYSTEM's document describes all five endpoints — `GET /api/v1/products`,
  `GET /api/v1/products/:id`, `POST /api/v1/products`, `PUT
  /api/v1/products/:id`, `DELETE /api/v1/products/:id` — with methods, paths, the
  `:id` path parameter, query parameters `page` (positive integer), `q` (string),
  and `active` (`true`/`false`) **with the listing semantics of 001 RF-9–RF-12
  (C11): 10 items per page (default page 1), `q` a case-insensitive substring on
  `name`, `active` an active/inactive filter, stable order `created_at DESC, id
  DESC`, all server-side**; the `{ "product": { … } }` request wrapper; the success
  envelopes (`{ data }` for show/create/update, `{ data, meta }` for the list, with
  `meta.current_page`, `meta.total_count`, `meta.total_pages`); and the success
  statuses: 200 (list, show, update), 201 (create), 204 empty body (delete).
- RF-2: THE SYSTEM's document describes the product resource exactly as serialized:
  `id`, `name`, `description`, `price` **as a string of exactly 2 decimals**
  (responses), `stock` integer, `sku` uppercase-normalized, `active` boolean,
  `created_at`/`updated_at` as ISO-8601 UTC — and states each field's validation
  rules as the model implements them (C9): `name` 3–100 chars, `description` ≤ 1000
  chars, `price` > 0 with at most 2 decimals, `stock` integer ≥ 0, `sku` required,
  matching `[A-Z0-9-]+` after uppercasing, unique among non-deleted products,
  `active` a boolean — **and the request-body rules of 001 RF-4: in `POST`, `name`,
  `sku`, `price`, and `stock` are required, `description` optional, `active`
  defaults to `true`; `PUT` is a full replacement — an omitted required field →
  422, an omitted `description` → stored empty, an omitted `active` → keeps its
  current value**.
- RF-3: THE SYSTEM's document describes the full error contract (C10) for every
  endpoint: 404 `not_found` (unknown **and** non-numeric id; a soft-deleted
  product's id on show/update/delete, including a repeated DELETE), 422
  `validation_failed` with `details` keyed by field (invalid body **and** malformed
  listing parameters: non-positive/non-integer `page`, `active` other than
  `true`/`false`, non-string `q`), 500 `internal_error` with a generic message —
  all under the single `{ "error": { "code", "message", "details" } }` shape,
  `details` present only on 422. It also documents `DELETE`'s real semantics (204;
  the product disappears and its SKU becomes reusable), the list's empty results
  (no match or out-of-range page → 200, empty `data`, `meta` echoing the requested
  page), and **a syntactically invalid JSON body, which the delivered API answers
  with 500 and the standard `internal_error` shape (observed live in the running
  stack) — documented as implemented**. At least one worked example per endpoint
  and per error case, the 500's generic shape included (user decision).

### Availability — the document and the interactive UI

- RF-4: THE SYSTEM keeps the document committed in the repository, and the running
  API serves it at a fixed URL (path fixed by the plan) answering 200 with the raw
  OpenAPI content and an appropriate content type; the URL is discoverable from the
  README (RF-8). (User decision: both the repository file and the served document.)
- RF-5: THE SYSTEM serves an interactive documentation UI at a fixed path on the same
  backend origin (proposed `/docs`; the plan confirms it), **self-contained: its
  assets are served by the application itself — no external CDN or other network
  access in the browser at runtime** (user decision). WHEN a client opens that URL
  in a browser, THE SYSTEM renders the OpenAPI document served per RF-4 — never a
  second, diverging copy — exposing all five operations with their parameters,
  bodies, and examples, and lets the client execute a real request against the API
  and see the actual response. The UI adds no endpoint and changes no API behavior:
  it consumes the same public API. The plan chooses the mechanism (C6): **any new
  dependency or asset bundle requires a decision recorded in `MEMORY.md` before code
  — to be registered by the coordinator.**

### Anti-drift — the document must not lie (the key requirement)

- RF-6: THE SYSTEM's automated backend suite includes a verification that parses the
  committed document and **fails whenever it diverges from the implemented API**.
  At minimum it asserts, with the code as the source of truth: (a) the documented
  set of operations equals the five product endpoints, and the application serves
  exactly those five plus the documentation routes (RF-4 document route and RF-5 UI
  route) — no more, no less; (b) the documented parameters per operation (`:id`,
  `page`, `q`, `active`) are exactly the implemented ones — none invented, none
  missing; (c) documented success statuses match the implemented ones; (d)
  documented error statuses, codes, and shared shape match the implemented
  contract; (e) documented product fields match the serializer's (including the
  2-decimal string `price`); (f) every reproducible request/response example in the
  document is exercised against the API and returns the documented status and
  shapes — the 500's generic shape is verified by simulating an unexpected error
  (precedent: 001 RF-16), and the reproducible invalid-JSON 500 of RF-3 is replayed
  like any other request; (g) the document served per RF-4 is byte-identical to the
  committed file. A code change that breaks any of these fails the verification (and
  the suite/CI) until the document is updated in the same change. The plan selects
  the mechanism and tooling (C6); the spec fixes only this behavior.
- RF-7: THE SYSTEM runs the RF-6 verification as part of the ordinary backend suite —
  `docker compose exec backend bundle exec rspec` — so it executes in the spec-003
  CI pipeline unchanged and green (C7: all pre-existing tests keep passing).

### Documentation upkeep (C17)

- RF-8: THE SYSTEM's `README.md` documents the OpenAPI description: where the
  document lives (repository location and served URL), the UI's URL, and how the
  anti-drift verification keeps it honest — coherent with the delivered reality.

## Non-functional requirements

- NFR-1: Verification uses only the commands in `MEMORY.md → Development commands`;
  the stack is unchanged (C8); no new dependency unless the plan justifies it and
  `MEMORY.md` records it before code (C6) — a hand-written document plus a parsing test is valid.
- NFR-2: The document is machine-readable and well-formed OpenAPI 3, and its
  `servers` entry is **relative** — `servers: [{ url: "/" }]`, "the server that
  serves the document" — so the base is never invented: it resolves to the
  serving origin, i.e. in development the base URL docker compose actually
  delivers (`http://localhost:3000`) and in production the deployed origin.

## Edge cases

- Future change adds, removes, or reshapes an endpoint → RF-6 fails red until the
  document matches: the verification is the safety net, not a one-time review.
- `DELETE` is documented as a soft delete (004 RF-1/RF-3): the doc must never claim
  permanent removal; a repeated DELETE is documented as 404.
- The `{ "product": … }` wrapper is the documented request contract; the bare-body
  quirk (D-9, `wrap_parameters`) is an implementation detail the document omits. A
  syntactically invalid body is not a 422 client error but the 500 of RF-3 (observed
  live), and `PUT`'s full-replacement rules (001 RF-4) are documented per RF-2.
- Documented 422 examples carry the per-field `details` keys the model really emits
  (`name`, `description`, `price`, `stock`, `sku`, `active`); malformed-parameter
  422s are keyed by the parameter name (`page`, `q`, `active`). A 500 is documented
  generically, never with internals.
- Request `price` representation (decimal number vs numeric string) is documented
  consistently with one form the API accepts and RF-6(f) replays.
- The UI renders the RF-4 served document (one source of truth), serves its own
  assets (no external network in the browser), and calls the API same-origin from
  the backend origin (CORS/D-9 untouched); a UI failure never affects the API.
- An **absolute** `servers` URL (e.g. `http://localhost:3000`) makes try-it-out
  target the wrong origin wherever the document is served from another origin
  (production): that is an NFR-2 defect. Because RF-6(g) keeps the served copy
  byte-identical to the committed file, the correction is made in the committed
  document — no UI-side override, no second copy of the base.

## Out of scope

- Deployment/hosting of anything (spec `006-deploy`) and any live-URL assumptions.
- Authentication/authorization documentation — the API has none (C2).
- Any audit API or audit documentation beyond at most a note that the change audit
  (004) is an internal table with no endpoints (004 RF-8).
- Any change to the five product endpoints' behavior, shapes, or the error contract —
  this spec documents them; it only adds the documentation routes (declared in Context).
- Changes to the delivered React frontend app (spec 002): the documentation UI of
  RF-5 is separate from it. New business endpoints; API versioning beyond `/v1`.

## Definition of done

- All RFs implemented; the backend suite — including the RF-6 verification — passes
  with `docker compose exec backend bundle exec rspec`, pre-existing suites included (C7).
- `docker compose up -d --build` then fetching the RF-4 URL returns the committed
  document with 200.
- Opening the RF-5 UI URL in a browser loads it without errors and without external
  network access (assets served by the app), shows all five documented operations
  with the document's examples, and a request executed from the UI renders the API's
  real response (the plan/tasks distribute the checks).
- README updated per RF-8; no secrets committed; each task lands as one specific commit (C17).

## Open questions

- None: every open point is settled — repository file **and** API-served document
  (RF-4); interactive UI in scope (RF-5), self-contained with app-served assets and
  no CDN at runtime (user decisions). Plan decisions, not spec ambiguities: paths,
  OpenAPI version, YAML/JSON, UI mechanism (any dependency → MEMORY before code).
