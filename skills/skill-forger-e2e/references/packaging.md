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

## Versions

- Semantic versioning in `plugin.json`: patch = wording fix, minor = new capability, major = changed triggers or output shape.
- One `CHANGELOG.md` entry per version, with the eval pass count.
- Tag `vX.Y.Z` on main; the release workflow builds the zip and signs provenance.
- Small releases every 1–2 weeks beat one big one: each release is a reason to look again.
