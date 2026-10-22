# Plan 002 — Frontend UI (Product CRUD)

Status: approved

Derived from the approved `spec.md` (RF-1…RF-14, NFR-1…NFR-5, DoD). Everything
runs through `docker compose` per D-1/C8 and `MEMORY.md → Development commands`.
The API contract is frozen by spec 001 (D-7/D-9): this plan consumes it as-is,
with **no backend changes**. It fixes what the spec delegated to the plan: how
the `frontend` service is served (RF-1), the source architecture, the state
flows (RF-3, RF-7…RF-11), the `price` round-trip mechanics (RF-5/RF-6), the
Tailwind setup and responsive strategy (RF-12, NFR-5), the test suite layout
(RF-14), and the exact README sections (RF-13). The React code follows
`vercel-react-best-practices` as a quality reference (NFR-3): no inline
component definitions, primitive `useEffect` dependencies, state derived during
render, ternaries over `&&` for conditional JSX, direct imports — a guide for
implementation, not extra requirements.

## Files to create and modify

| File | Responsibility |
|---|---|
| `docker-compose.yml` (modify) | Add the `frontend` service (D-P13): `node:22` via `frontend/Dockerfile`, `npm run dev` on 5173, bind mount `./frontend:/app` for HMR plus an anonymous `/app/node_modules` volume, env `VITE_API_BASE_URL=http://localhost:3000`. `db`/`backend` untouched. |
| `.env.example` (modify) | Document `VITE_API_BASE_URL` (browser-reachable backend URL, D-P14). No secrets (C16). |
| `frontend/Dockerfile` | `node:22`; `WORKDIR /app`; `COPY package*.json` + `npm ci` at build time; `COPY . .`. Dev server is the runtime (RF-1). |
| `frontend/.dockerignore` | `node_modules`, `dist` (small, correct build context). |
| `frontend/package.json`, `frontend/package-lock.json` | Scripts: `dev` (Vite), `build` (`tsc -b && vite build` — the typecheck gate, NFR-2), `test` (`vitest run`, non-watch so the binding command exits). Deps per D-P20/D-P22; lockfile committed for reproducible `npm ci`. |
| `frontend/tsconfig.json` (+ `tsconfig.node.json`) | Strict TypeScript (NFR-2); standard Vite split. |
| `frontend/vite.config.ts` | Plugins `@vitejs/plugin-react` + `@tailwindcss/vite`; `server: { host: true, port: 5173 }` (reachable through the compose port mapping); `test` block for Vitest (jsdom, globals, setup file). |
| `frontend/index.html` | Vite entry; mounts `#root`. |
| `frontend/src/main.tsx` | React root; imports `index.css`. |
| `frontend/src/index.css` | Tailwind entry + the design tokens (D-P20): `@theme` block defining brand/surface/danger/success colors, radius, and base font styles. |
| `frontend/src/App.tsx` | Single view (no router, D-10): owns `useProducts`, modal open state (create vs edit target vs closed), the notification slot; composes list + modal + dialogs. |
| `frontend/src/types/api.ts` | Contract types (D-7): `Product`, `ListingMeta`, listing/single envelopes, `ApiErrorBody`, and `ApiError` (an `Error` subclass carrying `status`, `code`, `details?`). No `any` without written justification (NFR-2). |
| `frontend/src/api/products.ts` | Plain-`fetch` layer (D-10): `listProducts({ page?, q?, active? })`, `createProduct(payload)`, `updateProduct(id, payload)`, `deleteProduct(id)`; one private `request` helper that parses `{ error }` bodies into `ApiError` and rethrows network failures. Base URL from `import.meta.env.VITE_API_BASE_URL`. |
| `frontend/src/validators/product.ts` | The mirror module (C14/D-9): `validateField` + `validateProduct` over `ProductForm` (all values as strings except `active: boolean`), returning per-field messages identical to the backend's (literals fixed below). SKU uppercasing on input (D-6 mirror). |
| `frontend/src/hooks/useProducts.ts` | Listing state: `{ products, meta, status: 'loading' \| 'error' \| 'ready', q, active, page, …setters, retry, refresh }`; owns the debounce effect, page-1 reset on `q`/`active` change, and the page clamp (below). One plain `fetch` per param change — no client-side search/filter/pagination (RF-2, C11). |
| `frontend/src/hooks/useDebouncedValue.ts` | Tiny hook: delays a string value by ~300 ms (D-10) with timer cleanup. |
| `frontend/src/components/ProductList.tsx` | Toolbar (search input, `active` filter select), the desktop table / mobile card rendering, pagination controls driven by `meta` (`current_page`, `total_pages`, `total_count`), and the loading/error/empty states (RF-2, RF-3, RF-12). |
| `frontend/src/components/ProductRow.tsx`, `ProductCard.tsx` | One product's presentation + Edit/Delete buttons; table row (`md+`) and list card (`<md`) variants share props (small markup duplication accepted over conditional-attribute soup — C5). |
| `frontend/src/components/ProductFormModal.tsx` | The single create/edit form (RF-5): fields, live mirror validation (RF-6), server-error rendering (RF-8), pending state with submit disabled (RF-7), confirmation trigger (RF-7/D-10). Owns form values and both error maps. |
| `frontend/src/components/Field.tsx` | Label + input + error `<p>` with correct `htmlFor` / `id` / `aria-invalid` / `aria-describedby` association (RF-12). |
| `frontend/src/components/ConfirmDialog.tsx` | One confirmation dialog reused for save (create **and** edit, RF-7/D-10) and delete (RF-10); props: title, message (delete names the product), confirm/cancel labels; `role="dialog"`, `aria-modal`, Escape closes, focus moves into the dialog on open, background rendered `inert`. |
| `frontend/src/components/Notification.tsx` | In-page success/error notification (RF-7, RF-10, RF-11, C15); persists until dismissed or replaced (no timers — deterministic and testable). |
| `frontend/src/components/states.tsx` | `LoadingState`, `ErrorState` (with retry button, RF-3), `EmptyState` (distinguishes empty inventory from no matches, RF-3). |
| `frontend/src/test/setup.ts` | `@testing-library/jest-dom` matchers + cleanup. |
| `frontend/src/__tests__/validators/product.test.ts` | Every mirror rule and boundary (RF-6, RF-14). |
| `frontend/src/__tests__/components/ProductList.test.tsx` | List states + meta-driven controls (RF-2, RF-3, RF-14). |
| `frontend/src/__tests__/components/ProductFormModal.test.tsx` | Prefill/round-trip, validation blocking, confirmation, success, 422 mapping (RF-5…RF-8, RF-14). |
| `frontend/src/__tests__/components/delete-flow.test.tsx` | Delete confirmation naming the product → DELETE sent → refresh (RF-10, RF-14). |
| `README.md` (rewrite) | RF-13 sections, in Spanish per D-P23, coherent with the real repo. |

