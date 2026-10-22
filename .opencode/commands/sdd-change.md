---
description: SDD · New requirement - spec first, then code (usage: /sdd-change 001-nombre the new need)
agent: planner
---
New requirement for the spec specs/$1/ (the text after the folder name): $ARGUMENTS
DO NOT touch code and DO NOT edit plan.md or tasks.md in this run. Use the sdd skill.

1. Update specs/$1/spec.md first: new RF (or change of an existing one) in EARS, its
   edge cases, and what is now out of scope.
2. Indicate which parts of plan.md and tasks.md would need to change afterwards.
3. Show the user the spec diff and wait for approval; this command ends there — the
   plan and tasks are updated only after the user approves the spec change.

English only.
