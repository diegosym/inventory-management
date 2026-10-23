# Plan 003 — CI (GitHub Actions)

Status: approved

Derived from the approved `spec.md` (RF-1…RF-6, NFR-1…NFR-3, DoD). This is a
tooling increment: the delivered core (specs 001–002) is **consumed as-is** —
the workflow runs the exact commands `MEMORY.md → Development commands` and the
README document, nothing in `backend/`, `frontend/`, or `docker-compose.yml`
changes (NFR-2 by construction). It fixes what the spec delegated to the plan:
the workflow mechanics (RF-1…RF-4), the non-secret configuration mechanism
(NFR-1), the README content (RF-5), and how RF-6's one-time manual activation is
recorded and verified without the implementer performing it (user decision
**D-14** — parity Docker local/CI — is implemented here, not reopened; the
coordinator records it in `MEMORY.md`).

## Files to create and modify

| File | Responsibility |
|---|---|
| `.github/workflows/ci.yml` (new) | The single CI workflow: events (RF-1), one job named **`CI`** executing the three verifications with run-all semantics (RF-2, RF-3), the project's Docker environment via `docker compose` (RF-4), and the non-secret environment variables that satisfy `docker-compose.yml`'s required `POSTGRES_PASSWORD` on a runner that has no `.env` (NFR-1). |
| `README.md` (modify) | RF-5: a new section **"Integración continua (CI)"** (after "Cómo ejecutar los tests") documenting which checks run and on which events, the run-all behavior, and the required-check note for RF-6 (below). Also: add `.github/workflows/ci.yml` to the repository-structure tree, and update the `003 — CI` bullet under "Mejoras Futuras" to reflect its delivery (C17 coherence). |

Nothing else. No changes to `docker-compose.yml`, the Dockerfiles,
`frontend/package.json`, `.env.example`, or any backend/frontend code or test.

## Workflow mechanics

### Events (RF-1)

- `pull_request` targeting `main` (GitHub defaults: `opened`, `synchronize`,
  `reopened`) — covers feature branches per D-8; a PR updated with new commits
  triggers a run against the **newest** commit, and the required check is tied
  to that head SHA, so an older green run never substitutes for it (edge case —
  default platform behavior, nothing to configure).
- `push` to `main` — covers commits that land on `main` (merge commits).
- **No `paths:` filter** — a docs-only or specs-only change still runs the full
  pipeline (spec edge case: simplest behavior).

### Runner and environment (RF-4)

- `runs-on: ubuntu-latest`: GitHub-hosted runners ship Docker Engine + Compose
  v2, so the project's own `docker compose` commands run unchanged (D-P28). No
  `container:` job wrapper and no self-hosted runner.
- One job, id and name `CI` — the single check the PR reports (D-P25), with
  `timeout-minutes: 20` as a cheap guard against a hung service.
- Fresh ephemeral runner per run: the `db_data` volume and images exist only for
  that run — no state carried between runs (NFR-3).

### Configuration without secrets (NFR-1, C16)

The runner has no `.env`, and `docker-compose.yml` hard-requires
`POSTGRES_PASSWORD` (`:?`). The workflow sets `POSTGRES_USER`, `POSTGRES_DB`,
and `POSTGRES_PASSWORD` in the workflow-level `env:` block as **literal
non-secret values** (e.g. `POSTGRES_PASSWORD: ci-insecure-not-a-secret`) that
compose picks up from the shell environment. They configure an ephemeral
throwaway database inside the runner and grant access to nothing — no
repository secret, no credential, no `.env` file (D-P27). A side benefit: PRs
from forks run with no secrets at all.

### Steps (RF-2, RF-3, RF-4)

Order and commands — the same ones the README documents locally, in the
documented order (D-P14 parity). Sketch (final YAML in implementation):

