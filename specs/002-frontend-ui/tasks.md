# Tasks 002 — Frontend UI (Product CRUD)

Derived from the approved `spec.md` (RF-1…RF-14, NFR-1…NFR-5, DoD) and the
user-approved `plan.md` (file surface, D-P13…D-P24, state flows, `price`
round-trip mechanics, test strategy, README sections).

Approvals verified before generating this file:

- `spec.md` → `Status: approved`.
- `plan.md` → `Status: approved` (user's explicit approval; `MEMORY.md`
  roadmap: "spec 002 … plan approved — drafting tasks"). The earlier NFR-4 ↔
  plan tension is closed by the user as `MEMORY.md` D-11: NFR-4 is satisfied
  by the env-driven API base URL (`VITE_API_BASE_URL`) plus the documented
  fixed dev-server default `http://localhost:5173` (pinned by RF-1); the
  dev-server host/port lives in `vite.config.ts`, not in env. No plan change;
  nothing pending.

Rules:

- One task = one task-specific commit (C17); tests first, then the code.
- All checks use only `MEMORY.md → Development commands` (everything via
  `docker compose`; never run Node on the host).
- **The React code must follow the project skill
  `.opencode/skills/vercel-react-best-practices/SKILL.md` and its `rules/`**
  (explicitly required by the user for the implementer; NFR-3): e.g. no
  inline component definitions, primitive `useEffect` dependencies, state
  derived during render, ternaries over `&&` for conditional JSX, direct
  imports.
- No backend file is touched; nothing from specs 003–006 (spec Out of scope).
- Dependency order: T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 (each task
  keeps the stack runnable — C7).

## Tasks

- [ ] **T1. Scaffold the `frontend` service: compose, Vite, Tailwind, test
  harness.** Modify `docker-compose.yml` (add the `frontend` service per
  D-P13: `node:22` via `frontend/Dockerfile`, `npm run dev` on 5173, bind
  mount + anonymous `node_modules` volume, env `VITE_API_BASE_URL`; `db` and
  `backend` untouched), `frontend/Dockerfile`, `frontend/.dockerignore`,
  `.env.example` (document `VITE_API_BASE_URL`, no secrets — C16/D-24),
  `frontend/package.json` + lockfile (scripts `dev`, `build` =
  `tsc -b && vite build`, `test` = `vitest run`), tsconfig pair, `vite.config.ts`
  (React + Tailwind plugins, `server: { host: true, port: 5173 }` fixed per
  D-11/RF-1, Vitest block: jsdom + globals + setup), `index.html`,
  `src/main.tsx`, placeholder `src/App.tsx`, `src/index.css` (Tailwind v4
  `@theme` tokens), `src/test/setup.ts`. RF-1, NFR-1, NFR-2, NFR-4 (D-11
  interpretation), NFR-5, RF-14 (harness), DoD (bring-up)
  - Done when: `docker compose up -d --build` starts db + backend + frontend,
    the dev server answers `200` on `http://localhost:5173` (e.g. `curl -s
    -o /dev/null -w '%{http_code}' http://localhost:5173`),
    `docker compose run --rm frontend npm test` exits green (empty suite +
    setup), and `docker compose exec frontend npm run build` is green — as
    one task-specific commit.

- [ ] **T2. Contract types, plain-fetch API layer, and the mirror
  validators.** `src/types/api.ts` (`Product`, `ListingMeta`, envelopes,
  `ApiErrorBody`, `ApiError` with `status`/`code`/`details`; no unjustified
  `any`), `src/api/products.ts` (`listProducts`/`createProduct`/
  `updateProduct`/`deleteProduct`, one private `request` parsing `{ error }`
  into `ApiError` and rethrowing network failures, base URL from
  `VITE_API_BASE_URL`), `src/validators/product.ts` (`validateField` +
  `validateProduct`, literal backend messages, SKU uppercasing per D-6,
  `price`/`stock` string discipline). Tests first:
  `src/__tests__/validators/product.test.ts` with one example per rule and
  boundary (name 2/3/100/101, description 1000/1001, price `""`/`0`/`-1`/
  `9.999` asserting the exact `"must have at most 2 decimal places"` / valid
  `49.99`, stock `-1`/`1.5`/`0`/`12`, sku missing/`abc@123`/
  `abc-123` → `ABC-123`). RF-1 (API leg), RF-6 (validator leg), NFR-2,
  NFR-3, RF-14
  - Done when: `docker compose run --rm frontend npm test` is green including
    the validator spec and `docker compose exec frontend npm run build` is
    green — as one task-specific commit.

