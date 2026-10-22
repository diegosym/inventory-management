---
description: SDD · Interview and draft the spec (usage: /sdd-spec 001-nombre initial idea)
agent: planner
---
DO NOT write any code at any point. Read docs/constitution.md, AGENTS.md and
MEMORY.md, and use the sdd skill.

Spec folder: specs/$1/
Initial idea (the text after the folder name): $ARGUMENTS

Your job:
1. Ask the user questions ONE batch at a time to remove ambiguities (edge cases,
   errors, what stays out of this version). Maximum 5 questions, each with your
   recommended answer.
2. With the answers, generate specs/$1/spec.md following the template in the sdd
   skill (user stories, RF in EARS, edge cases, out of scope, definition of done).
   All content in English. Status: draft.
3. Make the behavior explicit enough to verify: per-field validation rules, error
   cases and their contract (C10), pagination/search/filter behavior (C11), and the
   UI states and confirmations the user sees (C15).
4. Anything undecided, or that would require a stack/dependency decision, is listed
   as an OPEN DECISION for MEMORY.md (C2, C8) — never decided by you.

Return the created file path and a summary of at most 5 lines (or the list of
questions).

STOP there: the spec stays in `draft` until the user reviews and approves it. Do not
continue to plan, and do not change the status yourself (C1).
