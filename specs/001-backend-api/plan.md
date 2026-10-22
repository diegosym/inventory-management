# Plan 001 — Backend API (Product CRUD)

Status: approved

Derived from the approved `spec.md` (RF-1…RF-16, NFR-1…NFR-3, DoD). Everything
runs through `docker compose` per D-1/C8 and `MEMORY.md → Development commands`.
This plan fixes the two items the spec delegated to it: the exact error JSON
shape (RF-7) and the name-search parameter name (RF-10).

## Files to create and responsibilities

| File | Responsibility |
|---|---|
| `docker-compose.yml` (root) | Services `db` (`postgres:16`) and `backend` (`ruby:3.3`); env wiring between them; named volume for the database. `frontend` service is **deferred to spec 002** (decision D-P6). |
| `.env.example` | Documents every variable: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DATABASE_URL`, `FRONTEND_ORIGIN` — placeholders only (NFR-2, C16). |
| `.gitignore` (update) | Ignore `.env`, `.env.*.local`. |
| `backend/Dockerfile` | `ruby:3.3` image; installs build deps for `pg`; `bundle install` at build time; boots `puma` on port 3000. No local Ruby on the host. |
| `backend/Gemfile`, `backend/Gemfile.lock` | Runtime: `rails` (API mode), `pg`, `rack-cors`. Test group: `rspec-rails`, `factory_bot_rails`. Nothing else (C6 — see decisions). |
| `backend/config.ru`, `backend/Rakefile`, `backend/bin/rails`, `backend/bin/rake` | Minimal Rails API app entry points (generated skeleton, API mode only). |
| `backend/config/application.rb` | API-only Rails app (`load_defaults` current), no view/asset stack. |
| `backend/config/boot.rb`, `backend/config/environment.rb`, `backend/config/environments/{development,test,production}.rb` | Standard environment config; test env uses transactional fixtures. |
| `backend/config/database.yml` | Reads `DATABASE_URL` / `POSTGRES_*` from env; test DB separate (NFR-2). |
| `backend/config/routes.rb` | Exactly the five `/api/v1/products` routes (RF-3), namespaced `api/v1`. |
| `backend/config/initializers/cors.rb` | `rack-cors`: allow origin from `FRONTEND_ORIGIN`, methods `GET POST PUT DELETE OPTIONS`, any headers (RF-8). |
| `backend/config/initializers/filter_parameter_logging.rb` | Standard parameter filtering. |
| `backend/app/controllers/application_controller.rb` | The single error contract: three `rescue_from` handlers (404 / 422 / 500) plus a private `render_error` helper that always renders the same JSON shape (RF-7, C10). |
| `backend/app/controllers/api/v1/products_controller.rb` | The five actions. List-param validation and listing pipeline live here; **no business validation** (C9). |
| `backend/app/models/application_record.rb` | Standard abstract class. |
| `backend/app/models/product.rb` | All business validations (RF-1, RF-2), SKU normalization (D-6), `description`/`active` normalization for PUT (RF-4), unique index backing. |
| `backend/db/migrate/XXXXXX_create_products.rb` | Columns: `name` (string, not null), `description` (text, default `""`), `price` (decimal(10,2), not null), `stock` (integer, not null, default 0), `sku` (string, not null), `active` (boolean, not null, default true); timestamps; **unique index on `sku`**. |
| `backend/db/seeds.rb` | Idempotent demo dataset (RF-15): `find_or_create_by!(sku:)`, >10 products, mix of active/inactive, varied names, prices > 0. |
| `backend/.gitignore` | `log/`, `tmp/`, `storage/`, etc. (generated skeleton). |
| `backend/.rspec` | `--require spec_helper`, documentation format. |
| `backend/spec/rails_helper.rb` | RSpec + FactoryBot config, transactional tests, environment boot. |
| `backend/spec/factories/products.rb` | Product factory with valid defaults (D-6-compliant SKUs). |
| `backend/spec/models/product_spec.rb` | Every validation, boundary, and normalization rule (RF-1, RF-2, RF-16). |
| `backend/spec/requests/api/v1/products_spec.rb` | Endpoint behavior: success, 404, 422 per endpoint; PUT edge cases (RF-3…RF-8, RF-16). |
| `backend/spec/requests/api/v1/products_listing_spec.rb` | Pagination, search, filter, malformed params, no-match (RF-9…RF-14, RF-16). |
| `backend/spec/requests/api/v1/error_contract_spec.rb` | The 500 branch: force an unexpected exception, assert the generic shape leaks nothing (RF-7, RF-16). |
| `backend/spec/seeds_spec.rb` | Run `Rails.application.load_seed` twice: dataset present (>10, mix) and idempotent (RF-15, RF-16). |

## API surface

Base path: `/api/v1`. Request bodies are wrapped: `{ "product": { … } }`.
All success bodies wrap the resource in `data`.

### Product serialization (single shape everywhere)

```json
{
  "id": 1,
  "name": "Mechanical Keyboard",
  "description": "Brown switches",
  "price": "49.99",
  "stock": 12,
  "sku": "KB-001",
  "active": true,
  "created_at": "2026-01-10T12:00:00Z",
  "updated_at": "2026-01-10T12:00:00Z"
}
```

`price` is a decimal **string** with 2 decimals (decision D-P5).

### Error contract (RF-7 — fixed here per the spec)

One shape for **every** error (404, 422, 500):

```json
{
  "error": {
    "code": "not_found | validation_failed | internal_error",
    "message": "Human-readable summary",
    "details": { "field": ["message", "…"] }
  }
}
```

- `details` appears **only on 422**, keyed by the offending field (or query
  parameter) with its Rails validation messages — NFR-3, the frontend mirrors
  them (C14). Example 422:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Validation failed",
    "details": {
      "name": ["is too short (minimum is 3 characters)"],
      "sku": ["has already been taken"]
    }
  }
}
```

