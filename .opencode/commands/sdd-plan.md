---
description: SDD · Generate the technical plan of an approved spec
agent: planner
---
First check the status line of specs/$1/spec.md: it must be `approved` (set after the
user's review). If the spec is missing or still `draft`, STOP and report it — a plan
is generated only from an approved spec (C1).

Then read docs/constitution.md, AGENTS.md, MEMORY.md and specs/$1/spec.md. Use the sdd
skill. DO NOT write code.

Generate specs/$1/plan.md with: files created/modified and each one's responsibility,
API surface (endpoints, params, response shapes) when the spec requires it, algorithm
in pseudocode where it actually helps, test strategy with RSpec (backend) and, only if
the spec includes frontend tests, that suite (binding commands in MEMORY.md →
Development commands), and technical decisions justified with the discarded alternative.

Keep the design as simple as the RFs allow (C5); add a dependency only if it makes the
implementation shorter or safer, and say so explicitly (C6). Every part must map to
RFs; state which RF each part covers. Flag any step that needs a decision recorded in
MEMORY.md before coding (C2, C8). English only.

Leave `Status: draft` in plan.md. Then show the plan summary and its relevant technical
decisions, and STOP: wait for the user's explicit review and approval before anything
else. Do not generate tasks and do not write code in this run.
