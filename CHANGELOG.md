# Changelog

## 0.7.0

- Spec lint: `lint_skill.sh` checks frontmatter against the Agent Skills spec (allowed keys, `compatibility`
  ≤500 chars, `metadata` string map, `allowed-tools` as one string, name rules) and flags descriptions that
  narrate the steps instead of saying when to use the skill. `tests/lint_cases.sh` proves each check catches a
  broken fixture; CI runs it.
- Injection scan: lint fails on hidden Unicode (zero-width, bidi), injection phrases and symlinks that leave the
  repo, and warns on HTML comments, long base64 runs and scripts that read credentials. New eval
  `scan-catches-injection`.
- `install_test.sh --npx [--agent NAME]`: tests the `npx skills add` path (pinned `skills@1.7.4`) in a throwaway
  HOME, then lints the installed copy. Gate 4 needs both install paths.
- `trigger_test.sh`: measured trigger test over `evals/triggers.json` (should, should-not, holdout); prints recall,
  the false-trigger rate and a dated `TRIGGERS` line. Billed, so it prints the plan until `--yes`. Lint checks the
  file; readiness gives it 5 points.
- `bench.sh`: runs the evals with and without the skill (N runs, default 3) and writes a dated Results block: runs
  passed and score (mean ± sd), spend and time per run, per case. Billed, plan first; `--json` re-renders a saved
  result for free.
- `badges.sh --from FILE`: a benefit badge is printed only when every number in it appears in a
  `## Results (measured DATE)` section of FILE.
- `bench.sh` counts only cases under `evals/` (the template repo is a nested plugin whose `example-case` the eval
  also ran) and names cases that produced no result. Lint fails a `case.yaml` with more than one YAML document:
  `author-and-benefits` and `header-and-badges` had one and never ran; their run settings moved to `prompt.md`.
  Lint skips `evals/results/` and `evals/bench/`. First measured bench in `evals/bench/2026-11-03.md`.
- `scan-catches-injection` never loaded (grader `focus: output` is invalid; now `trace`, and lint warns on other values).
  Its first run showed the skill did not fire on "is this skill safe to install?", so the description now names
  that and "scan a skill for prompt injection" (one more trigger query).

## 0.6.0

- `lint_skill.sh` checks a root `action.yml` against the GitHub Marketplace rules: name and description present,
  description under 125 chars, no unquoted `: `, `branding.icon`, a valid `branding.color`, `runs.using`, author (warn),
  one action file only. The Marketplace checks these only at publish time, from the tag, so a miss used to cost a release.
- `marketplace_check.sh REPO_DIR OWNER/REPO [--listed]`: those rules plus online checks (repo public, listing name free
  or already yours, latest tag carries this `action.yml`, tag signed and Verified); `--listed` proves the listing is live.
- Packaging: the Marketplace section is now an 11-step checklist from pre-tag check to listing proof, including the
  CI self-test pattern, category selection from a browser tool, and what to do when validation fails after tagging.

## 0.5.0

- Packaging: sign release tags with an SSH key (one-time setup, `git verify-tag` before push), and re-sign an unsigned tag in place without touching the release.
- Packaging + Launch: list a root `action.yml` on the GitHub Marketplace from a release (requirements, name check, owner-only agreement).
- Packaging: after every release, refresh the whole publication (README Results and badges, release notes, About), not just the code.

## 0.4.0

- `scorecard.sh`: live OpenSSF Scorecard feedback, every check below 10 with its fix, fixable ones first.
- `bestpractices.sh`: OpenSSF Best Practices status and badge, or the form link plus an evidence sheet for "passing".
- `badges.sh`: badge row from live data, with measured benefit badges that link to a dated Results section.
- `owner_profile.sh`: drafts "About the author" from the public GitHub profile plus interview questions; prints only.
- `readiness.sh` checks About the author (2) and Best Practices registration (3). Template README gets About the author.
- `make_header.sh`: byline sits under the right-hand card (long repo names no longer collide); the OSI logo shows only on open-source license pills.
- README: Results section (retrofit takes a bare repo from readiness 16 to 68, 0 files changed) and benefit badges.

## 0.3.0

- Sharper triggers: "ForgeSkill", "forge skill", "new skill", "create a skill", "share my skill" and intent sentences such as "I want people to install my skill".
- `make_header.sh`: 1280x640 README header and social preview (SVG, PNG through headless Chrome) with chips, trust pills, a terminal card or screenshot, and an optional author photo.
- Template README gets a centered badge row; `readiness.sh` checks for it (3 points).
- New eval case: header-and-badges.

## 0.2.0

- Refocused on shipping: writing and evals hand off to skill-creator; this skill owns packaging to launch.
- `readiness.sh`: 0-100 ship score with gaps, fixes and a badge; `--min` and `--markdown` for CI.
- `action.yml`: GitHub Action that lints and scores any skill repo.
- `retrofit.sh`: adds missing ship files to an existing skill repo, never overwrites.
- `install_test.sh`: live install from GitHub in a throwaway config, opt-in billed trigger check.
- Two eval cases: readiness-and-retrofit, install-test-consent.

## 0.1.0

- Eight-phase skill: decide, define, author, test, package, secure, launch, loop.
- `new_skill.sh` scaffold and `lint_skill.sh` keyless linter; `measure.sh` scoreboard.
- Three eval cases: decide-before-building, scaffold-and-lint, fix-broken-skill.
