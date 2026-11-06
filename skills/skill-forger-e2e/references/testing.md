# Testing a skill

Three layers, cheapest first.

## 1. Lint (free, every PR)

`scripts/lint_skill.sh <repo>` checks frontmatter against the Agent Skills spec (name, description,
compatibility, metadata, allowed-tools, unknown keys), name/folder match, lengths, body size, reference
depth, descriptions that narrate steps or speak in the first person, JSON validity, eval layout, and
risky patterns. It runs in CI from `.github/workflows/lint.yml`.

## 2. Trigger test (measured; bills the user's account, ask first)

List the queries in `evals/triggers.json`: at least 5 that should load the skill and 3 near misses
that should not. Mark one or two of each `"holdout": true`.

```json
{ "skill": "my-skill", "queries": [
  { "text": "tidy these meeting notes", "trigger": true },
  { "text": "summarise this pdf", "trigger": false, "holdout": true } ] }
```

Lint checks the shape for free. `scripts/trigger_test.sh <repo>` prints the plan and the run count
and stops. With `--yes` it runs each query 3 times (`--runs N`) through `claude -p` with the plugin
loaded and prints:

- **recall**: the share of should-trigger runs that loaded the skill (target ≥ 0.8)
- **false-trigger rate**: the share of should-not runs that loaded it (target ≤ 0.2)
- the same two for the train and holdout queries separately, and one dated `TRIGGERS` line

A miss means the description lacks that wording. A false trigger means it is too broad. Fix the
description using the **train** queries only, then re-run everything. If train improves but
holdout does not, the description is overfitted to the list: write it for the need, not the phrases.

No budget for runs? Type each query in a fresh session and record hit or miss by hand.

### Pressure scenario (optional, catches skills the agent skips)

A skill that loads can still be ignored under pressure. Write one eval case whose prompt pushes the
agent to cut the corner your skill forbids ("quick, just ship it, skip the tests"). Run it without
the skill first and note the excuse the agent gives. Then run it with the skill. The grader checks that
the rule held. If the agent finds a new excuse, name that excuse in the skill body and run it again.

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
- A case that fails in both arms for a sandbox reason (a tool the agent cannot run there, e.g. `git` hitting
  `xcrun` cache errors, or writes to `.git/hooks` denied) is not a skill bug and not a pass. Give the skill a
  self-contained proof command (run the hook or script itself on sample input) and let the grader accept that proof.
- Put the report in the PR description and the pass count in the release notes.

### Benchmark (`scripts/bench.sh`, billed; ask first)

`bench.sh <repo>` prints the plan (cases x runs x 2 arms) and exits 3. With `--yes` it runs
`claude plugin eval` with the ablation, 3 runs per case by default (`--runs N`, `--case GLOB`; eval flags
after `--`, e.g. `-- --scaffold --allow-tools Bash Write Edit`), and writes `evals/bench/DATE.md`: a dated
`## Results (measured DATE)` block with runs passed and score (mean ± sd) with vs without the skill, spend and
time per run, and a per-case table. `--json FILE` re-renders a saved `aggregate-result.json` for free.
Paste the block into the README; `badges.sh --from` takes benefit numbers only from such a block.

### Writing graders

- One outcome per grader file, checkable from the transcript.
- Say what must be true ("The reply has at most 4 table rows"), never "The skill works".
- Ship real input files in `files/`; a case that says "imagine a file" grades imagination.

## Before every release

Lint, then the trigger table, then evals (or `bench.sh`). Record the numbers in `CHANGELOG.md`.