- 404: `{ "error": { "code": "not_found", "message": "Product not found" } }` —
  no `details`.
- 500: `{ "error": { "code": "internal_error", "message": "Internal server error" } }`
  — generic only, exception logged server-side, internals never exposed.
- Malformed query parameters (RF-13) reuse this same shape with
  `code: "validation_failed"` and the **parameter name** as the details key,
  e.g. `{ "page": ["must be a positive integer"] }` (decision D-P11).

### Endpoints

| Endpoint | Params | Success | Failures |
|---|---|---|---|
| `GET /api/v1/products` | `page` (optional positive integer, default 1), `q` (optional name search — decision D-P2), `active` (optional `true`/`false`) | 200, see below | 422 malformed params (RF-13) |
| `GET /api/v1/products/:id` | — | 200 `{ "data": { product } }` | 404 unknown or non-numeric id (RF-5) |
| `POST /api/v1/products` | body `{ "product": { … } }` | 201 `{ "data": { product } }` | 422 with per-field details (RF-2) |
| `PUT /api/v1/products/:id` | body `{ "product": { … } }` | 200 `{ "data": { product } }` | 404, 422 (RF-4, RF-5) |
| `DELETE /api/v1/products/:id` | — | 204, empty body | 404 (RF-5, RF-6) |

Listing response (RF-9 metadata: `current_page`, `total_count`, `total_pages`):

```json
{
  "data": [ /* 0–10 products, created_at DESC, id DESC */ ],
  "meta": { "current_page": 2, "total_count": 23, "total_pages": 3 }
}
```

Behavioral notes:

- `q`: substring match on `name`, case-insensitive, computed in PostgreSQL;
  whitespace-only or empty `q` = no term (full listing); `%`/`_` in the term are
  escaped so they match literally (RF-10).
- `active`: exact match filter in the database (RF-11). `active=` (empty) is
  "other than true/false" → 422, per RF-13.
- Search + filter + pagination combine server-side; stable order (RF-12).
- Out-of-range page → 200, empty `data`, `meta.current_page` echoes the request
  (RF-13); no match on search/filter → 200 empty list, never 404 (RF-14).

### Listing pseudocode (the only non-obvious algorithm)

```
def index
  errors = {}
  errors[:page]   = ["must be a positive integer"]  if page present and !page.match?(/\A[1-9]\d*\z/)
  errors[:active] = ["must be true or false"]        if active present and active not in ["true","false"]
  errors[:q]      = ["must be a string"]             if q present and q is not a String
  render 422 validation_failed(details: errors) if errors.any?

  scope = Product.all
  scope = scope.where(active: active == "true")                    if active present
  scope = scope.where("name ILIKE ?", "%#{sanitize_sql_like(q.strip)}%") if q present and q.strip.present?
  scope = scope.order(created_at: :desc, id: :desc)

  total      = scope.count
  current    = (page presence || 1)
  render data: scope.limit(10).offset((current - 1) * 10),
         meta: { current_page: current, total_count: total, total_pages: (total / 10.0).ceil }
end
```

Model-side normalization (PUT semantics, RF-4): `before_validation` uppercases
`sku` and turns a `nil` `description` into `""`; `active` is validated with
`inclusion in [true, false]` (so `active: null` → 422) and, on update, is only
assigned when the key is present in the payload (omitted → keeps its value).
`price` gets `numericality greater_than: 0` plus a precision check
(`price != price.round(2)` → 422) because PostgreSQL would silently round
`9.999` at write time.

## Test strategy (RF-16, C12)