## API surface consumed (frozen — D-7/D-9, spec 001)

No new endpoints. The frontend calls:

| Call | Request | Success | Failure handling here |
|---|---|---|---|
| `GET /api/v1/products?page&q&active` | query string (`active` as `"true"`/`"false"`) | 200 `{ data: Product[], meta }` | 422 (malformed params — the client never sends them; surfaced as the list error state), 5xx/network → list error state (RF-3) |
| `POST /api/v1/products` | `{ "product": { name, description, price, stock, sku, active } }` — values as **trimmed strings**, `active` a JSON **boolean** (D-9) | 201 `{ data }` | 422 → per-field (RF-8); 5xx/network → notification, form intact (RF-11) |
| `PUT /api/v1/products/:id` | same body (full replacement) | 200 `{ data }` | 404 → inform, close, refresh (RF-9); 422 → per-field (RF-8); 5xx/network → RF-11 |
| `DELETE /api/v1/products/:id` | — | 204 empty | 404 → inform + refresh; other → error notification, list intact (RF-10) |

`price` arrives serialized as the 2-decimal string `"49.99"` (D-P5) and is sent
back as a string (D-P17) — the server casts.

## State flows

### List (RF-2…RF-4)

- `useProducts` refetches on every change of `page`, debounced `q` (~300 ms, D-10),
  or `active`; changing `q` or `active` resets to page 1 (RF-2). While a request
  is in flight → `LoadingState`; failure → `ErrorState` with a retry button that
  re-requests (RF-3, spec edge case "backend unreachable": never crash/blank).
