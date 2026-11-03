# Packaging and installing

## Repo layout (what `scripts/new_skill.sh` creates)

```
.claude-plugin/plugin.json        name, version, description, author, license, keywords
.claude-plugin/marketplace.json   makes the repo its own marketplace (one plugin, source "./")
skills/<name>/SKILL.md
evals/<case>/…
scripts/lint_skill.sh
.github/workflows/{lint,scorecard,codeql,release}.yml + dependabot.yml
README.md LICENSE SECURITY.md CHANGELOG.md llms.txt
```

## Install paths to document (both)

Claude Code:
```
/plugin marketplace add OWNER/REPO
/plugin install NAME@NAME
```

Any agent that reads skills (skills.sh):
```
npx skills add OWNER/REPO
```

Manual: copy `skills/<name>/` into `~/.claude/skills/` (personal) or `.claude/skills/` (one project).

## Verify before claiming

1. Push to a public repo.
2. `scripts/install_test.sh OWNER/REPO`: installs from GitHub into a throwaway config and checks the skill landed. Free.
3. `scripts/install_test.sh OWNER/REPO --trigger "<phrase>"`: one billed `claude -p` run; the phrase must load the skill. Ask first.
4. `npx skills add OWNER/REPO` in a scratch folder for the second path. Note what you typed and what happened.

## Readiness score in CI

`scripts/readiness.sh <repo-dir> [OWNER/REPO]` scores 0-100. The repo root `action.yml` wraps lint + score for any repo:
`uses: maumoya/skill-forger-e2e@<full-commit-sha>` with `min-score: 80`. Pin the SHA like every other action.
Outputs `score` and `badge`; the table goes to the job summary.

## GitHub Marketplace (when the repo ships an action)

A root `action.yml` can be listed on the GitHub Marketplace, so people find the CI check there too.
The Marketplace validates `action.yml` **only when you publish, and reads it from the release tag**. A mistake
found then costs a new patch release. So every rule is checked in the PR, before the tag exists.

**Rules** (`lint_skill.sh` fails on each one, so CI catches them):
- Public repo, exactly one `action.yml` (or `action.yaml`) at the root. Action files in subfolders cannot be listed.
- `name`: unique across Marketplace actions, users, orgs and categories. The listing slug is the name in lowercase
  with every run of other characters turned into `-` (`ADHD status reply lint` → `adhd-status-reply-lint`).
- `description`: **under 125 characters**. It is the listing's one-liner, so lead with the job, not the tool.
- Quote any value that contains `: ` (`description: "Check replies: one table"`). Unquoted, that is invalid YAML.
- `branding.icon`: a Feather icon name (`check-circle`, `shield`, `zap`). `branding.color`: one of white, black,
  yellow, blue, green, orange, red, purple, gray-dark.
- `author` (a warning if missing: the listing shows it). `runs.using`: `composite`, `node20` or `docker`.
- Pass inputs to `run:` through `env:`, never `${{ inputs.x }}` inside the script (that is shell injection).

**Steps, in order** (one release per listing update):
1. `scripts/marketplace_check.sh . OWNER/REPO`, before tagging. It runs the rules above, then checks online that the repo
   is public, the name is free (or already yours) and what the latest tag carries. Fix every FAIL first.
2. CI self-tests the action: a job with `uses: ./` on a passing input, and one on a failing input
   (`continue-on-error: true`, then assert `steps.<id>.outcome == 'failure'` and the outputs).
3. PR → CI green → the owner merges. Bump the version (`plugin.json`, CHANGELOG, README `@vX.Y.Z` example) in that PR.
4. Signed tag on the merge commit, `git verify-tag`, the owner pushes it. The release workflow creates the release.
5. Release notes: what changed, a `uses:` example pinned to the new tag, measured numbers, the verify command.
6. Open the release → **Edit** → tick "Publish this Action to the GitHub Marketplace". The page now validates
   `action.yml` from the tag: name, description, icon, color must all show a green check. Any red: stop, fix in a PR,
   new patch release, start again at step 1. Do not move the old tag.
7. Pick a primary and a secondary category (e.g. Code quality, Continuous integration, Testing, AI Assisted).
   Driving the page from a browser tool: the selects are `#action-primary-category` and `#action-secondary-category`;
   set the option value and dispatch `input` and `change` from JavaScript, since form filling does not stick.
8. **Update release** is a publish click: ask the owner first, then click.
9. First listing only: the owner accepts the GitHub Marketplace Developer Agreement (needs 2FA). That is accepting
   terms, so the owner does it, you never do.
10. Prove it: `scripts/marketplace_check.sh . OWNER/REPO --listed` must print `listed:` and PASS. The page is
    `https://github.com/marketplace/actions/<slug>`.
11. Point to it: a README section "Check … in CI (GitHub Action)" with the Marketplace link and a `uses:` example,
    a line in `llms.txt`, and the release notes. Then the usual refresh (see Versions).

Later releases update the listing only when the box is ticked on that release, so repeat steps 6–10 each time.

## Versions

- Semantic versioning in `plugin.json`: patch = wording fix, minor = new capability, major = changed triggers or output shape.
- One `CHANGELOG.md` entry per version, with the eval pass count.
- Tag `vX.Y.Z` on main; the release workflow builds the zip and signs provenance.
- Sign the tag too, set up once before the first release (otherwise GitHub shows the tag as Unverified):
  `ssh-keygen -t ed25519 -f ~/.ssh/git_signing_ed25519 -C "git tag signing"`, then
  `git config --global gpg.format ssh`, `user.signingkey ~/.ssh/git_signing_ed25519.pub`, `tag.gpgSign true`,
  and `gh auth refresh -s admin:ssh_signing_key && gh ssh-key add ~/.ssh/git_signing_ed25519.pub --type signing`.
  Check with `git verify-tag vX.Y.Z` before pushing (it needs `gpg.ssh.allowedSignersFile`).
- Unsigned tag already out: re-sign it in place on the same commit, `git tag -f -s vX.Y.Z <commit> -m "..."`,
  `git verify-tag vX.Y.Z`, `git push -f origin vX.Y.Z`. The release, zip and provenance stay; the release workflow
  re-runs and fails on "release already exists", which is harmless.
- After every release, refresh the whole publication, not just the code: README Results (new dated run, older ones
  kept as history), headline and benefit badges, any "where it stands" table, bench sections, release notes
  (what changed, measured numbers, verify command) and the repo About description. Stale numbers next to a new
  version read as untrue.
- Small releases every 1–2 weeks beat one big one: each release is a reason to look again.
