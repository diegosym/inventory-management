# Spec 004 — Data Integrity (Soft Delete + Change Audit)

Status: approved

## Context and goal

First backend-modifying bonus increment; delivers two statement bonus items together
— "Soft deletes en lugar de hard deletes" and "Auditoría de cambios (quién y cuándo
modificó)" (C2) — same model, same endpoints. Base: merged spec 001, superseded in
two points (C3): RF-6's permanent delete becomes a soft delete, and RF-15's seed
idempotence is scoped to non-deleted products (RF-4). The five endpoints keep their
shapes (C10, C11) and the frontend keeps its mirror (C14); the audit "who" is settled
by user decision: the constant `"system"` (OQ-1, closes **MEMORY.md OD-2**).

## Users

- Inventory manager / API client (no authentication — C2); evaluator (runs the
  suites and inspects the Rails console).

## User stories

- US-1. As an inventory manager, I want deleting a product to hide it everywhere
  without destroying its data, so that an accidental delete is not data loss.
- US-2. As an evaluator, I want every product change recorded — who, when, what —
  so that data integrity is demonstrable.

## Definitions

- **Soft-deleted product**: row stays in the database, but it no longer exists for
  the API — invisible to all five endpoints.
- **Audit entry**: one internal record of one successful change (create, update, or
  soft delete) of one product.

## Functional requirements

### Soft delete — the visible behavior of the existing endpoints

- RF-1: WHEN `DELETE /api/v1/products/:id` targets an existing, non-deleted product,
  THE SYSTEM marks it as deleted — the row and all its data remain in the database —
  and answers 204 with an empty body (spec 001 RF-6's shape, new semantics).
- RF-2: THE SYSTEM excludes soft-deleted products from `GET /api/v1/products` in
  every case — with/without `q`, with/without `active` — and computes
  `total_count`/`total_pages` over non-deleted products only.
- RF-3: IF the `:id` of show, update, or delete refers to a soft-deleted product —
  or to an unknown/non-numeric id — THE SYSTEM answers 404 with the standard error
  shape (C10); a repeated DELETE thus answers 404 and records no second entry.
- RF-4: SKU uniqueness holds **among non-deleted products only** (rule in the model,
  C9): WHEN a `POST` reuses the SKU of a soft-deleted product, THE SYSTEM creates a
  new product with a new id (201); taking the SKU of a non-deleted product still
  answers 422 with today's per-field message (C14).
- RF-5: THE SYSTEM keeps every spec-001 contract intact: same five routes, same
  success shapes (201/200/204), same 404/422/500 error contract (C10), same
  server-side `page`/`q`/`active` behavior — 422 on malformed params, 200 with an
  empty list on no match or out-of-range page (spec 001 RF-13/RF-14, C11). No new
  query parameter and no new response field: existing API clients keep working.

### Change audit — statement "Auditoría de cambios"

- RF-6: WHEN a product is created, updated, or soft-deleted, THE SYSTEM records
  exactly one audit entry in an internal table, **committed in the same database
  transaction as the change**: a persisted change always has its entry; a rejected
  request (422) leaves neither a change nor an entry.
- RF-7: Each audit entry records at least: affected product id, action
  (`create`/`update`/`delete`), change timestamp, and actor — **the fixed string
  `"system"` for every change**, API or server-side (seeds): with no authentication
  the audit targets the action, the date, and what changed, not a faked identity
  (C5); the field stays ready for a real actor if auth ever arrives. Content by
  action: **update** → exactly the fields that changed, each with previous and new
  value; **create** → the created values; **delete** → only id, action, timestamp,
  actor, no field values or snapshot (user decision, C5). "Changed" is judged on
  **persisted values** — an equivalent payload (`price: "49.9"` over `49.90`,
  `description: null` over `""`) is not a change and records no entry; the exact
  before/after representation is fixed in `plan.md`.
- RF-8: THE SYSTEM records nothing for reads (GET) or rejected requests (404/422)
  and exposes **no endpoint** to create, read, update, or delete audit entries: an
  internal table verifiable only via the test suite and the Rails console; no
  product response includes audit data.

### Tests (C12) and documentation (C17)

- RF-9: THE SYSTEM's RSpec suite covers: deleted products invisible on all five
  endpoints; listing counts/pagination/search/filter with deleted products present;
  SKU reuse after soft delete; repeated DELETE → 404 with no second entry; audit
  entries per RF-7 (create: created values; update: fields before/after; delete:
  id/action/timestamp/actor only); no entry on GET, 422, or a no-op update;
  atomicity (an entry is written iff the change persists); seeds idempotent for
  non-deleted products; pre-existing suites green (C7), adaptation allowed only for
  tests encoding the superseded 001 RF-6 semantics (e.g. destroy asserting
  `Product.count`) — all other existing tests untouched. Run: `docker compose exec
  backend bundle exec rspec`.
- RF-10: THE SYSTEM's `README.md` documents the soft-delete behavior, what the audit
  records, and its actor (`"system"`, OQ-1), coherent with the real code.

## Non-functional requirements

- NFR-1: Verification uses only the commands in `MEMORY.md → Development commands`;
  stack unchanged (C8); no new dependency unless the plan justifies it and it is
  recorded in `MEMORY.md` before code (C6).
- NFR-2: Soft delete stays server-side: no listing/filter/pagination responsibility
  and no deleted-row bookkeeping shifts to the frontend (C11, C14).

## Edge cases

- Delete product X, then `POST` with X's SKU → 201 with a new id; the two products
  never coexist in the API and their audit entries reference their own ids.
- PUT changing several fields → one entry covering all of them; identical-payload
  PUT → 200 and no entry; PUT on a deleted product → 404, no entry.
- 422 on create/update → nothing persists, nothing audited.
- A deleted `active: false` product stays invisible under both `active=true` and
  `active=false`.
- After deletions, a page beyond the last page → 200 with an empty list and
  `current_page` echoing the request (spec 001 RF-13 over the reduced counts).
- **(User decision)** re-running `db:seed` **resurrects** a soft-deleted demo product
  with a **new id** (RF-4); seed idempotence is scoped to non-deleted (001 RF-15).
- Non-numeric id (`/api/v1/products/abc`) → 404, never 500, no entry.

## Out of scope

- Restore/undelete endpoint or UI — recovery is a database-level operation.
- Any audit API (list/read/export) or audit UI — internal table only (RF-8).
- Permanent purge/erasure, audit retention, background jobs.
- Authentication/authorization of any kind (C2); specs `005-openapi`, `006-deploy`.
- Frontend changes: spec 002 already mirrors the contract and needs none here; if
  implementation reveals one is required, work stops and reports (C3).
- New gems/libraries beyond what the plan justifies (C6) — e.g. `audited`/`paranoia`
  wrappers: the plan must weigh the plain Rails/PostgreSQL alternative first.

## Definition of done

- All RFs implemented with passing tests: RF-9's command green and the pre-existing
  backend/frontend suites still green (C7) — allowing only the adaptations RF-9 lists.
- `docker compose up -d --build` + `bin/rails db:prepare db:seed` still yields the
  spec-001 dataset; deleting a seeded product via the API removes it from the list
  while its row remains queryable in the Rails console.
- No secrets committed; each task lands as one specific commit (C17).

## Open questions

- None: OQ-1 was answered by the user and is now RF-7 — actor `"system"` for every
  change (API and seeds) — **closing MEMORY.md OD-2**.
