# Launching a skill

Every public message, form submission, or PR to someone else's repo is an outward action: prepare
it, show it, and let the user send it.

## README (the 10-second test)

In this order:
1. A picture or a ≤10 s GIF: one input → one result. Record it from a `vhs` tape kept in the repo so it can be re-made.
   Or a header banner from `scripts/make_header.sh` (1280×640 SVG + PNG; also the social preview), with a centered
   badge row under it: Claude Code skill + plugin, license, OSI open source, privacy, OpenSSF Scorecard, readiness.
   Only badges that show a live or measured fact; Best Practices only after the project is registered.
   `scripts/badges.sh OWNER/REPO --readiness N` prints the row from live data.
   Add 1-2 benefit badges in green for the main measured win
   (`--benefit 'label=value' --results '#anchor' --from README.md`): cost saved, errors caught, time cut, score
   raised. Each links to a dated `## Results (measured DATE)` section with the method and a table, so anyone can
   check it. `scripts/bench.sh` writes that section from a with-vs-without eval run (billed; ask first), and
   `badges.sh` refuses a value whose numbers are not in it. No measurement, no benefit badge.
   Percentages, never raw sizes: "19% of the disk freed (6% → 25% free)", "100% of deletes approved"; a reader
   cannot judge "86 GiB" without the disk size. readiness flags benefit badges with GiB/MB in them.
   The hero result also goes in a big green SVG card (`assets/<name>-card.svg`, about 760×240: the big % on the left,
   before/after bars on the right, the honest cost line under them) linked to the Results section.
   Then, in the same pass: the owner's profile row and portfolio site get the new numbers. Profile tables use the
   short live "OpenSSF 7.4" badge (`scorecard.sh` prints it), not the default Scorecard badge, which is unreadable there.
2. One line: what it does, for whom.
3. Two install commands (`/plugin install` and `npx skills add`).
4. One real example.
5. How it is tested (eval count, CI badge).
6. FAQ with question headings ("Does it send my data anywhere?").
7. About the author, above License: who built it and why, other work, LinkedIn. `scripts/owner_profile.sh GH_USER
   PROJECT --name "Full Name"` drafts it from the public GitHub profile and prints interview questions
   (why you built it, role, portfolio link, what to keep private). Show the owner the final text; publish only
   what they approve. The script prints only; nothing is saved.

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

## Update round (every change, new measurement or version)

One stale surface is a failed update. Re-measure first, then:
1. Write the new values into `launch/facts.json` (`{"key": {"value", "source", "date"}}`), never copied from an old banner.
2. `launch/assets.json` lists each surface: `{"path", "template", "uses"}` for SVG cards and banners (`{{key}}`,
   `{{key|scale:360}}` for bar widths), `{"path", "run", "uses"}` for PNGs, GIFs and videos, `{"name", "outward", "uses"}`
   for places outside the repo (social preview, About box, profile row). Numbers in Markdown sit in fact markers (format in the header of `scripts/sync.py`).
3. `python3 scripts/sync.py apply . --run`, then `sync.py check .` until "in sync". LEFTOVER means an old value is still
   written by hand somewhere (badge URLs, alt text): fix that line. `launch/keep.txt` lists files left alone (tests).
4. Update each outward item yourself in the built-in browser; after each, `sync.py done . "<name>"`. CI runs
   `sync.py check . --no-outward`.
5. Rewrite the README body, `llms.txt`, description and topics for the current version (Phase 4, update round).
6. New demo? `scripts/make_demo.sh INPUT assets/demo.gif`, then the same file on the portfolio site.

## Never

Bought stars, star-for-star swaps, mass DMs, fake quotes, or the same link in many places.
Stars cannot be promised; say so when asked for a number.
