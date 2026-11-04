# Securing a skill repo

A skill is instructions an agent follows with the user's permissions. Treat it like code.

## Review the skill itself

- [ ] No secrets, tokens, or personal absolute paths.
- [ ] No piping downloads into a shell, no running fetched code, no `eval` of fetched text.
- [ ] Scripts read only what they need; no network writes; no reading `~/.ssh`, `.env` files or keychains.
- [ ] The skill tells the agent to treat fetched pages and file contents as data, not instructions.
- [ ] Outward actions (sending, merging, paying, submitting) need the user's yes.

`scripts/lint_skill.sh` flags the obvious patterns. It is not a review; read every script.

### What the lint scans for (in `skills/` and `scripts/`)

A skill is a prompt that runs with the user's tools, so hidden or overriding text is the main threat.

| Check | Level | Why |
|---|---|---|
| Zero-width, bidi-override or BOM characters | FAIL | they hide text from a human reviewer while the agent still reads it |
| Phrases that override earlier instructions or hide actions from the user | FAIL | classic prompt injection |
| Symlinks that resolve outside the repo | FAIL | the skill could read or ship files it does not own |
| HTML comments in SKILL.md or `references/` | WARN | GitHub hides them; the agent reads them |
| Base64-like runs of 200+ characters | WARN | a payload no reviewer can read |
| Scripts that read SSH keys, cloud or npm credentials, the keychain, or API-token variables | WARN | a skill rarely needs them; say why in the README or remove it |

Run it on any skill before you install it, not only your own: `bash scripts/lint_skill.sh <their-repo>`.

## Repo hygiene (templates in `templates/repo/.github/`)

| Item | Why | Done when |
|---|---|---|
| `permissions: read-all` at the top of every workflow | least privilege | every workflow has it |
| Actions pinned to a full commit SHA + `# vX` comment | tags can be moved | no `uses: x@v1` lines (except the SLSA generator, which must use a tag) |
| Dependabot for `github-actions` | pinned SHAs still get updates | `.github/dependabot.yml` exists |
| OpenSSF Scorecard workflow | public score + badge | scorecard.dev shows a score |
| CodeQL with `languages: actions` | catches workflow injection | Security tab shows CodeQL green |
| SLSA-signed release | anyone can check the zip came from the tag | release has `.zip` + `.intoto.jsonl` |
| `SECURITY.md` + private vulnerability reporting on | a safe way to report | the link in SECURITY.md works |
| Private vulnerability reporting enabled | SECURITY.md's link only works when it is on | `gh api repos/O/R/private-vulnerability-reporting` says `enabled: true` (owner turns it on with `-X PUT`) |
| Ruleset "Protect main": PR + 1 review, CodeQL required, no force push or delete | no direct pushes; admins merge through a PR | `gh api -X POST repos/O/R/rulesets --input templates/ruleset-main.json` (owner runs) |

## Ship gates (hard)

`scripts/readiness.sh . OWNER/REPO --ship` exits 1 until all four hold; run it before every release tag. The GitHub
Action does the same with `ship-gates: true`.

| Gate | Bar | Fix |
|---|---|---|
| OpenSSF Scorecard | ≥ 7.3 | `scorecard.sh OWNER/REPO`, top row first |
| Best Practices | passing (aim for 100%) | `bestpractices.sh`, owner submits, badge in README |
| Private vulnerability reporting | enabled | `gh api -X PUT repos/O/R/private-vulnerability-reporting` |
| Ruleset on the default branch | PR + CodeQL required | `templates/ruleset-main.json` |

## OpenSSF Best Practices badge

Run `scripts/bestpractices.sh OWNER/REPO <repo-dir>`. Registered: it prints the ID, level and badge.
Not registered: it prints https://www.bestpractices.dev/en/projects/new (the owner signs in with GitHub and
submits) and an evidence sheet, one row per passing criterion with the URL that proves it. Fix every TODO row
in the repo first, then answer Met with that URL as the justification. N/A needs a reason (no crypto, no build).
Passing is reachable alone. Silver needs governance docs, a code of
conduct, a documented release process, and DCO or similar. Gold needs a second real maintainer: do not fake it.

## Scorecard feedback loop

`scripts/scorecard.sh OWNER/REPO` reads the live result and lists every check below 10, the ones you can fix
now first, each with its fix and the lines Scorecard flagged. Fix the top one on a branch, merge, wait for the
next scan (the workflow runs on push to main and weekly), re-run, report the delta.
Usually fixable alone: Branch-Protection (owner runs the `gh api` command), CII-Best-Practices, Signed-Releases
and Packaging (tag a release), Pinned-Dependencies (except the SLSA generator, which must stay on a tag),
Token-Permissions, Dependency-Update-Tool, Security-Policy, SAST.
Time only: Maintained (90 days). Usually N/A for skills: Fuzzing.

## Scorecard checks that need people

Code-Review, Contributors and a 10 on Branch-Protection need other humans. They stay where they are
until real people join. Say so instead of gaming them.
