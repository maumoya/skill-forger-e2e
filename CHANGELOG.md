# Changelog

## 0.11.0

- Preflight before Phase 0: itemize the request (one row per sentence or number) and load the owner's standing
  preferences (photo byline, demo card, portfolio section, Marketplace, marketing angle).
- Launch checklist grows from a-h to a-q and is swept three times from fresh evidence: photo byline, dated Results and
  marketing angle, social preview and share unfurl, profile row and portfolio card in the right section, live links,
  rendered read-back, every outward step done by the agent, every request row ticked.
- New ship gates in `readiness.sh --ship`: header carries the owner photo byline, dated Results section, social preview
  set, profile README lists the repo, portfolio site lists the repo (`FORGE_SITE`, default `https://OWNER.github.io/`),
  every README link answers.
- Marketplace by default: a skill whose job fits a CI check ships a self-tested root `action.yml` and is listed from its
  first release (checklist row q); only when none fits is the user told, up front.
- `make_header.sh` tags the photo (`id="byline-photo"`) so the gate can find it.
- "Why steps get missed": six root causes from an audit of ~40 owner corrections, each mapped to the rule that stops it.
- `bench.sh` passes `--scaffold`, so eval cases get their input files (before, such cases scored 0 in both arms).
- `bench.sh` grants the tools the cases list (`allowed_tools`) with `--allow-tools`; the eval sandbox ignored them, so cases that run a script scored 0 in both arms.
- Lint warns on two eval traps that score a case 0 in both arms: a prompt like `/my-skill: do X` (the colon stops the skill loading) and a hook-install case whose scaffold keeps `.git/hooks` (eval sandboxes lock it; use `git init --separate-git-dir`).
- Testing guide: a case that fails in both arms for a sandbox reason (git cannot run, `.git/hooks` locked) gets a self-contained proof command and a grader that accepts it.
- `make_demo.sh` records a local page too (`file:///abs/path/demo.html`).
- New skill repos get a `.gitignore` for `evals/results/`.
- `readiness.sh` and `marketplace_check.sh` on a repo with no release yet say "(none)"; before, they showed GitHub's 404 JSON as the tag name.
- Dependabot groups GitHub Action bumps into one PR (template and this repo). Split bumps of `codeql-action/init` and
  `codeql-action/analyze` failed CodeQL, because the two must be the same version.
- New and retrofitted skill repos get a `CONTRIBUTING.md` (Best Practices asks for it, with a test policy); before,
  `bestpractices.sh` reported two TODO rows on every fresh repo.
- Tag only after the merge landed: a blocked merge plus an early tag points the release at the old code.

## 0.10.0

- The agent does the GitHub work end to end: push, PR, merge, signed tag, release, Marketplace, private reporting,
  ruleset, Best Practices form (to 100% of passing) and About/social preview, in the built-in browser where the owner
  is signed in. The owner keeps sign-ins, passkeys and terms. New "Who does what" section.
- Launch checklist (a-h) in SKILL.md, swept before every status or done report, each row with its proof; with the
  adhd-status skill installed it runs as that skill's sweep.
- `make_demo.sh` + `record_page.mjs`: a <=10 s README demo GIF under 5 MB from a screen recording or a URL
  (headless Chrome screencast).
- New ship gates in `readiness.sh --ship`: header banner, demo video card and result card (were plain checks),
  owner-only authorship (no AI co-author trailer or footer in commits or files), main head signed + Verified +
  authored by the owner, latest release tag signed + Verified.
- Update round rewrites the whole README body, `llms.txt`, description and topics for the new version, not just numbers.
- This repo: README order is banner, badges, demo card, result card.

## 0.9.0

- Update round: `scripts/sync.py` keeps every published number in step with one `launch/facts.json`. It re-renders SVG
  cards and banners from templates, re-runs generators (PNG, GIF) with `--run`, updates fact markers in
  Markdown, lists owner-only places (social preview, About, profile row), and `check` fails on any stale surface or old
  value left by hand, badge URLs included. `--no-outward` for CI.
- `make_header.sh OUT_DIR --png-only` re-renders header.png from an updated header.svg.
- This repo: `launch/` drives the bench card and header; README re-measured (readiness 100/100, retrofit 14 → 66,
  18 files) with both results under one dated Results section; CI runs the sync check.

## 0.8.0

- Ship gates: `readiness.sh . OWNER/REPO --ship` exits 1 unless OpenSSF Scorecard ≥ 7.3, Best Practices is passing,
  private vulnerability reporting is on, and a ruleset on main requires a PR and CodeQL. The Action does the same
  with `ship-gates: true`. Phase 5 is now a hard gate before every release tag.
- `templates/ruleset-main.json`: the "Protect main" ruleset (PR + 1 review, CodeQL required, no force push or delete).
- readiness also checks CodeQL, `permissions: read-all` in every workflow, SHA-pinned actions, one version across
  plugin.json, CHANGELOG, README and llms.txt, an action self-test (or flags "no action.yml = not on the Marketplace"),
  benefit badges in % instead of raw sizes, and a hero result card.
- `marketplace_check.sh` fails without a CI self-test (a passing `uses: ./` run and one asserted as failure) and on
  version drift. Packaging notes that Update release triggers GitHub sudo (passkey): owner OK first.
- `scorecard.sh`: ship bar line, ruleset and private-reporting fixes, and a short live "OpenSSF" profile badge.
- Launch: results as percentages, a big green SVG hero card, profile row and portfolio site updated in the same pass.
- This repo: CI self-tests the Action on a failing repo; README leads with the measured bench card (47% vs 0%).

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