RSpec only; this spec includes **no frontend suite** (spec 002 adds one). All
commands via docker compose, from `MEMORY.md → Development commands`:

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec
```

- **Model spec** — one example per rule and boundary of RF-1/RF-2: name 2/3/100/101
  chars; description 1000/1001; price 0, negative, `9.999`, non-numeric, valid
  `49.99`; stock 0, −1, non-integer; sku missing, bad charset, duplicate, and
  normalization `abc-123` → `ABC-123` (D-6); `active` default and invalid values.
- **Request specs** — per endpoint: 201/200/204 success shapes; 422 with the exact
  per-field `details`; 404 for unknown **and** non-numeric ids (never 500); PUT
  edge cases (a) omitted `active` on an inactive product stays inactive,
  (b) omitted/`null` `description` stored empty, (c) `active: null` → 422;
  own SKU on update valid vs another product's SKU → 422.
- **Listing spec** — page 1 default, page 2 content, out-of-range page (200 empty,
  echoed `current_page`); `q` case-insensitive substring, whitespace-only → full
  list; `active=true`/`false`; all three combined; no match → 200 empty;
  malformed `page` / `active` → 422 with parameter-keyed details; stable order.
- **Error contract spec** — force an unexpected exception (stub a model call to
  raise) and assert 500 with the generic shape and no internals; CORS: a request
  with `Origin` (and a preflight `OPTIONS`) returns
  `Access-Control-Allow-Origin` from `FRONTEND_ORIGIN` (RF-8).
- **Seeds spec** — `load_seed` twice; assert >10 products, active/inactive mix,
  and unchanged count on the second run (RF-15).
- Factories (`factory_bot_rails`) keep setup short; no Faker (fixed, readable
  seed/factory data), no DatabaseCleaner (transactional tests suffice).

## Technical decisions (discarded alternative included)

- **D-P1 — Error JSON shape:** nested `{ "error": { code, message, details } }`.
  Discarded: flat top-level fields (collides with the `data` wrapper convention
  and leaves no namespace for later specs) and RFC 7807 `application/problem+json`
  (media-type negotiation for zero user-visible benefit — C5).
- **D-P2 — Search parameter is `q`.** Discarded: `search`/`name`/`query` (longer,
  no gain; `q` is the Rails/elastic convention and keeps URLs short).
- **D-P3 — Plain `limit`/`offset` + `count` in the controller.** Discarded:
  Kaminari/Pagy (a gem dependency to save ~4 lines for a fixed 10/page — fails
  C6; revisit only if a future spec needs configurable page sizes).
- **D-P4 — Dependencies:** `pg` (required driver), `rack-cors` (ships with the
  Rails bundle but must be enabled — RF-8), `rspec-rails` (C8/D-1), and
  `factory_bot_rails` in the test group (materially shortens and hardens the
  RF-16 suite). Discarded: Faker, DatabaseCleaner, jbuilder (plain `render json:`).
- **D-P5 — `price` serialized as the string `"49.99"`.** Discarded: JSON float
  (binary float precision loss in JS) and integer cents (would silently define
  the contract spec 002 consumes).
- **D-P6 — No `frontend` service in this compose file; spec 002 adds it.**
  An empty `node` container has nothing to run or build (C5); D-1's layout
  (`backend/` + `frontend/` + root compose) is preserved because 002 extends the
  same `docker-compose.yml`.
- **D-P7 — Rails current stable (8.x) on the local `ruby:3.3` image;
  `postgres:16` per MEMORY.** Discarded: Rails 7.x (shorter support window, no
  benefit for a greenfield API).
- **D-P8 — SKU normalization and all validations in the model
  (`before_validation`), never in the controller** (C9); the unique index in
  PostgreSQL backs uniqueness (D-6).
- **D-P9 — Error handling via `rescue_from` in `ApplicationController` with one
  `render_error` helper.** Discarded: a BaseController/concern hierarchy or a
  gem (one controller exists today — C5; a base class can wait until a second
  controller appears).
- **D-P10 — Request bodies wrapped as `{ "product": { … } }`.** Discarded: flat
  bodies (Rails strong-params convention; keeps the controller trivial).
- **D-P11 — Malformed-query 422 reuses the standard shape** with
  `code: "validation_failed"` and the parameter name as the details key.
  Discarded: a distinct code/shape (RF-7 mandates a single shape).
- **D-P12 — PUT semantics in the model + key-presence check in the controller:**
  `description` nil → `""` and `active` inclusion `[true, false]` live in the
  model; the controller assigns `active` only when the payload key exists
  (omitted → unchanged, `null` → 422). Discarded: defaulting logic in the
  controller (would duplicate model rules — C9).

## RF coverage map

| Part | Covers |
|---|---|
| `docker-compose.yml`, `backend/Dockerfile`, `.env.example`, env-based config | NFR-1, NFR-2, DoD |
| Product migration + model + validations | RF-1, RF-2, RF-4 (semantics), D-6 |
| `application_controller.rb` (`render_error`, `rescue_from`) | RF-2 (422 leg), RF-5, RF-7, RF-13 |
| `products_controller.rb` — create/update/destroy/show | RF-3, RF-4, RF-5, RF-6 |
| `products_controller.rb` — index | RF-9, RF-10, RF-11, RF-12, RF-13, RF-14 |
| `cors.rb` initializer | RF-8 |
| `db/seeds.rb` | RF-15 |
| `spec/` (all suites) | RF-16, NFR-3 (via asserted `details` keys) |

## Out of scope for this plan

Frontend anything (spec 002, including its tests and the project README),
CI (003), soft delete/audit (004), OpenAPI (005), deploy (006), authentication,
`per_page`, and any gem beyond D-P4 (C6, C2).
