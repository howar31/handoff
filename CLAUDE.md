# handoff — repo guide

Public Claude Code plugin: one model-invoked skill, `handoff`, that saves a session as an LLM-facing handoff document and loads one back to resume work cold. Distributed two ways from this single repo — as a standalone plugin (the repo is its own marketplace) and via the central `howar31` marketplace.

## Layout
- `skills/handoff/SKILL.md` — the skill procedure, and the deliverable. Two modes: SAVE (bundle decisions / state / dead ends / constraints / next steps into one file) and LOAD (autodiscover, present, consume; then follow the file's embedded §0 PROTOCOL).
- `skills/handoff/template.md` — the handoff document spec (§0 PROTOCOL text, §1–§14, format rules); SAVE reads it via `${CLAUDE_SKILL_DIR}`.
- `.claude-plugin/plugin.json` — plugin manifest.
- `.claude-plugin/marketplace.json` — self-marketplace (`source: "./"`) so the repo is directly installable.
- `setup.sh` — symlink installer (recommended path): links the skill into `~/.claude/skills/` for the short `/handoff` name, repo stays source of truth. Idempotent; `--dry-run` / `--force`. The plugin manager is the alternative (namespaced `/handoff:handoff`, discoverable). Use one, not both.
- `README.md` — human-facing overview + install / uninstall.

## Conventions
- The skill is model-invocable: triggering lives entirely in the SKILL.md `description` + `when_to_use` (no `disable-model-invocation` / `user-invocable` gating). Keep `description` + `when_to_use` ≤ 1536 chars or the skill listing truncates (currently ~1030); no `<` / `>` in them.
- Questions to the user are tool-neutral: write "ask the user", never name a question tool.
- `$ARGUMENTS` appears exactly once in SKILL.md; never write `$<digit>` or a whitespace-preceded `` !` `` (both are harness substitution syntax).
- Skill content stays portable and public: no machine-specific paths (use `~/.claude/...`, never a hardcoded home), no personal / employer / locale data in examples, no references to private config files beyond the conventional `~/.claude/USER.md` (read only if present).
- Handoff documents themselves are written to `~/.claude/cache/handoff/` at runtime — they are NOT part of this repo and may contain user-private context.
- Conventional Commits. MIT licensed.

## Install
Recommended — `./setup.sh` (symlink → `/handoff`). Alternative — `claude plugin marketplace add howar31/handoff && claude plugin install handoff@handoff` (→ `/handoff:handoff`).
