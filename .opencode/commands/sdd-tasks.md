---
description: SDD · Split the plan into small, verifiable tasks
agent: planner
---
First confirm BOTH approvals; if either is missing, STOP and say exactly what is
missing — never infer an approval:
- specs/$1/spec.md exists and is `approved` (its status line, set after the user's
  review).
- specs/$1/plan.md exists and is `approved` (its `Status:` line, or the user's
  approval recorded in MEMORY.md).

Then, from specs/$1/spec.md and specs/$1/plan.md, generate specs/$1/tasks.md
following the sdd skill format:

- Coherent tasks in dependency order, each a practical unit of work: never one task
  per file or trivial change, never several independent features in one task (C3).
- Each with the RFs it covers and a verifiable "Done when:" line backed by a command
  from MEMORY.md → Development commands.
- Checkboxes.
- Size follows coherence, not a fixed count: if the list suggests the spec mixes
  independent capabilities, propose a split instead of forcing tasks.

English only. Return the file path and the task count.
