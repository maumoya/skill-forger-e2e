# Launching a skill

Every public message, form submission, or PR to someone else's repo is an outward action: prepare
it, show it, and let the user send it.

## README (the 10-second test)

In this order:
1. A picture or a ≤10 s GIF: one input → one result. Record it from a `vhs` tape kept in the repo so it can be re-made.
   Or a header banner from `scripts/make_header.sh` (1280×640 SVG + PNG; also the social preview), with a centered
   badge row under it: Claude Code skill + plugin, license, OSI open source, privacy, OpenSSF Scorecard, readiness.
   Only badges that show a live or measured fact; Best Practices only after the project is registered.
2. One line: what it does, for whom.
3. Two install commands (`/plugin install` and `npx skills add`).
4. One real example.
5. How it is tested (eval count, CI badge).
6. FAQ with question headings ("Does it send my data anywhere?").

In the 8 biggest skill repos (measured 2026-11): 6 open with a picture, 5 document `npx skills add`.

## Words people search

- Repo description ≤350 chars, opening with what + who.
- H1 and first paragraph use the same words.
- Up to 20 topics: `claude-code`, `claude-skill`, `agent-skills`, plus the job's own words.
- Light and dark header via `<picture>`; 1280×640 social preview uploaded in repo settings.

## AI discovery

- `llms.txt` at the root (what it is, install, links to SKILL.md and README).
- GitHub Pages homepage with Open Graph tags, set as the repo homepage.
- FAQ headings phrased as the questions people ask an assistant.

## Channels (in order, one submission each)

1. Anthropic plugin directory submission form (linked from the anthropics/claude-plugins-official README).
2. skills.sh listing (fed by `npx skills add` installs).
3. Awesome lists, each on its own rules: read its CONTRIBUTING first. Some take PRs, some only issue
   forms, some require a minimum repo age or star count.
4. The niche community the skill serves, then r/ClaudeAI, then X with the GIF.
5. An essay that teaches something and links the repo (dev.to, a blog). Then Show HN with the essay,
   not the bare repo: bare skill-repo links on HN have scored 2–3 points.

## Never

Bought stars, star-for-star swaps, mass DMs, fake quotes, or the same link in many places.
Stars cannot be promised; say so when asked for a number.