- Empty distinction (RF-3): `total_count === 0` with no `q` and no `active` →
  "empty inventory"; otherwise → "no matches" for the current search/filter.
  A page beyond the last page returns 200 + empty `data` (spec 001 RF-13): the
  empty state shows and pagination stays operable; after a mutation's refresh,
  if `page > meta.total_pages` the hook re-requests the last valid page (or 1)
  so deleting the last product of the last page never strands the user (spec
  edge case).
- Every successful create/update/delete triggers `refresh()` (RF-4) with the
  current params — the list always reflects the server.

### Form: create and edit (RF-5…RF-9)

- `App` owns modal state: `mode: 'closed' | 'create' | 'edit'` plus the target
  `Product`. Opening edit pre-fills `ProductForm` from the product; on input the
  mirror validator marks invalid fields with the backend's messages and blocks
  submission (RF-6).
- Submit flow (RF-7): valid form → `ConfirmDialog` ("confirmación antes de
  guardar", both modes, D-10) → on confirm: POST/PUT with submit disabled (no
  double submission) → success → success notification + close modal + `refresh()`
  (RF-4); on cancel: nothing sent, form stays open with its values.
- 422 (RF-8): form stays open with entered values; each `error.details` key that
  matches a field renders under it; keys matching no field (e.g. `sku` taken,
  `base`) render as a form-level message. 404 on update (RF-9): message, close
  the form, refresh the list. Any other error or unreachable server (RF-11):
  error notification, form open, values intact.

### Delete (RF-10)

- Delete button → `ConfirmDialog` naming the product → confirm → DELETE with the
  row's action disabled while pending → success notification + `refresh()`;
  404 → "already deleted" message + refresh; other failure → error notification,
  list unchanged.

### `price` round-trip (RF-5/RF-6 — the fixed mechanics)

The decimal string must survive edit → save without precision loss; nothing may
convert it to a JS `number` (binary floats turn `49.99` into `49.99000…`):

```
open edit:        form.price = product.price              # "49.99" passthrough, no Number()
typing:           sanitize input to /^\d*(\.\d*)?$/       # strips junk, keeps what the user typed
validate:         ""                      -> "can't be blank"
                  !/^\d+(\.\d{1,2})?$/   -> "must have at most 2 decimal places"   # exact literal, D-9
                  Number(v) <= 0         -> "must be greater than 0"               # comparison only
submit:           price: form.price.trim()                # sent as the JSON string "49.99"
```

- Input is `type="text"` with `inputMode="decimal"` (D-P17): the user can type
  intermediate values like `49.` without a browser re-parsing the field.
- `stock` follows the same string-in-form discipline (`stock: form.stock.trim()`;
  the server casts), with client-side integer/`>= 0` checks; `sku` is uppercased
  on input (D-6 mirror); `description` optional, `active` a checkbox (always a
  real boolean in the payload).

## Validation literals mirrored (C14/D-9)

Client messages copy the backend's Rails defaults exactly, so the mirror and the
422 `details` the server renders under the same field are the same text:

- `name`: "can't be blank", "is too short (minimum is 3 characters)",
  "is too long (maximum is 100)".
- `description`: "is too long (maximum is 1000 characters)".
- `price`: "can't be blank", "must have at most 2 decimal places" (D-9 exact),
  "must be greater than 0".
- `stock`: "can't be blank", "must be an integer", "must be greater than or
  equal to 0".
- `sku`: "can't be blank", "is invalid" (charset `[A-Z0-9-]+`).
- Uniqueness is **not** mirrored client-side (server-only rule): it surfaces as
  the 422 `details.sku` path of RF-8.

## Tailwind and responsive layout (D-2, RF-12, NFR-5)

