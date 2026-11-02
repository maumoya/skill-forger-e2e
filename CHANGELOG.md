# Changelog

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
