<!-- Header: create it with skill-forger-e2e's make_header.sh, then put its img tag here, centered, width 100%. -->

<p align="center">
  <img src="https://img.shields.io/badge/Claude%20Code-skill%20%2B%20plugin-7c5cfc" alt="Claude Code skill and plugin">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license">
  <a href="https://opensource.org/license/mit"><img src="https://img.shields.io/badge/Open%20Source-OSI%20approved%20license-3DA639?logo=opensourceinitiative&logoColor=white" alt="Open Source: OSI-approved MIT license"></a>
  <img src="https://img.shields.io/badge/privacy-no%20tracking%20%C2%B7%20no%20data%20collected-7c5cfc" alt="Privacy: no tracking, no data collected">
  <a href="https://scorecard.dev/viewer/?uri=github.com/__GH__/__NAME__"><img src="https://api.scorecard.dev/projects/github.com/__GH__/__NAME__/badge" alt="OpenSSF Scorecard"></a>
</p>

# __TITLE__

__DESCRIPTION__

<!-- Put a picture or a ≤10 s GIF here: one input → one result. -->

## Install

Claude Code plugin:

```
/plugin marketplace add __GH__/__NAME__
/plugin install __NAME__@__NAME__
```

Any agent that reads skills:

```
npx skills add __GH__/__NAME__
```

## Use

Type: `TRIGGER ONE`

## How it is tested

`evals/` holds one case per promise. Run `claude plugin eval . --allow-tools`.
Every PR runs `scripts/lint_skill.sh` in CI.

## FAQ

### What does it do?

__DESCRIPTION__

### Does it send my data anywhere?

No. It is instructions and local scripts only.

## License

MIT © __YEAR__ __OWNER__
