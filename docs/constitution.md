# Constitution — Inventory Management (Full Stack Challenge)

Non-negotiable principles for specification, planning, implementation, testing, and
delivery. If any spec, plan, or line of code conflicts with this document, **stop
work** and resolve the conflict with the user first. Amending the Constitution
requires explicit user approval and is recorded in `MEMORY.md` (C4); this project
does **not** use ADRs — decisions live in `MEMORY.md`, and the README reports them.

## I. Scope and requirements

- **C1. No feature code without an approved spec** in `specs/NNN-name/`
  (Constitution → Spec → Clarification → Plan → Tasks → Implementation → Validation).
  Each spec covers one coherent capability with a clearly defined scope: never
  artificially split, never overloaded with unrelated features. It states the
  requirements, the acceptance criteria, and the relevant constraints, and covers the
  challenge's mandatory requirements without unjustified scope.
- **C2. The challenge statement (`docs/Reto técnico.pdf`) is the source of truth** for
  functional requirements and evaluation criteria; mandatory requirements outrank
  optional improvements. The statement requires no authentication: do not implement
  it unless the user approves a scope change. Never invent functionality or widen the
  scope on your own: relevant ambiguities are
  recorded as `OPEN DECISION` in `MEMORY.md` and resolved before the affected part is
  implemented.
- **C3. Order, consistency, traceability, and granularity.** Changes flow spec → plan
  → tasks → code; a relevant requirement change is reflected in the spec before the
  plan and tasks are updated, and any decision that significantly affects scope, the
  API contract, or the architecture needs user approval first. Spec, plan, tasks, and
  code stay consistent, and requirements stay traceable from spec to tasks, to their
  tests, and to the commit that delivered them. Each task is a coherent unit of work with a verifiable result: small
  enough to implement, review, and test clearly, large enough to avoid fragmentation —
  never one task per file or trivial change, never several unrelated features in one
  task. A task has a clear objective, verifiable acceptance criteria, the
  requirements it satisfies, and explicit dependencies. Adjust the granularity when a
  task turns out not to be a practical unit of work, keeping the traceability.
- **C4. Amending this constitution requires explicit user approval**; the change is
  recorded in `MEMORY.md`.

## II. Simplicity and code quality

- **C5. Keep complexity low and the code clean.** Prefer readable, conventional,
  maintainable code that is easy to explain in a technical interview. Separate
  responsibilities without adding layers, services, interfaces, or abstractions that
  bring no real value. Avoid duplication, superfluous dependencies, premature
  generalization, and speculative features. Follow the usual Rails, React, and
  TypeScript conventions; never introduce architectural patterns only to demonstrate
  knowledge. A correct, complete, easy-to-run solution beats a needlessly
  sophisticated one.
- **C6. Add a dependency only for a concrete need whose benefit justifies the added
  complexity** — gem, npm package, component or style library, infrastructure,
  automation, or document. Record it in `MEMORY.md` only when the decision is relevant
  enough to need it; do not document the same decision twice. Nothing enters merely
  because a tool or agent suggested it.

## III. Priority

- **C7. Mandatory before optional, and `main` stays functional.** Optional
  improvements are judged by their contribution to the evaluation, quality, security,
  or user experience; they stay bounded and verifiable and never compromise the
  mandatory scope — an optional increment may not start until **all mandatory
  requirements of the challenge are implemented and validated**. After each task is
  integrated, `main` must keep working **with
  whatever exists at that moment**: the checks that already apply (existing test
  suite, compose services created so far) keep passing. The complete application is
  not a precondition for starting — the rule is simply never to integrate a change
  that breaks what already worked.

## IV. Stack and environment

- **C8. Binding stack:** backend **Ruby on Rails (API mode)** with **PostgreSQL**,
  backend tests **RSpec**; frontend **React + TypeScript** with **Tailwind CSS**;
  execution via **Docker Compose**, reproducible, with no local Ruby, PostgreSQL, or
  Node installation for the agreed flow. Ruby on Rails (API mode), PostgreSQL, React,
  TypeScript, and RSpec are requirements of the challenge; Tailwind CSS is the agreed
  choice among the CSS frameworks the challenge allows; Docker Compose is an optional
  improvement adopted
  as part of this scope. Nothing in this list changes on your own initiative:
  additional libraries (React Query, Vitest, component libraries, …) are welcome only
  when they solve a concrete need with a proportionate benefit (C6), recorded in
  `MEMORY.md` before code.

## V. Backend / API

- **C9. Business validations live in the Rails models**, exactly as the spec defines
  them; controllers and other layers never duplicate them, and no backend abstraction
  is added without a demonstrable need.
- **C10. Consistent, documented error contract:** 404 for a missing resource, 422 for
  a validation failure with per-field detail, 500 for an unexpected error — one JSON
  shape for every error response.
- **C11. The REST contract matches the statement** (routes under `/api/v1/products`,
  the required success and failure cases, CORS for the frontend), and pagination
  (10 items/page by default), name search, and the active/inactive filter are
  implemented **on the server**, never in the client.

## VI. Tests

- **C12. Tests are part of done.** RSpec covers every model validation and every
  required endpoint (success, invalid data, missing resource), proportionally — no
  redundant tests that add no useful coverage. Relevant tests run before each task is
  finished, and the full suite before delivery. Never claim tests pass without having
  run them, and never mark a mandatory feature done without its validation.

## VII. Frontend

- **C13. Explicit TypeScript types; `any` only with justification.** Communication
  with the API stays organized and typed, without unnecessary layers.
- **C14. Mirror rule:** frontend validations stay consistent with the backend rules;
  the backend is the final authority.
- **C15. Every relevant view shows loading, error, and empty states**, with input
  validation, confirmation before destructive actions, visual feedback of operations,
  and a responsive layout (mobile, tablet, desktop). Use Tailwind consistently; no
  additional component or style library without a concrete need (C6).

## VIII. Security

- **C16. No secrets, credentials, or `.env` files with real values are committed.**
  Configuration goes through environment variables; provide `.env.example` when
  needed.

## IX. Commits and documentation

- **C17. Each completed task ends in one specific Git commit** containing the whole
  task, including coordinated changes across files. Run the relevant tests and checks
  before committing; never finish a task or create its commit if validations failed.
  Clear, consistent messages that describe the change: no mixing independent tasks,
  no splitting a task into one commit per file or trivial change, no unrelated
  changes, and never overwriting the user's work. If a task needs splitting or
  regrouping in a way that significantly affects scope or dependencies, update the
  plan first. **The README is a deliverable:** concise architecture, requirements, how
  to run and how to test, relevant technical decisions, and known limitations —
  coherent with the real configuration of the project, without redundant documents.

## Definition of done

A task is done when:

1. It meets its requirements and acceptance criteria.
2. Its implementation keeps a proportionate complexity.
3. The relevant tests and checks have been executed correctly.
4. The changes are delimited and ready for review.
5. Its specific commit has been created.
6. No secrets and no out-of-scope changes were introduced.

The project is ready for delivery when every mandatory requirement is implemented and
validated, the application runs following the README, the repository follows the
layout the statement requires (public GitHub repository with `backend/` and
`frontend/`), and the Git history reflects a coherent set of changes.
