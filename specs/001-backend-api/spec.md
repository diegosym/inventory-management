# Spec 001 — Backend API (Product CRUD)

Status: implemented

## Context and goal

First core increment of the challenge (`docs/Reto técnico.pdf`, C2): the product
CRUD backend every later spec builds on — scaffolding per D-5, the Product model
and its validations, the five `/api/v1/products` endpoints, server-side
pagination / search / filter (C11), the error contract (C10), functional seeds,
and the RSpec suite. The statement's SKU wording is settled by **D-6** — not
reopened here.

## Users

- API consumers: the React frontend (spec 002), any HTTP client, and the evaluator.

## User stories

- US-1. As a frontend developer, I want a REST API to create, read, update, and delete products, so that I can build the UI against it.
- US-2. As an API client, I want server-side pagination, name search, and an active/inactive filter, so that large inventories stay navigable.
- US-3. As an API client, I want consistent error responses (404/422/500, with per-field detail on 422), so that I can render precise feedback.
- US-4. As an evaluator, I want functional seeds and an RSpec suite, so that I can run and verify the backend quickly.

## Definitions

- **Product**: `name`, `description` (optional), `price`, `stock`, `sku`, `active` (default `true`), timestamps — no other fields.
- **SKU normalization** (D-6, settled): uppercased before validating; then must
  match `\A[A-Z0-9-]+\z` and be unique. `abc-123` → `ABC-123`.
- **Active product**: business flag only; the default listing includes inactive products unless filtered.

## Functional requirements

### Model and validations (C9 — in the model, never duplicated elsewhere)

- RF-1: WHEN a product is created or updated, THE SYSTEM validates: `name`
  present, 3–100 characters; `description` at most 1000 characters (omission
  allowed); `price` a decimal of scale 2, greater than 0, with at most 2
  decimals (more decimals → invalid); `stock` integer and not negative; `sku`
  present, normalized per D-6, unique; `active` a boolean defaulting to `true`.
- RF-2: IF any field fails validation, THE SYSTEM rejects the operation with HTTP
  422, reports the detail of each invalid field, and persists nothing.

### Endpoints (C11)

- RF-3: THE SYSTEM exposes exactly: `GET /api/v1/products`, `GET
  /api/v1/products/:id`, `POST /api/v1/products`, `PUT /api/v1/products/:id`,
  `DELETE /api/v1/products/:id`.
- RF-4: WHEN a valid `POST` is received, THE SYSTEM persists the product and
  answers 201 with the created product; WHEN a valid `PUT` is received, it
  answers 200 with the updated product. `PUT` is a full replacement under the
  same validations as create: required fields (`name`, `sku`, `price`, `stock`)
  omitted or `null` → 422; `description` omitted or `null` → stored empty;
  `active` omitted → keeps its current value (never resets to `true`); `active: null` → 422.
- RF-5: IF the `:id` of a `GET`, `PUT`, or `DELETE` does not exist — or is not a
  number (`/api/v1/products/abc`) — THE SYSTEM answers 404 with the standard
  error shape, never 500.
- RF-6: WHEN a valid `DELETE` is received, THE SYSTEM permanently removes the
  product and answers 204. (Soft delete belongs to spec 004.)
- RF-7: THE SYSTEM answers every error (404/422/500) with a single JSON shape; a
  422 lists the failing fields; a 500 uses a generic message and never exposes
  internals (C10). The exact JSON shape is fixed in `plan.md`.
- RF-8: THE SYSTEM accepts cross-origin requests from the frontend origin
  (CORS — required by the statement).

### Listing: pagination, search, filter — always server-side (C11)

- RF-9: THE SYSTEM paginates `GET /api/v1/products` at exactly 10 items per page
  (fixed; no `per_page` parameter); the response carries the data plus
  pagination metadata (current page, total items, total pages) sufficient for
  the client to render controls. The exact JSON shape is fixed in `plan.md`.