```yaml
name: CI
on:
  push:    { branches: [main] }
  pull_request: { branches: [main] }
env:                                   # non-secret CI-only config (NFR-1, C16)
  POSTGRES_USER: inventory
  POSTGRES_DB: inventory_development
  POSTGRES_PASSWORD: ci-insecure-not-a-secret
jobs:
  ci:
    name: CI
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Stack up (db + backend + frontend)      # images built once
        run: docker compose up -d --build
      - name: Prepare database
        run: docker compose exec -T backend bin/rails db:prepare db:seed
      - name: Backend — RSpec suite
        run: docker compose exec -T backend bundle exec rspec
      - name: Frontend — Vitest suite
        if: ${{ !cancelled() }}                       # run-all (RF-3)
        run: docker compose run -T --rm frontend npm test
      - name: Frontend — production build (tsc + vite)
        if: ${{ !cancelled() }}                       # run-all (RF-3)
        run: docker compose exec -T frontend npm run build
```

- **Startup:** one `docker compose up -d --build` brings up all three services;
  the compose `depends_on: service_healthy` gate waits for PostgreSQL before
  the backend starts, and `bin/rails db:prepare db:seed` mirrors the
  documented first-run step (D-P30). `rails_helper` maintains the test schema,
  so the documented sequence is exactly what has been proven locally
  (backend 90/0, frontend 57/57 — `MEMORY.md`).
- **Run-all (RF-3):** steps 2 and 3 are guarded with `if: ${{ !cancelled() }}`.
  GitHub Actions runs `if:`-guarded steps even after an earlier step failed, and
  a failed step keeps the job (and the run, and the PR check) red — so a
  failing RSpec suite still lets Vitest and the build execute, and the check UI
  highlights the failing step by name ("Backend — RSpec suite"), which is how
  the check identifies which verification failed. A verification can never be
  reported as success: no step uses `continue-on-error` (D-P26).
- **Infrastructure failure (edge case):** if `docker compose up` or
  `db:prepare` fails, the job is red and the guarded steps attempt to run and
  fail as well — trouble never counts as success.
- **Non-interactive runner:** `exec`/`run` carry `-T` (no TTY on runners).
  Same images, same compose file, same suite, same commands — only TTY
  allocation differs, which is a runner property, not test configuration
  (D-P29; D-14 parity unaffected).
- `actions/checkout` is the only marketplace action used — the repo must exist
  on the runner; nothing else is pulled (C6).

## RF-6: required check — recorded, performed by the user

The branch-protection activation is a one-time manual repository setting the
**user** performs in GitHub; the implementer never does it. The plan makes it
verifiable and assigns it:

- The README CI section states, in Spanish: the check is named **`CI`**; to
  make it required for merging into `main`, the repository owner adds it under
  *Settings → Branches → branch protection for `main` → Required status checks*
  ("Require a pull request before merging" + "Require status checks to pass");
  this is a one-time manual configuration by the owner. It also states the
  resulting behavior: a PR with a failed or missing `CI` run cannot be merged;
  a green one can.
- The tasks generated from this plan include one task that delivers that
  documentation and then **hands the activation to the user**, capturing the
  user's confirmation (DoD: red PR unmergeable, then green PR mergeable) as the
  verification evidence — exactly the spec's required end state, verified on
  any red PR.

## Verification of this plan

The plan's command sequence is confirmed with the binding commands from
`MEMORY.md → Development commands`, run locally before any implementation:

```sh
docker compose up -d --build
docker compose exec backend bin/rails db:prepare db:seed
docker compose exec backend bundle exec rspec    # must be green (90 examples)
docker compose run --rm frontend npm test        # must be green (57 tests)
docker compose exec frontend npm run build       # must succeed (tsc + vite)
```

