---
description: SDD · Implement ONE task, tests first (usage: /sdd-implement 001-nombre T1)
agent: implementer
---
Implement ONLY task $2 of specs/$1/tasks.md, following specs/$1/plan.md,
docs/constitution.md, AGENTS.md and the sdd skill.

1. Check `git status` first. If there are uncommitted changes that do not belong to
   this task, STOP and report them: never reset, clean, or overwrite existing work.
2. Write the relevant tests first and verify they fail. RSpec is mandatory for the
   backend; run frontend tests only if a real frontend suite is configured.
3. Write the code until they pass — the simplest code that satisfies the task (C5),
   within the binding stack (C8); no new or optional dependency on your own
   initiative (C6).
4. Run the binding verification from MEMORY.md → Development commands and show the
   results: `docker compose exec backend bundle exec rspec`, plus the frontend
   command only if that suite exists.
5. Review the diff of the implementation and its tests.
6. Only when the task's criteria are satisfied and the relevant validations passed,
   mark $2 as done in tasks.md and state which RFs it covers. Never mark a task done
   with failing or unrun validations.
7. Review the full diff, confirm it only contains changes from this task, run the
   final validations once more, stage only the files belonging to this task, and
   create a single task-specific commit (C17) with all of them — implementation,
   tests, and the tasks.md update.
8. If any validation fails, the diff includes foreign changes, or you are unsure what
   belongs to the task, STOP without creating the commit and explain the problem.

Then STOP. Do not start the next task. If the task needs something not covered by the
spec/plan (a new dependency, an extra feature, a different API contract), STOP and
report it (SDD gate).
