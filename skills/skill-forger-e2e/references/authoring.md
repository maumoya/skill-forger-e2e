# Authoring a SKILL.md

## Layout

```
skills/<name>/
  SKILL.md           required: frontmatter + instructions
  references/*.md    optional: detail the model reads only when a step needs it
  scripts/*          optional: work the model runs instead of re-deriving (output is read, code is not)
  templates/ assets/ optional: files copied into the user's output
```

## Frontmatter

| Field | Rule |
|---|---|
| `name` | lowercase letters, digits, hyphens; ≤64 chars; same as the folder; no "claude" or "anthropic" |
| `description` | ≤1024 chars; third person; WHAT it does + WHEN to use it; holds the trigger phrases users type; never the steps |
| `license` | optional; `MIT` is the common choice |
| `compatibility` | optional; ≤500 chars; what the skill needs to run (a CLI, network, a product) |
| `metadata` | optional; a flat map of `key: "string"` pairs; put custom keys here, quote numbers |
| `allowed-tools` | optional, experimental; one space-separated string such as `Read Bash(git:*)`, not a YAML list |

These six keys are the [Agent Skills spec](https://agentskills.io/specification), so every agent that
reads skills understands them. Claude Code adds its own (`argument-hint`, `disable-model-invocation`,
`model` and others); other agents ignore those. Lint warns on any other top-level key. If
`skills-ref` is installed (`pip install skills-ref`), lint also runs `skills-ref validate`.

The description is loaded for every installed skill in every session. The body loads only when the
skill is chosen. So everything that decides *whether* to pick the skill goes in the description, and
everything about *how* goes in the body.

### Description pattern

`<What it does, one sentence>. Use when the user says "<phrase>", "<phrase>", "<phrase>", or asks <situation>. <What makes it different, one sentence>.`

Bad: `Helps with documents.` (no trigger, no difference)

Bad: `Reads the transcript first, then lists decisions, finally assigns owners.` (it narrates the steps;
the model may follow the summary and never read the body, so the body's rules get skipped)

Good: `Turns a meeting transcript into decisions, owners and dates. Use when the user pastes a transcript or says "meeting notes", "action items", "who owns what". Never invents an owner that was not said.`

## Body

- Under 500 lines and about 5,000 tokens. If it grows, move sections to `references/` and link them with "read X when Y".
- Imperative, numbered steps. One action per line.
- Say what done looks like. The model checks against it before replying.
- Give one worked example (input → output) when the output has a shape.
- Prefer a script over prose for anything deterministic (parsing, counting, validating, formatting).
- References one level deep: SKILL.md links to references; references do not link to more references.

## Degrees of freedom

- Fragile, exact work (a migration, a release): exact commands or a script.
- Judgment work (a review, a summary): criteria and an example, not a script.

## Do not

- Put secrets, tokens or personal absolute paths (`/Users/<you>/…`) in any file.
- Tell the model to pipe a download into a shell, run fetched code, or disable safety checks.
- Explain things the model already knows (what JSON is, how git works).
- Write time-sensitive facts without a date.