- Tailwind v4 through the `@tailwindcss/vite` plugin (D-P20); tokens (brand,
  surface, danger, success colors; radius; base typography) live in
  `src/index.css` inside `@theme` — the single source of styling truth, no
  parallel CSS system (NFR-5). If the same 3+ token combination repeats across
  components, it becomes a small local component class (D-2).
- Mobile-first (D-P21): below `md` (768px) the list renders stacked cards; at
  `md`+ a table (name, SKU, price, stock, active, actions). Pure CSS
  show/hide — no JS viewport detection, no per-breakpoint component trees.
  Toolbar (search + filter) and pagination stay identical at every size.
- Accessibility (RF-12): `Field` associates label/error programmatically; both
  dialogs are `role="dialog"` + `aria-modal` with focus moved in, Escape to
  close, and the background `inert` while open; all actions are real
  `<button>`s, operable by keyboard alone.

## Test strategy (RF-14, NFR-1, C12)

Vitest + React Testing Library + `@testing-library/user-event` + jsdom, with
`fetch` stubbed via `vi.stubGlobal` — no MSW (D-P22, C6). Tests live under
`frontend/src/__tests__/` mirroring `src/`. Binding commands from
`MEMORY.md → Development commands`:

```sh
docker compose up -d --build
docker compose run --rm frontend npm test       # vitest run (non-watch)
docker compose exec frontend npm run build      # tsc -b && vite build — typecheck gate
docker compose exec backend bundle exec rspec   # regression: backend still green (DoD, C7)
```

- **Validators** — one example per rule and boundary: name 2/3/100/101 chars;
  description 1000/1001; price `""`/`0`/`-1`/`9.999` (exact D-9 message)/valid
  `49.99`; stock `-1`/`1.5`/`0`/`12`; sku missing/`abc@123`/uppercase
  normalization `abc-123` → `ABC-123`; valid full form.
- **List** — loading state while the fetch is pending; error state with working
  retry; empty inventory vs no matches; pagination controls follow the stubbed
  `meta`; a `q` change resets to page 1 (asserts the request URL).
- **Form** — edit pre-fill keeps `price` byte-identical (`49.99` never
  `49.990000000000002`) and the PUT payload sends the string; invalid field
  blocks submission; valid submit shows the confirmation first — cancelling
  sends nothing, confirming POSTs with `active` as boolean and disables submit;
  a 422 renders each `details` message under its field plus an unknown key as a
  form-level message; success closes the modal and shows the notification.
- **Delete** — confirmation names the product; confirm sends DELETE and refreshes;
  404 informs and refreshes.

## Technical decisions (discarded alternative included)

- **D-P13 — `frontend` service runs the Vite dev server** (`node:22`, port
  5173, bind mount + anonymous `node_modules` volume for HMR); a single
  `docker compose up -d --build` brings up all three services — no
  `docker-compose.override`. Discarded: serving the production build via nginx
  (a second image and a non-existent production deploy — spec 006; RF-1 fixes
  the dev-server origin) and the override file (indirection for zero benefit —
  C5).
- **D-P14 — The API base URL is `VITE_API_BASE_URL`, default
  `http://localhost:3000`** — the host-mapped backend port, because the browser
  (not the container) makes the calls; `http://backend:3000` is unresolvable
  from the host. Discarded: proxying `/api` through the Vite dev server (extra
  config that hides the real cross-origin path CORS was built for — D-9).
- **D-P15 — Vite + React + TypeScript scaffold; single view, plain `fetch`.**
  React Query and react-router are **not** adopted (D-10, user decision); one
  `useProducts` hook plus a `useDebouncedValue` hook replace them. Discarded:
  any state/data library (C6: ~200 lines of well-tested code vs a dependency).
