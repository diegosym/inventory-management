---
description: SDD · Validate the spec RF by RF (usage: /sdd-validate 001-nombre)
agent: reviewer
---
Walk through specs/$1/spec.md requirement by requirement. For each RF, name the test
that covers it and the result of running it with the binding commands in MEMORY.md →
Development commands (`docker compose exec backend bundle exec rspec` for the backend;
the frontend command only if a real frontend suite is configured). Read specs/$1/tasks.md
and the implementation files. Use git only after verifying
`git rev-parse --show-toplevel` is the project root.

Report only results you actually executed in this run: a test you did not run is
"not verified", never "passing".

If some RF has no covering test or fails, say so clearly. Check the definition of done
in spec.md and the constitution compliance checklist (docs/constitution.md), with
special attention to: simplest code and justified dependencies (C5, C6), validations
in the model (C9), error contract (C10), server-side pagination/search (C11), and the
frontend mirror rule and states (C14, C15). Do NOT fix anything yet.

Start your answer with exactly one of these lines:
- VEREDICTO: APROBADO
- VEREDICTO: CAMBIOS NECESARIOS

If changes are needed, a numbered list with: file:line, what it violates (task, RF
or clause) and what is expected. Non-blocking suggestions go separately under
"Optional".
