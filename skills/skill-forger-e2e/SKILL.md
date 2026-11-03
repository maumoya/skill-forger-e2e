---
name: skill-forger-e2e
description: ForgeSkill - ship an agent skill end to end, from idea to an installable, secured, launched Claude Code plugin repo. Writing and evals hand off to skill-creator; this skill owns the rest - scaffold, lint, a 0-100 readiness score, retrofit of an existing repo, a live install test from GitHub, security workflows and launch. Use when the user says "ForgeSkill", "forge skill", "forge a skill", "skill forger", "new skill", "make a skill", "create a skill", "build a skill", "ship my skill", "publish my skill", "release my skill", "share my skill", "package my skill as a plugin", "turn my prompt into a plugin", "is my skill ready", "readiness score", "retrofit my skill repo", "test the install", "add a header image and badges", "improve my Scorecard", "OpenSSF best practices badge", "add about the author", "skill end to end", "is this skill safe to install", "scan a skill for prompt injection", or says "I want people to install my skill", "how do I publish a skill", or asks what step comes next for a skill.
license: MIT
---

# Skill Forger E2E

Eight phases. Each has a gate. Do not start a phase until the previous gate passes.
Tell the user which phase you are in and what passes its gate, in one line.

Write it with a writing tool, ship it with this one. Phases 2-3 hand off to the best authoring and eval tools;
Phases 4-7 are this skill's own work and scripts.

**Already have a skill?** Skip to Phase 4: run `scripts/readiness.sh <repo-dir> [OWNER/REPO]` for the score and the gaps,
then `scripts/retrofit.sh <repo-dir> "<Owner Name>" <github-user>` to add what is missing (it never overwrites).

Paths below are relative to this skill's folder (`skills/skill-forger-e2e/`).

## Phase 0 · Decide (is a skill the right thing?)

A skill is right when the job repeats, needs know-how the model does not have by default, and fits in instructions plus small scripts.
Not a skill: a one-off task (just do it), a fact (put it in CLAUDE.md), a long-running service (build an MCP server), a hard rule that must always fire (use a hook).

Search before building: `npx skills find <words>`, GitHub search `<words> SKILL.md`, the anthropics/skills repo, the awesome-claude-skills lists.
If one exists and is good, install it instead. If it exists and is weak, say what yours does better in one sentence.

**Gate 0:** one sentence: "This skill helps WHO do WHAT, better than WHAT EXISTS because WHY."

## Phase 1 · Define

Write down, before any SKILL.md:
- **Job:** the input the user gives and the output they get.
- **Triggers:** 5–10 phrases a real user types. Include the slash name. Add 3 phrases that must NOT trigger it.
- **Done when:** 2–4 checkable outcomes. These become the eval graders in Phase 3.
- **Baseline:** run the job once with no skill and save what the model did. This is what the skill must beat.

**Gate 1:** job, triggers, non-triggers, done-when and a saved baseline exist.

## Phase 2 · Author (hand off the writing)

Scaffold the repo first: `scripts/new_skill.sh <skill-name> <target-dir> "<Owner Name>" [github-user]`. It copies `templates/repo/` and fills the names.
Then write the SKILL.md body with a dedicated authoring tool when one is installed:
Anthropic's `skill-creator` (interview, draft, description tuning), or superpowers `writing-skills` (test-first). Without one, follow the rules below.
Rules (full list in `references/authoring.md`):
- `name`: lowercase letters, digits, hyphens; ≤64 chars; equals the folder name.
- `description`: ≤1024 chars, third person, says what AND when, holds the trigger phrases. It is the only part the model sees before choosing the skill.
- Body under 500 lines. Imperative steps. Move detail to `references/*.md` (read on demand) and repeatable work to `scripts/` (run, not read).
- No secrets, no absolute home paths, no instructions to fetch and run remote code.

**Gate 2:** `scripts/lint_skill.sh <repo-dir>` prints `PASS`.

## Phase 3 · Test