Green here proves the exact steps the workflow will execute (D-14 parity).
Post-implementation evidence (a real PR run green; a temporarily broken test
turning the run red with all three verifications executed, then reverted; the
user's required-check confirmation) is the DoD material of the tasks, verified
on GitHub's UI.

## Technical decisions (discarded alternative included)

- **D-P25 — One job named `CI`, run-all steps; no parallel jobs.** Discarded:
  three jobs (one per verification) — with build caching out of scope each job
  would rebuild/pull the full compose stack (≈3× setup cost), duplicate the
  compose-up logic three times, and turn one required check into three to
  configure and keep in sync; parallel wall-clock time is not a requirement.
- **D-P26 — Run-all via `if: ${{ !cancelled() }}` on the later steps.** A failed
  step fails the job while guarded steps still run, and the failing step is
  named in the check UI. Discarded: `continue-on-error` + a final gate step (a
  failed verification would render as a green-with-warning step — RF-3 forbids
  reporting failure as success or tolerating it); one bash step capturing exit
  codes with `set +e` (loses the native per-step identification RF-3 requires
  and buries the failure in a log); `always()` (would run the remaining
  verifications even after a manual cancellation, wasting minutes).
- **D-P27 — `POSTGRES_*` as literal non-secret values in the workflow's `env:`
  block.** Discarded: a step that writes a `.env` file on the runner (the
  local-file pattern for zero benefit on an ephemeral runner, and it invites
  real-secret habits); a GitHub Actions `secret:` (exactly what NFR-1 forbids,
  plus a manual setup step for the user); relaxing `docker-compose.yml`'s
  `${POSTGRES_PASSWORD:?}` to a default (weakens the local C16/D-1 guardrail
  and modifies the delivered core — NFR-2).
- **D-P28 — GitHub-hosted `ubuntu-latest` with its preinstalled Docker +
  Compose v2; the compose stack runs on the runner daemon.** Discarded:
  `container: ruby:3.3`-style job images (steps would run inside one image
  without the compose services — breaks RF-4/D-14 parity) and a self-hosted
  runner (infrastructure outside the challenge's scope, and a maintenance
  liability).
- **D-P29 — `docker compose exec`/`run` gain `-T` in CI.** Runners have no TTY,
  so without `-T` `exec` aborts with "the input device is not a TTY".
  Discarded: forcing a pseudo-TTY (`script -qec`, `-t` wrappers) — obscure,
  untestable locally, and hides the real command; replacing every `exec` with
  `run --rm` (changes the documented command surface and runs one-off
  containers where a running service exists).
- **D-P30 — One `docker compose up -d --build` for all three services, then
  `bin/rails db:prepare db:seed`, then the verifications in order backend →
  frontend tests → build.** Exactly the documented local flow (D-14). Discarded:
  selective service startup (`up db backend` + `compose run` for the frontend —
  more compose invocations and a divergence from the one-command documented
  startup for no time gain, since images build once either way); running only
  `RAILS_ENV=test db:prepare` (diverges from the documented flow;
  `rails_helper` maintains the test schema anyway); skipping `db:seed` (a few
  seconds saved against exact parity and an extra exercise of the seeds).

## RF coverage map

| Part | Covers |
|---|---|
| `.github/workflows/ci.yml` — `on:` block | RF-1, edge cases (newest commit, no path filter) |
| `.github/workflows/ci.yml` — job + steps | RF-2, RF-3 (run-all), RF-4 (compose commands, `-T`), NFR-2 (no core change), NFR-3 (ephemeral runner) |
| `.github/workflows/ci.yml` — `env:` block | NFR-1 (no secrets, C16) |
| `README.md` — "Integración continua (CI)" section | RF-5, and the RF-6 record (check name `CI` + user activation) |
| `README.md` — structure tree + "Mejoras Futuras" 003 bullet | RF-5 coherence (C17) |
| RF-6 resulting state (user activation, confirmed in tasks) | RF-6, DoD |

## Out of scope for this plan

Everything under the spec's Out of scope: CD/deployment (`006-deploy`), soft
delete + audit (`004-data-integrity`) and OpenAPI (`005-openapi`) — their future
tests join these same suites with no CI change; CI notifications, coverage or
lint reporting, Docker image builds as checks, and build/layer caching; path
filters, matrices, and concurrency configuration; any change to specs 001/002,
their local commands, or the compose stack; and the branch-protection setting
itself, which stays a one-time manual action of the user (RF-6).
