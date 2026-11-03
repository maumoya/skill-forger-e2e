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
- Requirements: public repo, exactly one `action.yml` at the root, a `name` no other Marketplace action, user,
  org or category uses (search the Marketplace first), plus `description`, `author` and `branding` (icon, color).
- Publishing happens on a release, in the web UI only: open the release (the release workflow made it) → Edit →
  tick "Publish this Action to the GitHub Marketplace" → pick a primary and secondary category → Update release.
- First time only: the owner accepts the GitHub Marketplace Developer Agreement (needs 2FA). That is accepting terms:
  the owner does it, you never do. Prepare the name check and categories, then hand over the click.
- Listing updates with each later release that has the box ticked. Check it at `https://github.com/marketplace/actions/<slug>`.

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
