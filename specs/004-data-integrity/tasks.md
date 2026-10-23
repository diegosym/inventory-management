# Tasks 004 — Data Integrity (Soft Delete + Change Audit)

Derived from the approved `spec.md` (RF-1…RF-10, NFR-1…NFR-2, edge cases, DoD) and
the user-approved `plan.md` (files/responsibilities, soft-delete and audit
mechanics, D-P31…D-P39, test strategy).

Approvals verified before generating this file:

- `spec.md` → `Status: approved`.
- `plan.md` → `Status: approved` (user's explicit approval; status header updated
  in the session that generated this file).

Rules:

- One task = one task-specific commit (C17); tests first where the task has tests
  (red → green).
- All checks use only `MEMORY.md → Development commands` (everything via
  `docker compose`; RSpec is mandatory). Nothing runs node/ruby on the host.
- Adaptation budget (D-16(d)/RF-9): exactly one existing 001 example may change —
  the `DELETE` success case, adapted in T2. Any other red test from 001/002/003 is
  a signal to stop and report, not to adapt. No file under `frontend/` is touched
  (C14/NFR-2 — if one proves necessary, the task stops and reports).
- Dependency order: T1 → T2 → T3 → T4 → T5 → T6 (each task leaves the whole suite
  green — C7; the risky storage/index change lands first, audit is isolated from
  soft delete so failures don't mix).

## Tasks

- [x] **T1. Soft-delete storage and model rules (red → green on the model suite).**
  Tests first: add the model examples to `backend/spec/models/product_spec.rb`
  (reusing the SKU of a soft-deleted product is valid; reusing a visible product's
  SKU still fails — existing example untouched; `soft_delete!` sets `deleted_at`
  and drops the visible count). Then the migration
  `add_deleted_at_to_products` (nullable `deleted_at` + plain index; drop the
  unique `sku` index, recreate as partial unique on `sku` where
  `deleted_at IS NULL` — D-P31/D-P33) and the `product.rb` model leg:
  `default_scope { where(deleted_at: nil) }` (D-P32), SKU uniqueness with
  `conditions:` narrowed to visible rows (D-P34; mandatory — Rails 8.1's
  validator ignores `default_scope`), `soft_delete!` (D-P35), regenerated
  `schema.rb`. All 001 validations and messages stay byte-identical (C14/D-12).
  RF-1 (storage leg), RF-4 (index + model leg), RF-5 (no new params/fields),
  RF-9 (model examples), DoD (storage)
  - Done when: `docker compose exec backend bin/rails db:prepare` succeeds against
    the existing `db_data` volume and the regenerated `backend/db/schema.rb` shows
    `deleted_at` and the partial unique index, and
    `docker compose exec backend bundle exec rspec` is green (the new model
    examples pass; every 001/002/003 test untouched) — as one task-specific
    commit. The DELETE endpoint still hard-deletes at this point (controller
    change is T2), so the 001 `DELETE` success example stays untouched and green.

- [x] **T2. DELETE becomes a soft delete; deleted rows invisible on every endpoint
  (red → green on the request suite).** Tests first: adapt the single allowed
  001 example — the `DELETE` success case in
  `backend/spec/requests/api/v1/products_spec.rb` now asserts 204 + empty body
  **and** the row remains with `deleted_at` set (`Product.unscoped`) with the
  visible count −1 (D-16(d) budget). New
  `backend/spec/requests/api/v1/soft_delete_spec.rb` per the plan: RF-1 (204 +
  row remains); RF-2 (deleted product absent with/without `q` and `active`;
  `total_count`/`total_pages` over visible rows; deleted `active: false`
  invisible under both filter values; out-of-range page after deletions → 200 +
  empty list + echoed `current_page`); RF-3 (show/update/repeat-DELETE of a
  deleted id and non-numeric id → 404 standard shape; no second delete entry —
  asserted from T3 on); RF-4 (POST reuses a deleted product's SKU → 201 new id,
  old row untouched; visible SKU still 422 with today's per-field message);
  RF-5 (shapes unchanged re-asserted cheaply). Then the one-line controller
  change: `destroy` calls `@product.soft_delete!` instead of `destroy!`
  (D-P35) — with the default scope, `find_product!` and the listing exclude
  deleted rows by construction. RF-1, RF-2, RF-3, RF-4 (endpoint leg), RF-5,
  RF-9 (adaptation budget)
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/soft_delete_spec.rb`
    is green and the full `docker compose exec backend bundle exec rspec` is
    green with exactly one adapted existing example (`git diff` on the spec
    suite touches only the `DELETE` success example plus the new file) — as one
    task-specific commit.

- [x] **T3. Audit storage and change entries (red → green on the new audit suite).**
  Tests first: new `backend/spec/requests/api/v1/audit_spec.rb` covering the
  entry semantics of RF-6/RF-7 — create → exactly one entry, action `create`,
  actor `"system"`, all created business values with `from: null`; update of
  several fields → one entry covering each with before/after; equivalent payload
  (`price: "49.9"` over `49.90`, `description: null` over `""`) → 200 and no
  entry; identical payload → 200 and no entry; soft delete → exactly one entry,
  action `delete`, `changes_data == {}`; repeated DELETE → 404 and no second
  entry (also asserted in `soft_delete_spec.rb`'s RF-3 example). Then the
  storage and mechanics per the plan: migration `create_product_audits`
  (`product_id`, `action`, `changes_data` jsonb default `{}`, `actor`,
  `created_at` only; no FK, no polymorphism — D-P36) and the immutable
  `ProductAudit` model (`action` inclusion in create/update/delete, nothing
  else — C5); in `product.rb`: `has_many :product_audits` and in-transaction
  `after_create`/`after_update` callbacks (D-P37) writing content per D-P38 —
  create = business-field slice of the persisted row (not `saved_changes`),
  update = business fields of `saved_changes`, delete = empty `changes_data`,
  values serialized like the API (2-decimal price string), `deleted_at`/
  timestamps excluded from change detection; actor `"system"` written explicitly
  (D-15). RF-6, RF-7, RF-8 (no route/serializer change — asserted in T4),
  RF-9 (audit examples), NFR-1
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/audit_spec.rb`
    is green and the full `docker compose exec backend bundle exec rspec` is
    green — as one task-specific commit.

- [x] **T4. Audit guarantees: atomicity, rejected requests, and the internal-only
  surface (red → green on audit suite additions).** Tests first, added to
  `backend/spec/requests/api/v1/audit_spec.rb`: atomicity — stub the audit
  insert to raise and assert the product change is rolled back with no entry
  remaining, on both the create and update paths; 422 on create/update →
  nothing persists and nothing is audited; no entry on GET; no entry for a
  non-numeric id (404, never 500). RF-8 — no product response of any endpoint
  ever contains audit data, and no route exists for the table. No production
  code change expected beyond what T3 delivered; if one is needed, it stays
  inside the T3 surface (model callbacks). RF-6 (atomicity leg), RF-7 (422/no-op
  legs), RF-8, RF-9 (atomicity examples)
  - Done when: `docker compose exec backend bundle exec rspec spec/requests/api/v1/audit_spec.rb`
    is green (rollback examples pass) and the full
    `docker compose exec backend bundle exec rspec` is green — as one
    task-specific commit.

- [x] **T5. Seeds: resurrection semantics documented and tested (red → green on
  the seeds suite).** Tests first: add examples to `backend/spec/seeds_spec.rb`
  (the four existing examples stay untouched) — soft-delete a seeded product,
  re-run `Rails.application.load_seed`: the SKU is present again under a
  **new id**, the old row still exists with `deleted_at`, no visible product was
  duplicated; seeded products carry audit entries with actor `"system"`
  (D-15/D-16a). Then the header comment in `backend/db/seeds.rb` documenting the
  D-16(a) resurrection semantics — zero logic change (D-P39: the default scope +
  partial index already deliver it). RF-4 (seed leg), RF-6/RF-7 (seeded actor),
  RF-9 (seed examples), DoD (seeds)
  - Done when: `docker compose exec backend bin/rails db:prepare db:seed` runs
    clean and `docker compose exec backend bundle exec rspec spec/seeds_spec.rb`
    is green (resurrection with new id, idempotence scoped to non-deleted,
    actor `"system"`) and the full `docker compose exec backend bundle exec
    rspec` is green — as one task-specific commit.

- [ ] **T6. README: soft delete and audit documentation (RF-10).** Update the
  `DELETE` row note in the endpoint table (soft-delete semantics: row remains,
  invisible everywhere, 204 unchanged) and add a short **"Integridad de
  datos"** subsection: what the audit records (id, action, timestamp, actor
  `"system"`, changed fields with before/after — no snapshot on delete) and that
  it is internal-only, verifiable via RSpec and the Rails console (OQ-1, RF-8);
  update the `Mejoras Futuras` 004 bullet to delivered; fix the stale
  `Limitaciones` bullet that claims OD-2 is open (D-15 closed it) — coherence
  C17. Documentation only; no test changes. RF-10, RF-8 (documentation leg)
  - Done when: the README is coherent with the code delivered in T1–T5 (same
    delete semantics, same audit fields and actor, no open-OD-2 claim), every
    `docker compose` command printed in it still matches
    `MEMORY.md → Development commands`, and `git diff --stat` shows `README.md`
    as the only modified file — as one task-specific commit.

## Final check (before `/sdd-validate`)

The DoD battery runs together as the last gate of T6's validation (no separate
task — verification without a code change would have no commit). CI (spec 003)
repeats all of it automatically on the PR with run-all semantics; the required
check is `CI`.

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec     # 90 today → grows; must be green
docker compose run --rm frontend npm test         # 57/57, unchanged (C14/NFR-2)
docker compose exec frontend npm run build        # tsc + vite, unchanged
```

DoD extras (plan): via `docker compose exec backend bin/rails console`, a seeded
product is gone from `Product.all` but present via `Product.unscoped`, with its
`product_audits` rows.

## RF coverage

| Task | RFs / NFRs / DoD |
|---|---|
| T1 | RF-1 (storage), RF-4 (index + model), RF-5, RF-9 (model examples), DoD (storage) |
| T2 | RF-1, RF-2, RF-3, RF-4 (endpoint), RF-5, RF-9 (adaptation budget) |
| T3 | RF-6, RF-7, RF-8 (asserted T4), RF-9 (audit examples), NFR-1 |
| T4 | RF-6 (atomicity), RF-7 (422/no-op), RF-8, RF-9 (atomicity) |
| T5 | RF-4 (seed), RF-6/RF-7 (seeded actor), RF-9 (seeds), DoD (seeds) |
| T6 | RF-10, RF-8 (documentation leg) |