- [ ] **T3. Listing: hooks, states, and meta-driven controls.**
  `src/hooks/useDebouncedValue.ts` (~300 ms, timer cleanup),
  `src/hooks/useProducts.ts` (one fetch per param change, debounce, page-1
  reset on `q`/`active`, page clamp to the last valid page),
  `src/components/states.tsx` (`LoadingState`, `ErrorState` with retry,
  `EmptyState` distinguishing empty inventory vs no matches),
  `src/components/ProductList.tsx` (toolbar search + `active` filter,
  pagination from `meta`, states), `App.tsx` wires the list. Tests first:
  `__tests__/components/ProductList.test.tsx` with `fetch` stubbed via
  `vi.stubGlobal` — loading while pending, retry re-requests, empty vs no
  matches, controls follow stubbed `meta`, a `q` change resets to page 1
  (asserting the request URL). RF-2, RF-3, RF-4 (refresh leg), NFR-3, RF-14
  - Done when: `docker compose run --rm frontend npm test` is green including
    the list spec and `docker compose exec frontend npm run build` is green —
    as one task-specific commit.

- [ ] **T4. Product form modal: fields, pre-fill, and live mirror
  validation.** `src/components/Field.tsx` (label + input + error `<p>` with
  `htmlFor`/`id`/`aria-invalid`/`aria-describedby`),
  `src/components/ProductFormModal.tsx` (single create/edit form, values as
  strings except `active: boolean`, `price` text input with
  `inputMode="decimal"` + sanitization per the plan's round-trip mechanics,
  `stock` string-in-form, `sku` uppercased on input, live validation blocking
  submission), `App.tsx` modal state (`closed`/`create`/`edit` + target).
  Tests first: edit pre-fill keeps `price` byte-identical (`49.99`, never
  `49.990000000000002`), the PUT payload sends it as a string, an invalid
  field blocks submission with the exact message. RF-5, RF-6, NFR-2, NFR-3,
  RF-14
  - Done when: `docker compose run --rm frontend npm test` is green including
    the form pre-fill/validation examples and
    `docker compose exec frontend npm run build` is green — as one
    task-specific commit.

- [ ] **T5. Save flow: confirmation, pending state, success, and the
  422/404/other error contracts.** `src/components/ConfirmDialog.tsx`
  (`role="dialog"`, `aria-modal`, Escape, focus move, `inert` background —
  reused by T6) and `src/components/Notification.tsx` (persistent until
  dismissed/replaced); submit flow: valid form → literal confirmation →
  POST/PUT with submit disabled while pending → success notification + close
  modal + `refresh()`; cancel sends nothing and keeps the form open; 422 →
  each `error.details` message under its field, unknown keys (e.g. `sku`
  taken) as a form-level message, values intact; 404 on update → inform +
  close + refresh; any other error or unreachable server → error
  notification, form open, values intact. Tests first in
  `ProductFormModal.test.tsx`: confirmation shows before any request (cancel
  sends nothing; confirm sends `active` as boolean and disables submit),
  422 per-field + form-level rendering, success closes + notifies, 404 and
  network-failure paths. RF-7, RF-8, RF-9, RF-11, RF-4, NFR-3, RF-14
  - Done when: `docker compose run --rm frontend npm test` is green including
    the save-flow examples and `docker compose exec frontend npm run build`
    is green — as one task-specific commit.

