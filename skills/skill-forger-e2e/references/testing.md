# Testing a skill

Three layers, cheapest first.

## 1. Lint (free, every PR)

`scripts/lint_skill.sh <repo>` checks frontmatter against the Agent Skills spec (name, description,
compatibility, metadata, allowed-tools, unknown keys), name/folder match, lengths, body size, reference
depth, descriptions that narrate steps or speak in the first person, JSON validity, eval layout, and
risky patterns. It runs in CI from `.github/workflows/lint.yml`.

## 2. Trigger test (free, manual, 5 minutes)

In a fresh session with the skill installed, type each trigger phrase and each non-trigger.

| Phrase | Should fire? | Fired? |
|---|---|---|
| "make a skill for X" | yes | |
| "what is a skill" | no | |

A miss means the description lacks that wording. A misfire means it is too broad. Fix the
description only, then re-run the whole table.

## 3. Evals with `claude plugin eval` (bills the user's account; ask first)

One case per promise in the README and in "Done when".

```
evals/<case>/
  case.yaml          schema_version "1.1", name, expected_outcome, optional context.scaffold_script
  prompt.md          frontmatter (tags, max_turns, timeout_seconds, allowed_tools) + the user's message
  graders/01-*.md    frontmatter (type: llm, focus: trace, weight) + one checkable sentence
  files/             optional input files the case needs
  place-files.sh     optional: cp -R "$(dirname "$0")/files/." .
```

Run `claude plugin eval <repo> --allow-tools`. It runs every case with the skill and without it
(the ablation). Read the report:

- A case that passes **without** the skill tests nothing the skill adds. Make it harder or drop it.
- A case that fails **with** the skill is a bug in SKILL.md, or a grader asking for something the
  skill never promised.
- Put the report in the PR description and the pass count in the release notes.

### Writing graders

- One outcome per grader file, checkable from the transcript.
- Say what must be true ("The reply has at most 4 table rows"), never "The skill works".
- Ship real input files in `files/`; a case that says "imagine a file" grades imagination.

## Before every release

Lint, then the trigger table, then evals. Record the numbers in `CHANGELOG.md`.