Details: `references/testing.md`. When `skill-creator` is installed, use its eval loop (with/without runs, blind comparison,
description optimizer) and come back here for the gate. SkillForge adds regression evals if the user wants them.
1. **Trigger test:** put the triggers and near misses in `evals/triggers.json` (mark a few `"holdout": true`). `scripts/trigger_test.sh <repo>` prints the run count; ask first, then add `--yes`. Fix the description on the train queries until recall ≥ 0.8 and the false-trigger rate ≤ 0.2, and check that holdout holds too.
2. **Evals:** one `evals/<case>/` per done-when (case.yaml + prompt.md + graders/). Each case ships its own input files.
3. **Run:** `scripts/bench.sh <repo-dir>` prints the run count; ask first (it bills the user's account), then add `--yes`. It runs `claude plugin eval` with and without the skill and writes a dated Results block (`evals/bench/DATE.md`). Keep it.
4. **Keyless CI:** the linter runs in GitHub Actions on every PR.

**Gate 3:** every case passes with the skill and the skill beats the baseline on at least one. If not, back to Phase 2.

## Phase 4 · Package

Details: `references/packaging.md`.
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (the scaffold made them).
- Install paths to document: `/plugin marketplace add OWNER/REPO` then `/plugin install NAME@NAME`, and `npx skills add OWNER/REPO`.
- Semantic version in plugin.json; `CHANGELOG.md`; signed git tag `vX.Y.Z` per release (SSH key, set up once).
- After each release, refresh every published number: README Results and badges, release notes, About.
- Live install test, after pushing: `scripts/install_test.sh OWNER/REPO`. It installs from GitHub into a throwaway config
  (yours is untouched) and prints the component inventory and token cost. Free.
- Trigger check: add `--trigger "<a phrase a user types>"`. One short `claude -p` run on the user's account: ask first.
- Second path: `scripts/install_test.sh OWNER/REPO --npx` installs with a pinned `npx skills add` into a throwaway HOME
  and lints the installed copy. Free. `--agent codex` (or another agent) tests that agent's folder.

**Gate 4:** `install_test.sh` prints `RESULT n passed, 0 failed` twice: once with a passing `--trigger` check, once with `--npx`.

## Phase 5 · Secure

Details: `references/security.md`. Templates are in `templates/repo/.github/`.
- Workflows: lint, OpenSSF Scorecard, CodeQL (`actions`), Dependabot for actions, SLSA-signed release.
- Every action pinned to a full commit SHA; `permissions: read-all` at the top.
- `SECURITY.md` with a private reporting path. Branch protection on main.
- Review every script the skill runs: no network writes, no piping downloads into a shell, no secret reads.
- Scorecard feedback: `scripts/scorecard.sh OWNER/REPO` lists every check below 10, fixable ones first, with the fix.
  Fix the top one, re-run after the next scan, report the score delta.
- Best Practices: `scripts/bestpractices.sh OWNER/REPO <repo-dir>` says if the project is registered (ID, level, badge).
  If not, it prints the form link and an evidence sheet (each passing criterion and the URL proving it).
  The owner signs in and submits the form; you prepare the answers. Never answer Met without the evidence.

**Gate 5:** Scorecard has run, CodeQL is green, a signed release exists, Best Practices is registered or its evidence sheet has no TODO.

## Phase 6 · Launch

Details: `references/launch.md`. Every post, form or PR to another repo is an outward action: ask the user first.
- README order: picture or ≤10 s GIF, one-line promise, two install commands, one example, FAQ.
- Header image: `scripts/make_header.sh assets --repo OWNER/REPO --head "Line one." --head2 "Line two." --chip … --line '$ cmd' --line '✓ result'`
  (`--image shot.png` for an app; `--photo me.png --by "Name" --handle "@you"` for a byline). Writes a 1280×640 SVG and,
  with Chrome, a PNG that doubles as the social preview. If the project already has good art (an Open Graph image), use that.
  Read the PNG back and fix any overflow before committing.
- Badge row under it, centered: `scripts/badges.sh OWNER/REPO --readiness N` prints it from live data (Claude Code, license,
  OSI, privacy, Scorecard once scanned, Best Practices once registered).
- Benefit badges are the most clicked: the main measured win, e.g. `--benefit 'runs passed=+50 pts' --results '#results-measured-DATE' --from README.md`; badges.sh refuses numbers that are not in the dated Results block.
  Only numbers from a run you can repeat (eval, bench, before/after score), shown in a dated `## Results` section with the method.
- About the author: `scripts/owner_profile.sh GH_USER PROJECT --name "Full Name"` drafts it from the public GitHub profile
  (bio, LinkedIn, other repos) and prints interview questions for the rest. Ask them, show the owner the final text,
  publish only what they approve. It prints only; nothing is saved. Add `--photo` and `--by` to the header for a byline.
- Repo description ≤350 chars opening with what + who; ≤20 topics; homepage (GitHub Pages) with Open Graph tags; `llms.txt`.
- Repo ships an `action.yml`? List it on the GitHub Marketplace from a release. Run `scripts/marketplace_check.sh . OWNER/REPO`
  **before tagging** (the Marketplace reads `action.yml` from the tag; a late fix costs a patch release), then follow the
  11 steps in `references/packaging.md`. The owner clicks Update release and accepts the agreement; finish with `--listed`.
- Channels in order: Anthropic plugin directory form, skills.sh, awesome lists (each on its own rules), the niche community, then an essay that teaches something and links the repo.

**Gate 6:** README passes the 10-second test (a stranger can say what it does and how to install it) and one channel submission is done.

## Phase 7 · Loop

Run `scripts/readiness.sh <repo-dir> OWNER/REPO` (ship score), `scripts/scorecard.sh OWNER/REPO` (security fixes)
and `scripts/measure.sh OWNER/REPO [BEST_PRACTICES_ID]` (traffic, stars).
Pick the one highest-impact gap. Fix it on a branch with a PR. Re-measure after merge. Report the delta in one row.
Re-run Phase 3 evals before every release. For CI, the repo root `action.yml` runs the linter and the score on every PR
(`uses: maumoya/skill-forger-e2e@<commit-sha>`, with `min-score` to fail below a bar); see `references/packaging.md`.

## Honesty rules

- Never claim a phase passed without running its check. Show the output.
- Stars and installs cannot be promised. Badges show live measurements only.
- No bought stars, star swaps, fake reviews, or the same link posted in many places.
- The user merges PRs and submits forms. You prepare them.
