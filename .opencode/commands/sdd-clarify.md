---
description: SDD · Review the spec as QA (detect only, do not solve)
agent: reviewer
---
Review specs/$1/spec.md as if you were a very professional QA. Use the sdd skill and
read docs/constitution.md. Do not modify any file.

List:
1. Remaining ambiguities (requirements that cannot be verified).
2. Contradictions between requirements.
3. Uncovered edge cases.
4. Conflicts with docs/constitution.md (cite the clause, e.g. C10 or C14).

In particular check that the validation rules are complete and testable, that every
failure maps to the error contract (404/422/500), and that what the UI must mirror
is stated once, unambiguously (C14).

Detect only: do not fix, edit, or solve anything, and never modify any file —
reporting the findings is the whole job; the user decides what happens next.
Output: a numbered list.