- RF-10: WHEN a name search term is provided, THE SYSTEM returns only products
  whose `name` contains the term as a substring, case-insensitive, computed in
  the database; a term of only whitespace counts as no term (full listing).
  The exact parameter name is fixed in `plan.md`.
- RF-11: WHEN an `active` filter (`true`/`false`) is provided, THE SYSTEM
  returns only products in that state, computed in the database.
- RF-12: THE SYSTEM applies search, filter, and pagination together on the
  server, ordering by `created_at DESC` with `id DESC` as tie-breaker so pages
  are stable.
- RF-13: IF a query parameter is malformed (empty or non-integer `page`,
  `active` other than `true`/`false`), THE SYSTEM answers 422; a valid but
  out-of-range page answers 200 with an empty list and metadata whose
  `current_page` echoes the requested page.
- RF-14: WHEN a search or filter yields no match, THE SYSTEM answers 200 with an
  empty list — never 404.

### Seeds

- RF-15: WHEN the seeds run, THE SYSTEM contains a functional demo dataset: more
  than 10 products (enough for at least two pages), a mix of active and
  inactive, valid SKUs per D-6, prices greater than 0, and varied names that
  exercise the search. Re-running `db:seed` must not duplicate it (idempotent).

### Tests (C12)

- RF-16: THE SYSTEM's RSpec suite covers every model validation, every endpoint
  (success, invalid data, missing resource), pagination, search, and filter
  behavior, plus the 500 branch of the error contract (RF-7, simulating an
  unexpected error), CORS (RF-8), and the seeds (RF-15); it passes with
  `docker compose exec backend bundle exec rspec`.

## Non-functional requirements

- NFR-1: The backend runs 100% through Docker Compose (D-1, C8); verification
  uses only the commands in `MEMORY.md → Development commands`.
- NFR-2: All configuration (database credentials, CORS origin) goes through
  environment variables; nothing secret is committed; `.env.example` documents what is needed (C16).
- NFR-3: Validation messages identify the offending field so the frontend
  (spec 002) can mirror them exactly (C14).

## Edge cases

- SKU `abc-123` → stored as `ABC-123`; keeping an own SKU on update is valid,
  taking another product's SKU → 422.
- `name` of exactly 3 or 100 characters valid; 2 or 101 → 422. `price` of 0,
  negative, or with more than 2 decimals (e.g. `9.999`) → 422; `stock` of 0 is
  valid, negative → 422. `description` omitted or empty valid; over 1000
  characters → 422. Non-numeric `price`/`stock`, non-boolean `active` → 422.
- `PUT` edge cases: (a) omitting `active` on an `active: false` product stays
  inactive; (b) omitting/nulling `description` → stored empty; (c) `active: null` → 422.
- `GET`/`PUT`/`DELETE` with an unknown or non-numeric id → 404 with the standard
  error shape (never 500).
- Page beyond the last page → 200 with an empty list and `current_page` echoing
  the requested page; whitespace-only search → full listing.

## Out of scope

- Frontend UI → spec `002-frontend-ui` (also delivers the project `README.md`,
  decided as OQ-4).
- CI (GitHub Actions) → spec `003-ci`; OpenAPI docs → spec `005-openapi`;
  deployment → spec `006-deploy`.
- Soft delete and change audit → spec `004-data-integrity` (this spec deletes
  permanently).
- Authentication of any kind — the statement does not require it (C2).
- Extra gems/libraries beyond what the plan justifies (C6).

## Definition of done

- All RFs implemented, each covered by a passing test.
- `docker compose up -d --build` brings up db + backend;
  `docker compose exec backend bin/rails db:prepare db:seed` yields the RF-15
  dataset; `docker compose exec backend bundle exec rspec` is green.
- No secrets committed; each task landed as one specific commit (C17).

## Open questions

None — OQ-1 (search semantics), OQ-2 (listing order), OQ-3 (malformed query
parameters), and OQ-4 (README delivery) were resolved by the user and are now RF-10, RF-12, RF-13, and the "Out of scope" note.
