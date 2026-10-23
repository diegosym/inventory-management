# Plan 004 — Data Integrity (Soft Delete + Change Audit)

Status: draft

Derived from the approved `spec.md` (RF-1…RF-10, NFR-1…NFR-2, edge cases, DoD).
This is the first backend-modifying bonus increment: it supersedes spec 001 in two
points (C3) and keeps every other contract intact (C10, C11, C14). The user
decisions **D-15** (actor `"system"`) and **D-16** (seed resurrection with new id,
snapshot-free delete entry, persisted-value change detection, test-adaptation
limit) are implemented here, not reopened. It fixes what the spec delegated to the
plan: the exact before/after representation of audit content (RF-7) and the
soft-delete/audit mechanics (verified against the live Rails 8.1.4 in the compose
container).

## Files to create and modify

| File | Responsibility |
|---|---|
| `backend/db/migrate/<timestamp>_add_deleted_at_to_products.rb` (new) | Add `deleted_at` (datetime, nullable) + a plain index on it; **drop** the current unique `sku` index and recreate it as a partial unique index on `sku` **where `deleted_at IS NULL`** (RF-1, RF-4 — D-P31/D-P33). |
| `backend/db/migrate/<timestamp>_create_product_audits.rb` (new) | The audit table (RF-6, RF-7 — D-P36): `product_id` (bigint, not null, indexed), `action` (string, not null), `changes_data` (jsonb, not null, default `{}`), `actor` (string, not null), `created_at` (datetime, not null). |
| `backend/db/schema.rb` (regenerate + commit) | Rails dumps it when `db:prepare` runs the migrations; the test schema and CI load from it (`maintain_test_schema!` is already configured). |
| `backend/app/models/product.rb` (modify) | Visibility via `default_scope` (D-P32); SKU uniqueness narrowed to visible rows via `conditions:` (D-P34, C9); `soft_delete!` (D-P35); audit callbacks `after_create`/`after_update` (D-P37/D-P38); `has_many :product_audits`. **All 001 validations and their messages stay byte-identical** (C14/D-12). |
| `backend/app/models/product_audit.rb` (new) | Immutable audit record: `action` inclusion in `%w[create update delete]`. No other behavior (C5). |
| `backend/app/controllers/api/v1/products_controller.rb` (modify) | One line: `destroy` calls `@product.soft_delete!` instead of `@product.destroy!` (still 204 + empty body, RF-1). Everything else untouched — with the default scope, `find_product!` and `listing_scope` exclude deleted rows by construction (RF-2, RF-3), and `serialize_product` is unchanged (RF-5, RF-8). |
| `backend/db/seeds.rb` (comment only) | Header comment documents the D-16(a) resurrection semantics; **zero logic change** (D-P39). |
| `backend/spec/requests/api/v1/products_spec.rb` (adapt — the only existing test touched) | The `DELETE` success example asserts soft-delete semantics: 204 + empty body **and the row remains** with `deleted_at` set (`Product.unscoped`), visible count −1. This is the one test D-16(d)/RF-9 explicitly lists as encoding the superseded 001 RF-6 "removes the product" semantics. The two `DELETE` 404 examples stay untouched (they remain green: `Product.count` counts visible rows). |
| `backend/spec/requests/api/v1/soft_delete_spec.rb` (new) | RF-1…RF-5 endpoint behavior (list below). |
| `backend/spec/requests/api/v1/audit_spec.rb` (new) | RF-6…RF-8 behavior + atomicity (list below). |
| `backend/spec/models/product_spec.rb` (add examples) | Reusing the SKU of a **soft-deleted** product is valid; reusing a **visible** product's SKU still fails (existing example stays); `soft_delete!` sets `deleted_at`. |
| `backend/spec/seeds_spec.rb` (add examples) | Resurrection with a new id; idempotence scoped to non-deleted products; seeded entries carry actor `"system"` (D-15). The four existing examples stay untouched. |
| `README.md` (modify — **RF-10 confirms the root README**, the project's documented deliverable since 002) | `DELETE` row note (soft-delete semantics) + a short "Integridad de datos" subsection: what the audit records and its actor `"system"` (OQ-1); `Mejoras Futuras` 004 bullet → entregado; the stale "Limitaciones" bullet claiming OD-2 is open is updated (D-15 closed it) — coherence C17. |

**Nothing else changes:** `Gemfile` (no new gems — C6), `docker-compose.yml`,
Dockerfiles, `.env.example`, CORS, `application_controller.rb` (the C10 contract
already handles `RecordNotFound`/`RecordInvalid`), `config/routes.rb`, factories (no
audit factory: entries are produced through product operations), `spec/rails_helper.rb`,
and **everything under `frontend/`** (C14/NFR-2 — if implementation reveals a
frontend change is needed, work stops and reports, per spec Out of scope).

## Soft-delete mechanics

### Column and visibility (D-P31, D-P32)

- `products.deleted_at` (nullable datetime) + plain index; `NULL` = visible,
  timestamp = soft-deleted. Discarded: `deleted` boolean (loses "when", nonstandard)
  and a tombstone table (moves the data out of the row the API reads).
- Visibility is one line in the model: `default_scope { where(deleted_at: nil) }`.
  This makes **every existing 001 query path correct by construction**: the listing
  (`Product.all` → counts, pagination, `q`, `active` — RF-2), `find_product!`
  (`find_by!` on a deleted id → `RecordNotFound` → 404 for show/update/delete,
  RF-3, repeated DELETE included), `find_or_create_by!` in seeds, `Product.count`
  in tests. **Discarded: an explicit `visible` scope threaded through the
  controller, seeds, and every future query** — RF-2 demands invisibility "in every
  case", and one missed query path silently leaks deleted rows; the explicit-scope
  version also forces 001 test edits everywhere `Product.count`/`find_by!` appears.
  Known `default_scope` risks and mitigations: it is implicit (accepted: the app has
  one model and the desired semantics *is* "ignore deleted", so implicitness here is
  the feature); `unscoped` discards **all** conditions (mitigation: `Product.unscoped`
  appears only in tests and console verification, never in app code, and only as a
  top-level call, never chained mid-query); associations would inherit it (accepted —
  the audit association must follow the product's visibility anyway).

### SKU uniqueness among visible only (D-P33, D-P34)

- Migration swaps the index: drop `index_products_on_sku`, add
  `index_products_on_sku_visible` unique on `sku` where `deleted_at IS NULL`.
  **Discarded: keeping the full unique index** (forbids RF-4's SKU reuse) and a
  composite unique `(sku, deleted_at)` (relies on PostgreSQL's NULL-unique quirk —
  correct but implicit; the partial index states the rule literally).
- Model side (C9): `validates :sku, uniqueness: { conditions: -> { where(deleted_at: nil) } }`.
  This `conditions:` option is **mandatory, not belt-and-suspenders**: verified in
  the container that Rails 8.1's `UniquenessValidator#build_relation` starts from
  `klass.unscoped`, i.e. the uniqueness validation **ignores** `default_scope` —
  without `conditions:`, reusing a deleted product's SKU would still answer 422 and
  RF-4 would fail. D-6 is untouched (same format rule, same normalization, same
  `"has already been taken"` message for visible SKUs). Side effect noted: the
  validator's unique-index short-circuit (`covered_by_unique_index?`) skips partial
  indexes, so the existence query runs on every save — one cheap query on a tiny
  table, accepted for correctness.

### The delete operation (D-P35)

- `Product#soft_delete!` → `update!(deleted_at: Time.current)` (a model rule — C9),
  called by the controller's `destroy` action; 204 + empty body unchanged (RF-1).
  **Discarded: overriding `destroy`** (silently redefines a standard Rails verb for
  every caller — console, `dependent:` options, future code; surprising and hard to
  grep) and a controller-side `update!` (business rule outside the model — C9).
- Repeated DELETE and DELETE of an already-deleted product need no extra code:
  the default-scoped `find_by!` raises `RecordNotFound` → 404, and no callback runs
  → no second audit entry (RF-3).

## Audit mechanics

### Table and model (D-P36)

- Table `product_audits`, one row per successful change (create/update/soft delete),
  immutable (`created_at` only — no `updated_at` for a write-once record).
  **Discarded: a generic polymorphic `audit_entries` table** (speculative generality:
  only products are ever audited here — C5; a second audited model can migrate later)
  and a foreign key to `products` (the audit must outlive any future purge; purge is
  out of scope, and an FK would let console destroys block on audit rows).
- `changes_data` is the jsonb column name; **discarded `changes`** (collides with
  ActiveRecord's dirty-tracking method `changes` on the model instance).
- `actor` is a plain string with the default `"system"`, written explicitly by the
  callbacks — D-15: the same constant for API and seeds, ready for a real actor if
  auth ever arrives.
- `Product has_many :product_audits` for readable console/test queries; no inverse
  bookkeeping.

### Transactionality (D-P37)

- The entries are written by **model callbacks `after_create` and `after_update`**,
  which run **inside the save's transaction** — exactly RF-6's requirement: if the
  callback raises, the whole save rolls back (a change without its entry is
  impossible); if validation fails (422), the callbacks never run (an entry without
  a change is impossible); in the transactional RSpec suite the entries appear in the
  same test transaction.
- The `after_update` callback distinguishes the three outcomes: `saved_change_to_deleted_at?`
  with `deleted_at` now present → action `delete`; otherwise → action `update`,
  written only when at least one business field changed; a no-op save writes nothing
  (verified: `saved_changes` is `[]` after a no-op save, and update callbacks *do*
  fire on it — so the business-field filter, not callback suppression, guarantees the
  "identical-payload PUT → no entry" rule).
- **Discarded: `after_commit`** — it runs *after* the commit: a crash between commit
  and callback leaves a persisted change with no entry, and an exception in it cannot
  roll the change back; both contradict RF-6's "committed in the same database
  transaction". **Discarded: transaction blocks in the controller** (duplicated per
  action, business rule outside the model — C9, and seeds would need the same
  duplication). **Discarded: database triggers** (invisible to the model layer and
  to RSpec, untestable through the documented commands).

### Change content and representation (D-P38 — fixes RF-7's delegated item)

`changes_data` is a JSON object `field → { "from": …, "to": … }` with exactly the
business fields `name, description, price, stock, sku, active`:

- **create** → every business field of the **persisted row**
  (`record.slice(...)`, not `saved_changes` — verified: `saved_changes` omits
  attributes equal to their column default, e.g. `description`/`active`), `"from": null`.
- **update** → only the business fields that changed, each with its previous and
  new value, taken from `saved_changes` (persisted, type-cast values — D-16c).
- **delete** → no field values: `changes_data` stays `{}`; the entry carries only
  `product_id`, `action`, `actor`, `created_at` (D-16b). Excluded from change
  detection everywhere: `id`, `created_at`, `updated_at`, `deleted_at`.
- **Value serialization** matches the API conventions the frontend already mirrors
  (D-7/D-12): `name`/`description`/`sku` as strings, `price` as the 2-decimal string
  (`"49.90"` — same `format('%.2f', …)` as `serialize_product`), `stock` as an
  integer, `active` as a JSON boolean. Persisted-value detection is inherent:
  `price: "49.9"` over `49.90` and `description: null` over `""` type-cast to the
  stored value, so nothing changed and no entry is written (RF-7 edge case).
- **Discarded: diffing the raw request payload** (would record entries for
  equivalent payloads — RF-7 forbids) and **full row snapshots** (heavier storage;
  RF-7/D-16b want exactly the changed fields and no delete snapshot).

### Audit surface (RF-8)

No endpoint, no route, no serializer field: `serialize_product` is untouched and the
table is reachable only through RSpec and `bin/rails console` (the documented
command).

## Seeds (D-16(a), D-P39)

**No logic change.** `Product.find_or_create_by!(sku:)` runs default-scoped, so a
soft-deleted demo product is *not* found; creation goes through and the partial
unique index admits it → the demo product is **resurrected with a new id**, while
the old row stays deleted — exactly D-16(a), with no code. A second run finds every
visible SKU and changes nothing → 001 RF-15's idempotence holds for non-deleted
products. Only the header comment is updated to document this. **Discarded:
explicit `with_deleted` lookups + restore** (would resurrect in place with the same
id, contradicting D-16(a), and adds code for nothing).

## Test strategy (RF-9, C12)

RSpec only; the spec includes no frontend suite changes (Vitest stays 57/57).
Commands from `MEMORY.md → Development commands`, all via docker compose:

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec     # 90 today → grows; must be green
docker compose run --rm frontend npm test         # 57/57, unchanged (C14/NFR-2)
docker compose exec frontend npm run build        # tsc + vite, unchanged
```

- **`soft_delete_spec.rb`** — RF-1: 204 + empty body, row remains with
  `deleted_at`, visible count −1. RF-2: deleted product absent from the list with
  and without `q` and `active`; `total_count`/`total_pages` computed over visible
  rows only; a deleted `active: false` product invisible under both `active=true`
  and `active=false`; page beyond the last page after deletions → 200 + empty list +
  echoed `current_page`. RF-3: show/update/repeat-DELETE of a deleted id → 404 with
  the standard shape, no second entry; non-numeric id → 404 (never 500). RF-4:
  POST reusing a deleted product's SKU → 201 with a new id while the old row is
  untouched; reusing a visible SKU → 422 with the same per-field message. RF-5:
  success shapes unchanged are re-asserted cheaply on the delete path.
- **`audit_spec.rb`** — RF-6/RF-7: create → exactly one entry, action `create`,
  actor `"system"`, all created values (`from: null`); update of several fields →
  one entry covering each with before/after; equivalent payload (`price: "49.9"`
  over `49.90`, `description: null` over `""`) → 200 and **no** entry; identical
  payload → 200 and no entry; soft delete → exactly one entry, action `delete`,
  with only id/action/actor/`created_at` (`changes_data == {}`); repeated DELETE →
  404 and no second entry. No entry on GET; 422 on create/update → nothing persists,
  nothing audited. Atomicity: stub the audit insert to raise → the product change is
  rolled back and no entry remains (create and update paths). RF-8: no product
  response ever contains audit data, and no route exists for the table.
- **`product_spec.rb` (added examples)** — SKU of a soft-deleted product validates;
  `soft_delete!` stamps `deleted_at` (visible count via `Product.count` drops).
- **`seeds_spec.rb` (added examples)** — soft-delete a seeded product, re-run
  `load_seed`: the SKU is present again under a **new id**, the old row still exists
  with `deleted_at`, and no visible product was duplicated; seeded products carry
  audit entries with actor `"system"` (D-15).
- **Adaptation budget (D-16(d)):** exactly one existing example (the `DELETE`
  success case above). Every other test of 001/002/003 stays green untouched (C7);
  any further red test is a signal to stop and report, not to adapt.
- Factories unchanged; no DatabaseCleaner (transactional tests suffice).

CI (spec 003) runs this same suite, the Vitest suite, and the build on every PR with
run-all semantics — no workflow change (003 is consumed as-is).

## Verification of this plan

The command block above, run before/after implementation; the migration is proven by
`db:prepare` on an existing database (the `db_data` volume) and by the regenerated
`schema.rb` loading the test schema. DoD extras: after `bin/rails db:prepare db:seed`,
`docker compose exec backend bin/rails console` shows a seeded product gone from
`Product.all` but present via `Product.unscoped`, with its `product_audits` rows.

## Technical decisions (discarded alternative included)

- **D-P31 — Soft delete via nullable `products.deleted_at` + index.** Discarded:
  a `deleted` boolean (no timestamp — the audit already records *when*, but console
  recovery and future restore want it, and the standard idiom costs nothing) and a
  separate tombstone table (the row must stay under the same primary key so all
  five endpoints keep addressing it).
- **D-P32 — `default_scope { where(deleted_at: nil) }` for visibility.** Discarded:
  an explicit `visible` scope used at every query site (RF-2's "every case" then
  depends on humans remembering each site; it also forces widespread 001 test edits)
  and `acts_as_paranoid`-style gems (C6 — one line replaces them). Risks and
  mitigations are spelled out above; `unscoped` never appears in app code.
- **D-P33 — Partial unique index `unique (sku) WHERE deleted_at IS NULL`, replacing
  the existing unique index in the same migration.** Discarded: keeping the current
  full unique index (forbids RF-4) and a composite `(sku, deleted_at)` unique index
  (works via PostgreSQL's NULL-unique behavior but states the rule only implicitly).
- **D-P34 — SKU uniqueness narrowed with `uniqueness: { conditions: -> { where(deleted_at: nil) } }`.**
  Discarded: relying on the default scope (verified false: Rails 8.1's uniqueness
  validator builds from `klass.unscoped`, so it would still reject reused SKUs and
  break RF-4) and dropping the model validation in favor of the index alone (violates
  C9 and would surface as `RecordNotUnique` → 500 instead of 422).
- **D-P35 — `Product#soft_delete!` called by the controller's `destroy`.**
  Discarded: overriding `destroy` (redefines a Rails verb for every caller —
  console, future `dependent:` — a silent, hard-to-audit semantic change) and a
  controller-side `update!` (business rule outside the model — C9).
- **D-P36 — Dedicated `product_audits` table with `product_id`, `action`,
  `changes_data` (jsonb), `actor`, `created_at` only; no FK, no polymorphism.**
  Discarded: polymorphic `audit_entries` (speculative generality — C5), `updated_at`
  on an immutable record, and an FK to `products` (the audit must survive any future
  purge; purge is out of scope).
- **D-P37 — In-transaction `after_create`/`after_update` model callbacks.**
  Discarded: `after_commit` (post-commit crash window leaves a change without an
  entry; a callback raise can't roll back the change — violates RF-6), controller
  transaction blocks (duplicated per action + seeds, business rule in the controller
  — C9), DB triggers (invisible to RSpec and to the model layer).
- **D-P38 — Audit content from persisted values: create = business-field slice of
  the new row (`from: null`), update = business fields of `saved_changes`, delete =
  empty `changes_data`; values serialized like the API (2-decimal price string).**
  Discarded: diffing the raw payload (equivalent payloads would record entries —
  RF-7 forbids), full before/after snapshots (heavier; contradicts D-16b for deletes),
  and trusting `saved_changes` for create (verified: attributes equal to their column
  default are omitted).
- **D-P39 — Seeds keep their logic; the default scope + partial index deliver the
  D-16(a) resurrection.** Discarded: explicit `with_deleted` find/restore (would
  resurrect with the same id — opposite of D-16(a) — and adds code for zero gain).

## RF coverage map

| Part | Covers |
|---|---|
| `deleted_at` migration + partial SKU index + `schema.rb` | RF-1 (storage), RF-4 (index leg), DoD |
| `product.rb` — `default_scope` | RF-2, RF-3 (visibility/404s), RF-5 (no new params/fields) |
| `product.rb` — uniqueness `conditions:` | RF-4 (model leg, C9), D-6 intact |
| `products_controller.rb` — `destroy` → `soft_delete!` | RF-1 (204 semantics) |
| `product_audit.rb` + `product_audits` migration | RF-6 (storage), RF-7 (columns) |
| `product.rb` — audit callbacks | RF-6 (same transaction), RF-7 (content/actor), RF-8 (internal) |
| `db/seeds.rb` (comment) | D-16(a) coherence; behavior via default scope + index |
| `soft_delete_spec.rb` | RF-1, RF-2, RF-3, RF-4, RF-5 |
| `audit_spec.rb` | RF-6, RF-7, RF-8 |
| `product_spec.rb` (added), `seeds_spec.rb` (added), adapted destroy example | RF-4, RF-9 (incl. D-16(d) budget) |
| `README.md` | RF-10 (soft delete, audit content, actor `"system"`) |

## Out of scope for this plan

Everything under the spec's Out of scope: restore/undelete endpoint or UI, any audit
API/UI/export, permanent purge and audit retention, background jobs, authentication,
specs `005-openapi` and `006-deploy`, all frontend changes (C14 — stop and report if
one proves necessary), new gems (`audited`, `paranoia`, or any other — C6), and any
change to the C10 error contract, the listing behavior (C11), or the 001 test suite
beyond the single adaptation D-16(d) allows (C7).
