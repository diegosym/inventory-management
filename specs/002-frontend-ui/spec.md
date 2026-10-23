# Spec 002 — Frontend UI (Product CRUD)

Status: implemented

## Context and goal

Second and last core increment of the challenge (`docs/Reto técnico.pdf`, C2):
the React + TypeScript + Tailwind CSS UI (binding stack, C8/D-2) consuming the
approved spec-001 API (C11, C14, C15) plus the project `README.md` (owed since
spec 001's OQ-4; C17); the contract (D-7/D-9) is fixed, no backend changes.

## Users

- Inventory manager: end user driving the CRUD from the browser (no auth — C2).
- Evaluator: runs the app via Docker Compose, exercises the UI, reads the README.

## User stories

- US-1. As an inventory manager, I want to search the product list by name and
  filter it, so that I can find products in a large inventory.
- US-2. As an inventory manager, I want to create and edit products with
  real-time per-field validation, so errors are caught before saving.
- US-3. As an inventory manager, I want confirmation and feedback around saves
  and deletes, so that I never alter or destroy data by accident.
- US-4. As an evaluator, I want `docker compose up -d --build` plus a clear
  README to run and verify the whole application quickly.

## Functional requirements

- RF-1: THE SYSTEM runs as a `frontend` service of the existing `docker
  compose` stack (D-1, C8, D-P6) on its dev-server origin (default
  `http://localhost:5173`, allowed by the backend CORS, D-9) and talks to the
  spec-001 API (`/api/v1/products`, contract D-7) through its base URL.

### Product list (challenge §2.1; C11, C15)

- RF-2: THE SYSTEM lists the current server-side page of products (at least
  name, SKU, price, stock, active), 10 per page; when the user types a name
  search term (`q`, matched server-side against the product name), THE SYSTEM
  waits ~300 ms of typing inactivity (debounce) and re-requests the server; a
  filter change or page navigation does the same — never searching, filtering,
  or paginating in the client. Controls follow the response `meta`
  (`current_page`, `total_pages`, `total_count`); search or filter resets to
  page 1.
- RF-3: WHILE a list request is in flight, THE SYSTEM shows a loading state;
  on failure an error state with retry; on an empty response an empty state
  distinguishing empty inventory from "no matches" for the search/filter.
- RF-4: WHEN a create, update, or delete succeeds, THE SYSTEM refreshes the
  list so it reflects the change without a manual reload.

### Product form: create and edit (challenge §2.2; C14)

- RF-5: THE SYSTEM provides one product form for create and edit as a modal
  over the list (single view, no router), with fields `name`, `description`,
  `price`, `stock`, `sku`, `active`; on edit it pre-fills current values.
- RF-6: WHILE the user edits, THE SYSTEM validates on input, marking each
  invalid field with the backend's message (spec 001 NFR-3, C14): `name` 3–100
  chars; `description` ≤ 1000 (optional); `price` > 0 with ≤ 2 decimal places
  — exact message `"must have at most 2 decimal places"` (D-9); `stock` a
  non-negative integer; `sku` `[A-Z0-9-]+` after uppercasing (D-6); `active`
  a boolean; submission blocked while any field is invalid.
- RF-7: WHEN the user submits a valid form, THE SYSTEM asks for confirmation
  before sending (challenge wording "confirmación antes de guardar", on both
  create and edit); on confirmation it sends the request (`active` as a JSON
  boolean, D-9; body per D-7/D-9), disables submit while pending (no double
  submission), and on success shows visual feedback (an in-page notification
  that keeps context) and closes the modal; on cancellation it sends nothing
  and keeps the form open with entered values.
- RF-8: IF the server answers 422 on save, THE SYSTEM keeps the form open with
  the entered values, renders every `error.details` message under its field,
  and shows any details key matching no field as a form-level message.
- RF-9: IF the edit target no longer exists (404 on save), THE SYSTEM informs
  the user, closes the form, and refreshes the list.

### Delete (challenge §2.3; C15)

- RF-10: WHEN the user requests a delete, THE SYSTEM asks for confirmation
  naming the product; on confirmation it sends the delete, shows visual
  feedback, and refreshes the list; on 404 it informs the user and refreshes;
  on other failures it shows an error notification and keeps the list intact.

### Feedback, states, and layout (challenge §2.4; C15)

- RF-11: IF a save fails with any error other than 422 (RF-8) or 404 (RF-9),
  or the server is unreachable, THE SYSTEM shows an error notification and
  keeps the form open with the entered values.
- RF-12: THE SYSTEM lays out responsively (mobile, tablet, desktop); every input
  has an associated label, every field error is programmatically associated with
  its input, and the main flows are operable with the keyboard alone.

### Project README (C17; challenge "Documentación requerida")

- RF-13: THE project `README.md` documents what the application is, how to run
  the whole stack with Docker Compose, how to run each test suite, a concise
  API summary, the key technical decisions and why each was taken (challenge
  "Decisiones Técnicas"; source: `MEMORY.md`), and a future-improvements /
  known-limitations section (challenge "Mejoras Futuras"; C17) — all coherent
  with the real configuration of the repository.

### Frontend tests (challenge: optional but valued; C12)

- RF-14: THE SYSTEM ships a frontend test suite (Vitest + React Testing
  Library) covering the RF-6 validation rules (each rule, including the exact
  `price` message), the list's loading/error/empty states, create and edit
  submit (success, save confirmation, 422 per-field rendering), and the delete
  confirmation flow; `docker compose run --rm frontend npm test` passes.

## Non-functional requirements

- NFR-1: The frontend runs 100% through Docker Compose (D-1, C8); verification
  uses only the commands in `MEMORY.md → Development commands`.
- NFR-2: API payloads, responses, and error shapes are explicitly typed in
  TypeScript; `any` only with written justification (C13).
- NFR-3: No UI, state-management, or component library beyond what the plan
  justifies (C6, D-2); the React code follows `vercel-react-best-practices`
  (the challenge's "frontend code" criterion).
- NFR-4: All configuration (API base URL, dev-server origin) goes through
  environment variables; nothing secret is committed (C16).
- NFR-5: Styling uses Tailwind CSS consistently, with no parallel CSS system.

## Edge cases

- Page beyond the last page → the server answers 200 with an empty list (spec
  001 RF-13); the system shows the empty state and keeps navigation on valid
  pages — deleting the last product of the last page lands on a valid page.
- Backend unreachable → the list shows its retry state (RF-3) and the form its
  error notification (RF-11); the application never crashes or blank-screens.

## Out of scope

- CI → spec `003-ci`; soft delete + change audit → spec `004-data-integrity`;
  OpenAPI docs → spec `005-openapi`; deployment → spec `006-deploy`.
- Authentication of any kind (C2); client-side caching, offline mode, i18n,
  dark mode, `per_page`; any extra library the plan does not justify (C6).
- Backend changes of any kind — spec 001 is implemented and validated.

## Definition of done

- All RFs implemented; RF-14 suite green (command in RF-14).
- `docker compose up -d --build` brings up db + backend + frontend; the UI
  exercises list, search, filter, paginate, create, edit, and delete against
  the seeded dataset; backend RSpec still passes (C7).
- `README.md` matches the real commands and layout (RF-13); no secrets
  committed; each task landed as one specific commit (C17).

## Open questions

- None: the four draft questions were answered and are now RF-5, RF-7, RF-2,
  and RF-14.