- [ ] **T6. Delete flow: confirmation naming the product, feedback, refresh.**
  Delete action on rows/cards (row's action disabled while pending) →
  `ConfirmDialog` naming the product → DELETE → success notification +
  `refresh()`; 404 → "already deleted" message + refresh; other failure →
  error notification, list intact. Tests first:
  `__tests__/components/delete-flow.test.tsx` (confirmation names the
  product; confirm sends DELETE and refreshes; 404 informs and refreshes).
  RF-10, RF-4, NFR-3, RF-14
  - Done when: `docker compose run --rm frontend npm test` is green including
    the delete-flow spec and `docker compose exec frontend npm run build` is
    green — as one task-specific commit.

- [ ] **T7. Responsive layout and accessibility pass.** Split presentation
  into `ProductRow` (md+ table) and `ProductCard` (<md stacked cards) with
  pure-CSS show/hide (D-P21); toolbar and pagination identical at every
  size; verify every input is label-associated, every field error is
  programmatically linked, both dialogs are keyboard-operable (Escape closes
  without sending), and all actions are real `<button>`s. Add the
  accessibility assertions to the suite (`getByLabelText`, `aria-invalid`
  after a failed rule, Escape-to-close). RF-12, NFR-3, NFR-5, RF-14
  - Done when: `docker compose run --rm frontend npm test` is green including
    the accessibility assertions and `docker compose exec frontend npm run
    build` is green — as one task-specific commit.

- [ ] **T8. README rewrite.** Root `README.md` in Spanish (D-P23) with the
  plan's six sections, coherent with the real repository: what the
  application is · how to run everything (`cp .env.example .env`,
  `docker compose up -d --build`, URLs) · how to run each test suite ·
  concise API summary (endpoints, envelopes, error contract) · "Decisiones
  Técnicas" sourced from `MEMORY.md` (D-1…D-11 + D-P*) · "Mejoras Futuras" +
  known limitations (roadmap 003–006; no auth, fixed 10/page, dev-server
  serving, no caching). RF-13
  - Done when: `docker compose down && docker compose up -d --build` follows
    the README's own steps cleanly and every command printed in the README
    matches `MEMORY.md → Development commands` — as one task-specific commit.

- [ ] **T9. Definition-of-Done gate.** Run the full battery and a manual
  smoke of every flow against the seeded dataset: list, search, filter,
  paginate (including deleting the last product of the last page), create,
  edit, save-confirmation cancel, delete-confirmation, the 422 field errors,
  and both empty states; verify the app never blank-screens with the backend
  stopped. RF-1…RF-14, NFR-1, NFR-5, DoD
  - Done when: `docker compose up -d --build`,
    `docker compose run --rm frontend npm test`,
    `docker compose exec frontend npm run build`, and the backend regression
    `docker compose exec backend bundle exec rspec` (C7) all pass, and the
    manual checklist passes; any gap the gate uncovers is fixed and lands in
    T9's single commit — if the gate finds nothing to change, it is recorded
    in the Final check below without its own commit (same rationale as spec
    001's final check).

## Final check (before `/sdd-validate`)

The DoD commands run together as the last gate of T9's validation:

```sh
docker compose up -d --build
docker compose run --rm frontend npm test
docker compose exec frontend npm run build
docker compose exec backend bundle exec rspec
```

## RF coverage

| Task | RFs / NFRs |
|---|---|
| T1 | RF-1, NFR-1, NFR-2, NFR-4 (D-11), NFR-5, RF-14 (harness), DoD (bring-up) |
| T2 | RF-1 (API leg), RF-6 (validators), NFR-2, NFR-3, RF-14 |
| T3 | RF-2, RF-3, RF-4 (refresh leg), NFR-3, RF-14 |
| T4 | RF-5, RF-6, NFR-2, NFR-3, RF-14 |
| T5 | RF-7, RF-8, RF-9, RF-11, RF-4, NFR-3, RF-14 |
| T6 | RF-10, RF-4, NFR-3, RF-14 |
| T7 | RF-12, NFR-3, NFR-5, RF-14 |
| T8 | RF-13 |
| T9 | RF-1…RF-14, NFR-1, NFR-5, DoD (final gate, backend regression C7) |
