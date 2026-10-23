# Spec 003 — CI (GitHub Actions)

Status: approved

## Context and goal

First bonus increment (D-4, C7: specs 001–002 delivered and untouched here):
automated verification for every proposed change, covering the statement's bonus
"CI/CD configurado" (C2) at its CI half — GitHub Actions running the backend
RSpec suite, the frontend test suite (spec 002 RF-14), and the frontend build
(`npm run build`: typecheck + production build, per README). No further CI is
required by the statement; the CD half belongs to `006-deploy`.

## Users

- Developer: gets pass/fail feedback on each proposed change before it merges.
- Evaluator: sees the repository verify itself automatically on every change.

## User stories

- US-1. As a developer, I want every change proposed to `main` to run the backend
  suite, the frontend suite, and the frontend build, so regressions are caught
  before merging.
- US-2. As an evaluator, I want CI configured in the repository, so the challenge's
  "CI/CD configurado" bonus is demonstrably met.

## Definitions

- **The three verifications**: (1) the backend RSpec suite, (2) the frontend
  Vitest suite, (3) the frontend production build — exactly what the README
  documents for local runs.
- **Pipeline run**: one execution of the CI workflow against one exact commit.

## Functional requirements

- RF-1: WHEN a commit is pushed to `main`, or a pull request targeting `main` is
  opened or updated, THE SYSTEM runs one pipeline that executes the three
  verifications against that commit. (Why: D-8 — feature branches land through
  pull requests, so PR runs cover work in progress, push runs cover `main`.)
- RF-2: THE SYSTEM executes all three verifications on every run — none optional,
  none skipped — and the run succeeds only when the three succeed.
- RF-3: IF one verification fails, THEN THE SYSTEM still executes the remaining
  verifications and afterwards marks the run as failed (run-all: no fail-fast);
  the pull request's check reports failure identifying which verification
  failed, and a failed verification is never reported as success or tolerated.
- RF-4: THE SYSTEM runs the three verifications in the project's Docker
  environment with the same documented `docker compose` commands used locally —
  never a reduced, differently configured, or parallelized test suite (same
  tests, same commands as local) — so the same commit yields the same verdict
  locally and in CI (single source of truth; user decision, to be recorded as
  **D-14** in `MEMORY.md`; workflow mechanics belong to the plan).
- RF-5: THE `README.md` documents which checks the pipeline runs and on which
  events, coherent with the workflow actually delivered (C17).
- RF-6: THE CI check is required for merging into `main`: WHILE a pull request
  targeting `main` has a failed or missing CI run, THE SYSTEM disallows merging
  it; WHEN the check passes, merging is allowed. This is a one-time manual
  repository (branch protection) setting performed by the user — the spec
  requires the resulting state, verifiable on any red pull request.

## Non-functional requirements

- NFR-1: THE SYSTEM needs no repository secret or credential to run (C16):
  configuration goes through non-secret environment variables only.
- NFR-2: THE pipeline changes nothing for the delivered core: specs 001/002 and
  their local verification commands keep working exactly as documented (C7).
- NFR-3: THE pipeline's verdict is reproducible: re-running it against the same
  commit yields the same result (no state carried between runs).

## Edge cases

- A pull request updated with new commits → the pipeline runs against the newest
  commit; an older green run never substitutes for it.
- A change touching only docs or specs → the full pipeline still runs (simplest
  behavior; no path filtering).
- A verification that cannot start (e.g. its service fails to come up) → the run
  fails; infrastructure trouble never counts as success.

## Out of scope

- CD / deployment → spec `006-deploy` (the statement bonus is split: CI here,
  CD there).
- Soft delete + audit → spec `004-data-integrity`; OpenAPI → spec `005-openapi` —
  their future tests join these same suites automatically; no CI change needed.
- CI notifications, coverage or lint reporting, build caching, and Docker image
  builds as CI checks: none is required by the roadmap wording ("RSpec +
  frontend tests + build").
- Any change to the delivered core (001/002) or to the local commands.

## Definition of done

- The workflow exists under `.github/workflows/` and a real run on a pull request
  executes the three verifications, all green against the current codebase.
- A temporarily broken test still lets all three verifications run, then turns
  that run red naming the failing one and showing the PR check as failed; the
  breakage is then reverted.
- The required-check protection is verified once: that same red PR cannot be
  merged into `main` (RF-6) and, after reverting, the green PR can.
- No secrets committed (C16); README documents the pipeline (RF-5); each task
  lands as one specific commit (C17).

## Open questions

- None — OQ-1 (execution environment) resolved: CI runs in the project's Docker
  environment with the documented `docker compose` commands (now RF-4; D-14, to
  be recorded by the coordinator). OQ-2 (required check) resolved: the CI check
  is required for merging into `main` (now RF-6), activated as a one-time manual
  repository setting.
