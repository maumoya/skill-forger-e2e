---
name: skill-forger-e2e
description: ForgeSkill - ship an agent skill end to end, from idea to an installable, secured, launched Claude Code plugin repo. Writing and evals hand off to skill-creator; this skill owns the rest - scaffold, lint, a 0-100 readiness score, retrofit of an existing repo, a live install test from GitHub, security workflows and launch. Use when the user says "ForgeSkill", "forge skill", "forge a skill", "skill forger", "new skill", "make a skill", "create a skill", "build a skill", "ship my skill", "publish my skill", "release my skill", "share my skill", "package my skill as a plugin", "turn my prompt into a plugin", "is my skill ready", "readiness score", "retrofit my skill repo", "test the install", "add a header image and badges", "improve my Scorecard", "OpenSSF best practices badge", "add about the author", "skill end to end", "is this skill safe to install", "scan a skill for prompt injection", or says "I want people to install my skill", "how do I publish a skill", or asks what step comes next for a skill.
license: MIT
---

# Skill Forger E2E

Eight phases. Each has a gate. Do not start a phase until the previous gate passes.
Tell the user which phase you are in and what passes its gate, in one line.
You do the GitHub work yourself, end to end: push, open PRs, merge, tag, release, Marketplace, settings, forms
(see "Who does what"). Every release ends with the Launch checklist, swept row by row.

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
  Bump plugin.json, CHANGELOG, the README `@vX.Y.Z` example and the `llms.txt` line in one PR (readiness checks they agree).
- No root `action.yml` = not on the GitHub Marketplace. Say so to the user now, not at launch; if a CI check fits
  the skill, design a real one (see Phase 6).
- After each change, run the update round: every number lives once in `launch/facts.json`, every surface that shows
  one is listed in `launch/assets.json` (SVG templates, generator commands, owner-only places), and Markdown numbers sit
  in fact markers (format in the header of `scripts/sync.py`). `scripts/sync.py apply . --run` re-renders and regenerates; `sync.py check .`
  must print "in sync" (CI runs it with `--no-outward`). Outward items (social preview, About, profile row) you update
  yourself in the built-in browser, then `sync.py done . "<name>"`. Details: `references/launch.md`.
- Same round, rewrite the whole README body, not just the numbers: re-read SKILL.md, CHANGELOG and the scripts, then
  update the promise, feature list, install lines, examples, Results, FAQ, `llms.txt`, the repo description and topics
  so each one describes the current version. A feature in the new CHANGELOG entry that the README does not mention is a miss.
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
- `SECURITY.md` with a private reporting path, and that path turned on (you run it):
  `gh api -X PUT repos/OWNER/REPO/private-vulnerability-reporting`.
- A ruleset on main that requires a PR and CodeQL (you run it, after telling the owner it is a settings change):
  `gh api -X POST repos/OWNER/REPO/rulesets --input templates/ruleset-main.json`.
- Review every script the skill runs: no network writes, no piping downloads into a shell, no secret reads.
- Scorecard feedback: `scripts/scorecard.sh OWNER/REPO` lists every check below 10, fixable ones first, with the fix.
  Fix the top one, re-run after the next scan, report the score delta. Keep looping until Scorecard reads ≥ 7.4
  (7.3 is the release floor, not the goal); stop only when every remaining check needs other people.
- Best Practices: `scripts/bestpractices.sh OWNER/REPO <repo-dir>` says if the project is registered (ID, level, badge).
  If not, it prints the form link and an evidence sheet (each passing criterion and the URL proving it).
  Fill the form yourself in the built-in browser (the owner is signed in; if not, they sign in, never you), answer every
  criterion with its evidence URL and save each section. Never answer Met without the evidence.
  Done means passing at 100%: re-read the project page, then add the badge to the README.

**Gate 5 (hard, blocks every release):** `scripts/readiness.sh . OWNER/REPO --ship` exits 0. Its GATE rows:
header banner, demo video card, hero result card, owner-only authorship, Scorecard ≥ 7.3, Best Practices passing,
private vulnerability reporting on, ruleset with PR + CodeQL, main head and latest release tag signed and Verified. CodeQL is green
and a signed SLSA release exists. Below 7.3, `scorecard.sh` lists the fixes (these took a repo from 6.6 to 7.4: ruleset,
CodeQL + Scorecard workflows, SHA pins, `permissions: read-all`, signed release, reporting on, Best Practices passing).

## Phase 6 · Launch

Details: `references/launch.md`. Every post, form or PR to another repo is an outward action: ask the user first.
GitHub-side updates (social preview upload, About/description/topics, Best Practices form, profile and site PRs):
do them yourself in the built-in browser, where the owner is signed in, instead of handing them over. Approvals and
sign-ins stay the owner's.
- README order, every repo, every release: header banner, badge row, ≤10 s demo video card (GIF; the same clip as the
  portfolio site), big green result card, one-line promise, two install commands, one example, FAQ.
- Demo video card: `scripts/make_demo.sh INPUT assets/demo.gif [--seconds 8] [--width 720]`. INPUT is a screen
  recording (mp4, mov, webm) or a URL (a live page or a local dev server, recorded with headless Chrome). It keeps
  the GIF ≤10 s and under 5 MB. Put it under the badge row; use the same file on the portfolio site.
