# Tasks 001 — Backend API (Product CRUD)

Derived from the approved `spec.md` (RF-1…RF-16, NFR-1…NFR-3, DoD) and the
user-approved `plan.md` (file/API surface, D-P1…D-P12, test strategy).

Approvals verified before generating this file:

- `spec.md` → `Status: approved`.
- `plan.md` → `Status: approved` (approved by the user's explicit approval;
  `MEMORY.md` roadmap: "spec + plan approved (tasks next)").

Rules:

- One task = one task-specific commit (C17); tests first, then the code.
- All checks use only `MEMORY.md → Development commands` (everything via
  `docker compose`; RSpec is mandatory).
- Dependency order: T1 → T2 → T3 → T4 → T5 → T6 → T7 (each task keeps `main`
  functional — C7).

## Tasks

- [x] **T1. Scaffold the Dockerized Rails API workspace.** Root `docker-compose.yml`
  (`db` + `backend` only, per D-P6), `backend/Dockerfile`, Rails API-mode skeleton,
  env-based configuration (`DATABASE_URL` / `POSTGRES_*`, `.env.example` with
  placeholders, updated `.gitignore`), and RSpec + FactoryBot wired (`.rspec`,
  `spec/rails_helper.rb`, product factory). NFR-1, NFR-2, DoD (bring-up)
  - Done when: `docker compose up -d --build` starts db + backend,
    `docker compose exec backend bin/rails db:prepare` succeeds against the
    compose database, and `docker compose exec backend bundle exec rspec` runs
    green — as one task-specific commit.

- [ ] **T2. Product model: migration, validations, and SKU normalization.**
  `create_products` migration (columns per plan, unique index on `sku`) and the
  `Product` model holding every rule: name 3–100, description ≤ 1000, price
  decimal scale 2 / > 0 / ≤ 2 decimals, stock integer ≥ 0, SKU present +
  uppercased (D-6) + charset + unique, `active` boolean default `true`,
  `description` nil → `""`, `active` inclusion `[true, false]`. Model spec covering
  every rule and boundary. RF-1, RF-2 (model leg), RF-4 (model-side semantics),
  RF-16 (model suite), NFR-3
  - Done when: `docker compose exec backend bundle exec rspec spec/models/product_spec.rb`
    is green and `docker compose exec backend bundle exec rspec` finishes with 0
    failures — as one task-specific commit.

- [ ] **T3. Routes, single error contract, and read/delete endpoints.** Exactly the
  five `/api/v1/products` routes; `ApplicationController` with the one
  `render_error` helper + `rescue_from` handlers rendering the fixed shape
  (`error.code` / `message`, `details` only on 422 — D-P1); product serialization
  (`data` wrapper, `price` as 2-decimal string — D-P5); `show` (200) and `destroy`
  (204) including unknown **and** non-numeric `:id` → 404 (never 500); the error
  contract request spec with the simulated-exception 500 branch (generic message,
  no internals). RF-3, RF-5, RF-6, RF-7, RF-16
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/products_spec.rb spec/requests/api/v1/error_contract_spec.rb`
    is green (404 shape asserted for `/api/v1/products/abc`; 500 example returns
    only `code: internal_error` + generic message) and the full
    `docker compose exec backend bundle exec rspec` is green — as one task-specific
    commit.

- [ ] **T4. Create and update endpoints (full-replacement PUT).** `POST` → 201,
  `PUT` → 200, both consuming the `{ "product": { … } }` wrapper (D-P10); 422 with
  per-field `details` for invalid data and nothing persisted; PUT semantics:
  required fields omitted/null → 422, `description` omitted/null → stored `""`,
  `active` omitted → keeps current value, `active: null` → 422 (key-presence in
  controller, rules in the model — D-P12); keeping own SKU valid vs another
  product's SKU → 422. Request spec additions for both endpoints. RF-2 (422
  leg), RF-4, RF-16, NFR-3
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/products_spec.rb`
    is green (including the PUT edge cases a/b/c and duplicate-SKU 422) and
    `docker compose exec backend bundle exec rspec` is green — as one
    task-specific commit.

- [ ] **T5. Listing endpoint: server-side pagination, search, and filter.** `index`
  per the plan's pseudocode: fixed 10/page, `meta` (`current_page`,
  `total_count`, `total_pages`), `q` case-insensitive substring in PostgreSQL with
  `%`/`_` escaped and whitespace-only = no term, `active=true|false` filter,
  combined with stable order `created_at DESC, id DESC`; malformed `page`/`active`
  → 422 with parameter-keyed details (D-P11), out-of-range page → 200 with echoed
  `current_page`, no match → 200 empty list. Listing request spec. RF-9, RF-10,
  RF-11, RF-12, RF-13, RF-14, RF-16
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/products_listing_spec.rb`
    is green (page 1/2 content, out-of-range echo, `q`, `active`, all three
    combined, malformed params → 422, no match → 200 empty) and the full
    `docker compose exec backend bundle exec rspec` is green — as one
    task-specific commit.

- [ ] **T6. CORS for the frontend origin.** `rack-cors` initializer allowing the
  origin from `FRONTEND_ORIGIN`, methods `GET POST PUT DELETE OPTIONS`, any
  headers; request specs asserting `Access-Control-Allow-Origin` on a normal
  request and on a preflight `OPTIONS` (in `error_contract_spec.rb` per the plan).
  RF-8, RF-16
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/error_contract_spec.rb`
    is green (CORS examples return the `FRONTEND_ORIGIN` header) and the full
    `docker compose exec backend bundle exec rspec` is green — as one task-specific
    commit.

- [ ] **T7. Idempotent demo seeds.** `db/seeds.rb` with `find_or_create_by!(sku:)`
  producing > 10 products (two+ pages), active/inactive mix, D-6-valid SKUs,
  prices > 0, varied names that exercise `q`; `spec/seeds_spec.rb` running
  `Rails.application.load_seed` twice and asserting dataset shape + unchanged
  count. RF-15, RF-16
  - Done when: `docker compose exec backend bin/rails db:prepare db:seed` runs
    clean and `docker compose exec backend bundle exec rspec spec/seeds_spec.rb`
    is green (>10 products, mix present, second run does not duplicate) — as one
    task-specific commit.

## Final check (before `/sdd-validate`)

The DoD commands run together as the last gate of T7's validation (no separate
task — verification without a code change would have no commit):

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec
```

## RF coverage

| Task | RFs |
|---|---|
| T1 | NFR-1, NFR-2, DoD (bring-up) |
| T2 | RF-1, RF-2, RF-4 (model), RF-16, NFR-3 |
| T3 | RF-3, RF-5, RF-6, RF-7, RF-16 |
| T4 | RF-2, RF-4, RF-16, NFR-3 |
| T5 | RF-9, RF-10, RF-11, RF-12, RF-13, RF-14, RF-16 |
| T6 | RF-8, RF-16 |
| T7 | RF-15, RF-16, DoD (seeds) |
