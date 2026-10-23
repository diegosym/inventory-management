# Tasks 003 — CI (GitHub Actions)

Derived from the approved `spec.md` (RF-1…RF-6, NFR-1…NFR-3, edge cases, DoD) and
the user-approved `plan.md` (workflow + README surface, D-P25…D-P30).

Approvals verified before generating this file:

- `spec.md` → `Status: approved`.
- `plan.md` → `Status: approved` (user's explicit approval; status header updated
  in the session that generated this file).

Rules:

- One task = one task-specific commit (C17) for T1–T2 (the tasks that change
  repo files). T3–T5 are verification tasks whose evidence lives in GitHub's UI,
  not in a commit (same rationale as the final-check sections of specs 001/002).
- The T4 drill's broken-test commit lives only on the PR branch and is reverted
  there — the breakage never lands on `main`.
- Local checks use only `MEMORY.md → Development commands` (everything via
  `docker compose`).
- No file under `backend/`, `frontend/`, or `docker-compose.yml` is touched
  (NFR-2); nothing from specs 004–006 (spec Out of scope).
- Dependency order: T1 → T2 → T3 → T4 → T5. The implementer delivers T1 and T2;
  T3–T5 require GitHub and are performed/confirmed by the **user** (or by the
  coordinator on the user's behalf with `gh`) — the implementer cannot activate
  branch protection nor push/verify a real PR by themselves.

## Tasks

- [x] **T1. The CI workflow: `.github/workflows/ci.yml`.** Per the plan: events
  `push` and `pull_request` targeting `main`, no `paths:` filter; one job with id
  and name **`CI`** on `ubuntu-latest` with `timeout-minutes: 20`; workflow-level
  `env:` block with literal non-secret `POSTGRES_USER`, `POSTGRES_DB`,
  `POSTGRES_PASSWORD` (no `secret:`, no `.env` file written — NFR-1/C16); steps in
  the documented order: `actions/checkout`, `docker compose up -d --build`,
  `docker compose exec -T backend bin/rails db:prepare db:seed`, backend RSpec,
  frontend Vitest, frontend `npm run build` — the last two guarded with
  `if: ${{ !cancelled() }}`, every `exec`/`run` carrying `-T`, no
  `continue-on-error`. RF-1, RF-2, RF-3, RF-4, NFR-1, NFR-2, NFR-3
  - Done when: the workflow file matches that structure (single `CI` job;
    `!cancelled()` guards on exactly the two later verifications; `-T` on every
    compose `exec`/`run`; no `continue-on-error`, no `secret:`, no `paths:`;
    `checkout` is the only marketplace action), no file besides
    `.github/workflows/ci.yml` is modified (`git diff --stat`), and the plan's
    local parity sequence runs green — proving the exact steps the workflow will
    execute (D-14): `docker compose up -d --build`,
    `docker compose exec backend bin/rails db:prepare db:seed`,
    `docker compose exec backend bundle exec rspec`,
    `docker compose run --rm frontend npm test`,
    `docker compose exec frontend npm run build` — as one task-specific commit.

- [x] **T2. README: the CI section and coherence updates.** New section
  **"Integración continua (CI)"** after "Cómo ejecutar los tests" documenting
  which three checks run and on which events (push to `main`, PR targeting
  `main`), the run-all behavior, and the required-check note: the check is named
  `CI`; making it required for merging into `main` is a one-time manual
  repository setting by the owner (*Settings → Branches → branch protection for
  `main` → Require a pull request before merging* + *Require status checks to
  pass* → `CI`); resulting behavior: a PR with a failed or missing `CI` run
  cannot be merged, a green one can. Also: add `.github/workflows/ci.yml` to the
  repository-structure tree, and update the `003 — CI` bullet under "Mejoras
  Futuras" to reflect its delivery. RF-5, RF-6 (documentation leg)
  - Done when: the README section is coherent with the workflow delivered in T1
    (same check name, events, and commands), every `docker compose` command
    printed in the README still matches `MEMORY.md → Development commands`, and
    `git diff --stat` shows `README.md` as the only modified file — as one
    task-specific commit.

- [ ] **T3. First real PR run, green (user / coordinator action).** Push the
  branch containing T1+T2 and open a pull request targeting `main`; the GitHub
  run executes the three verifications against the newest commit and is green.
  RF-1 (real evidence), RF-2, RF-4 (D-14 parity on a real runner), DoD (first
  bullet)
  - Done when: the PR's `CI` check reports success and its log shows all three
    verifications executed with the documented `docker compose` commands
    (evidence: the run URL reported to the coordinator; no repo commit —
    verification only). If the run is red, the coordinator reports the failing
    step to the user and implementation resumes before proceeding.

- [ ] **T4. Run-all drill: a deliberately broken test turns the run red naming
  the failing verification, then reverted (user / coordinator action).** On the
  same PR branch, temporarily break one backend test and push: the run must stay
  red while still executing the remaining verifications, and the check UI must
  name the failing step ("Backend — RSpec suite"). Then revert the breakage
  (revert commit on the PR branch) and confirm the run returns green. The
  breakage never lands on `main`. RF-3, DoD (second bullet), edge case
  (failure never counts as success)
  - Done when: the red run's log shows all three verification steps attempted
    with the failing one named and the PR check as failed, and the revert commit
    restores a green run (evidence: both run URLs reported to the coordinator;
    no commit on `main` — verification only).

- [ ] **T5. Required check activated and verified (user action).** The
  repository owner activates the branch protection per the README's T2
  instructions (required status check `CI` on `main`). Then, on a red PR state
  (e.g. reusing the T4 drill mechanism), confirm merging into `main` is
  disallowed; after the revert makes it green, confirm merging is allowed. RF-6,
  DoD (third bullet)
  - Done when: the user confirms to the coordinator that (a) a PR with a failed
    or missing `CI` run shows merging disallowed, and (b) the green PR shows
    merging allowed — the one-time manual setting and its confirmation are
    recorded in the session report; no repo commit. With T5, `/sdd-validate
    003-ci` can verify the full DoD.

## RF coverage

| Task | RFs / NFRs / DoD |
|---|---|
| T1 | RF-1, RF-2, RF-3, RF-4, NFR-1, NFR-2, NFR-3 |
| T2 | RF-5, RF-6 (documentation leg) |
| T3 | RF-1 (real evidence), RF-2, RF-4 (D-14 parity), DoD (first bullet) |
| T4 | RF-3, DoD (second bullet), edge cases (failure never success) |
| T5 | RF-6, DoD (third bullet) |