- Header image: `scripts/make_header.sh assets --repo OWNER/REPO --head "Line one." --head2 "Line two." --chip … --line '$ cmd' --line '✓ result'`
  (`--image shot.png` for an app; `--photo me.png --by "Name" --handle "@you"` for a byline). Writes a 1280×640 SVG and,
  with Chrome, a PNG that doubles as the social preview. If the project already has good art (an Open Graph image), use that.
  Read the PNG back and fix any overflow before committing.
- Badge row under it, centered: `scripts/badges.sh OWNER/REPO --readiness N` prints it from live data (Claude Code, license,
  OSI, privacy, Scorecard once scanned, Best Practices once registered).
- Benefit badges are the most clicked: the main measured win, e.g. `--benefit 'runs passed=+50 pts' --results '#results-measured-DATE' --from README.md`; badges.sh refuses numbers that are not in the dated Results block.
  Only numbers from a run you can repeat (eval, bench, before/after score), shown in a dated `## Results` section with the method.
- Say results as percentages, never raw sizes: "19% of the disk freed (6% → 25% free), 100% of deletes approved",
  not "86 GiB". Put the hero result in a big green SVG card under the badge row (`assets/*-card.svg`, linked to Results).
- Same pass: update the owner's profile row and portfolio site with the new numbers. In profile tables use the short
  live badge `scorecard.sh` prints as "Profile badge" (reads "OpenSSF 7.4"), never the tiny default Scorecard badge.
- About the author: `scripts/owner_profile.sh GH_USER PROJECT --name "Full Name"` drafts it from the public GitHub profile
  (bio, LinkedIn, other repos) and prints interview questions for the rest. Ask them, show the owner the final text,
  publish only what they approve. It prints only; nothing is saved. Add `--photo` and `--by` to the header for a byline.
- Repo description ≤350 chars opening with what + who; ≤20 topics; homepage (GitHub Pages) with Open Graph tags; `llms.txt`.
- Repo ships an `action.yml`? List it on the GitHub Marketplace from a release. Run `scripts/marketplace_check.sh . OWNER/REPO`
  **before tagging** (the Marketplace reads `action.yml` from the tag; a late fix costs a patch release), then follow the
  11 steps in `references/packaging.md`: you tick the box and click Update release in the built-in browser; a passkey
  prompt is the owner's, and so is accepting the agreement (first listing only); finish with `--listed`. CI must self-test the action: one passing `uses: ./` run and one
  failing run asserted as failure (`marketplace_check.sh` fails without it).
- Channels in order: Anthropic plugin directory form, skills.sh, awesome lists (each on its own rules), the niche community, then an essay that teaches something and links the repo.

**Gate 6:** `readiness.sh --ship` still exits 0 on the tagged release, the README shows the banner, the demo video card
and the result card, `marketplace_check.sh . OWNER/REPO --listed`
prints PASS when there is an `action.yml`, README passes the 10-second test (a stranger can say what it does and how
to install it), and one channel submission is done.

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
- Owner-only authorship: commits, tags and releases carry the owner's name only. Never write an AI co-author
  trailer or an AI "generated with" footer anywhere; `readiness.sh` fails the authorship gate if one exists.
- "Verified" means the GitHub check mark on the signed head commit and release tag. The Marketplace's blue verified-creator
  badge is only for organizations GitHub partners with: never promise it.

## Who does what

You (in the shell or the built-in browser, where the owner is signed in): commit as the owner's git identity, push,
open the PR, wait for CI, merge (after the owner's OK for that merge, if the session needs one), sign and push the tag,
edit the release, publish to the Marketplace, turn on reporting, add the ruleset, fill the Best Practices form,
update the About box, topics, social preview, profile and portfolio rows.
The owner: signs in, completes passkey or 2FA prompts, accepts terms, and approves posts to other people's spaces.
Never create accounts or type passwords.

## Launch checklist (every release)

Before any status or done report, sweep these rows. If the `adhd-status` skill is installed, invoke it and use this
list as its sweep: each row is ✅ only with the proof output in hand, otherwise it is a 👉 or ⚠️ row.

| Row | Proof |
|---|---|
| a. Pushed, PR merged, tag and release out, all by you | `gh pr view N --json state` = MERGED; `gh release view vX.Y.Z` |
| b. Header banner on top | GATE "README has a header banner" |
| c. Whole README body, `llms.txt`, description match this version | every new CHANGELOG feature named in the README |
| d. Demo video card and big green result card | GATEs "demo video card" and "hero result card"; `sync.py check .` in sync |
| e. Best Practices passing at 100% | GATE "Best Practices passing" |
| f. Scorecard ≥ 7.3, looping to ≥ 7.4 | GATE "Scorecard"; `scorecard.sh` lists what is left |
| g. Verified | GATEs "head signed, Verified" and "release tag signed and Verified"; `marketplace_check.sh --listed` PASS |
| h. Owner-only authorship | GATE "owner-only authorship" |

Rows a–h together: `readiness.sh . OWNER/REPO --ship` exits 0, plus the a and c checks. Any row not met means the
release is not done: say which, and fix it before reporting.