- **D-P16 — Layered `src/` layout** (`components` / `api` / `validators` /
  `hooks` / `types`): each rule and flow is isolated and directly testable.
  Discarded: everything in `App.tsx` (untestable at RF-14's granularity) and
  feature-folder abstractions (one feature exists — C5).
- **D-P17 — `price` (and `stock`) stay strings end-to-end in the form layer.**
  Discarded: `type="number"` inputs (the browser re-parses/rounds what it
  dislikes and breaks the round-trip) and `Number(price)` conversion (binary
  float artifacts like `49.990000000000002` sent to the server).
- **D-P18 — Client messages are literal copies of the backend's**, with
  uniqueness left to the server's 422 (documented above). Discarded: paraphrased
  friendlier messages (the mirror rule C14 compares texts; D-9 fixes the price
  message exactly).
- **D-P19 — Confirmations are one small overlay `ConfirmDialog`** (div with
  `role="dialog"`, Escape, focus move, `inert` background), reused for save and
  delete. Discarded: the native `<dialog>`/`showModal` (browser-free extras are
  attractive but jsdom support is uneven, complicating RF-14) and a focus-trap
  library (dependency for behavior one handler covers — C6).
- **D-P20 — Tailwind v4 via `@tailwindcss/vite`, tokens in `@theme`.**
  Discarded: Tailwind v3 with `tailwind.config.js` + PostCSS wiring (two extra
  config files for the same result).
- **D-P21 — Responsive via CSS-only breakpoints**, cards < 768px, table ≥ 768px.
  Discarded: JS viewport detection/conditional trees (re-renders and split
  code paths for a styling concern).
- **D-P22 — Test stack per D-10: Vitest + RTL + user-event + jsdom +
  jest-dom, `fetch` stubbed with `vi.stubGlobal`.** Discarded: MSW (a network
  mocking dependency where five stubbed tests suffice — C6).
- **D-P23 — The project README stays in Spanish**, rewritten for the challenge's
  own section names ("Decisiones Técnicas", "Mejoras Futuras"; C2). Sections:
  what the app is · how to run everything (`cp .env.example .env`,
  `docker compose up -d --build`, URLs) · how to run each test suite · concise
  API summary (endpoints, envelopes, error contract) · key technical decisions
  and why (sourced from `MEMORY.md` D-1…D-10 + D-P*) · future improvements and
  known limitations (bonus roadmap 003–006; limitations: no auth, fixed
  10/page, dev-server serving, no caching). Discarded: English README
  (the evaluator and the statement are Spanish) and keeping the current
  scaffold text (RF-13 demands the real commands and layout).
- **D-P24 — One env source: the root `.env.example` gains
  `VITE_API_BASE_URL`;** compose passes it to the service and Vite exposes only
  `VITE_`-prefixed variables. Discarded: a second `frontend/.env.example`
  (two files to keep in sync — C5).

## RF coverage map

| Part | Covers |
|---|---|
| `docker-compose.yml`, `frontend/Dockerfile`, `.env.example` | RF-1, NFR-1, NFR-4, DoD |
| `src/api/products.ts`, `src/types/api.ts` | RF-1, NFR-2, contract consumption (D-7/D-9) |
| `useProducts` + `useDebouncedValue` + `ProductList` | RF-2, RF-3, RF-4 (refresh), edge cases (out-of-range page, unreachable server) |
| `ProductFormModal` + `Field` + `validators` | RF-5, RF-6, RF-7, RF-8, RF-9, RF-11 (form leg), `price` round-trip |
| `ConfirmDialog` + delete flow in `ProductList`/`App` | RF-7 (save confirmation), RF-10 |
| `Notification` + states | RF-3, RF-7, RF-10, RF-11 (C15 feedback) |
| Tailwind setup + responsive components | RF-12, NFR-5 |
| `README.md` rewrite | RF-13 |
| `src/__tests__/**` | RF-14, NFR-3 (exercised through the suite) |
| Everything runs via compose | NFR-1, DoD |

## Out of scope for this plan

Everything under the spec's Out of scope: CI (003), soft delete/audit (004),
OpenAPI (005), deploy (006), authentication, client-side caching, offline
mode, i18n, dark mode, `per_page`, any library beyond the set fixed above
(react, react-dom, vite, typescript, tailwindcss + vite plugin, vitest, jsdom,
testing-library react/user-event/jest-dom — C6), and any backend change.
