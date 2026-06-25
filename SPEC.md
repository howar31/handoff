# handoff — SPEC

## Purpose
A public Claude Code plugin that ships one model-invoked skill, `handoff`. The skill writes and reads **session handoff documents** — single, self-describing, LLM-facing Markdown files that let a different agent, starting cold in a fresh context window, resume a task from one file alone. SAVE mode captures the session's mission, state, decisions (with rationale and rejected alternatives), dead ends, constraints, open questions, and ordered next actions. LOAD mode autodiscovers the relevant file, confirms with the user, reads it, and then follows the protocol the document embeds in its own §0. The skill contains no runtime code; it is pure prompt guidance.

## Architecture
- **Skill, not a service.** The deliverable is `skills/handoff/SKILL.md` — Markdown with YAML frontmatter (`name`, `description`). Claude reads the `description` to decide when to auto-invoke; the body loads on invocation.
- **Two distribution channels from one repo:**
  - *Standalone plugin* — `.claude-plugin/plugin.json` defines the plugin; `.claude-plugin/marketplace.json` (`source: "./"`) makes the repo its own single-plugin marketplace, directly installable.
  - *Central marketplace* — the sibling `howar31-marketplace` repo lists this repo by `source: { github, repo: howar31/handoff }`. Same content, zero duplication.
- **Two install mechanisms, one source:** `setup.sh` (recommended) symlinks the skill directory into `~/.claude/skills/`, giving the short un-namespaced name `/handoff`; the Claude Code plugin manager (`claude plugin …`) installs the same skill namespaced as `/handoff:handoff`, in exchange for marketplace discoverability and auto-update. Use one, not both (both would expose the skill under two names).

## Data model
- **Handoff documents** live at `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md`, OUTSIDE this repo. They are transient resume-state, may carry user-private context, and are explicitly deletable after pickup (the document's §0 PROTOCOL prompts the receiving agent to delete it).
- **Information routing** is three-homed and drift-avoiding: durable project knowledge → the project's auto-loaded memory (`~/.claude/projects/<encoded-cwd>/memory/`); transient resume-state → the handoff; cross-project handoff behavior → the skill itself. SAVE mode runs in **lean** (memory exists → record only transient state + pointers) or **self-contained** (no memory → spell everything out) form.

## Layout
```
.
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (name, version, author, keywords)
│   └── marketplace.json     # self-marketplace: source "./" → repo installable directly
├── skills/
│   └── handoff/
│       └── SKILL.md         # the skill: SAVE/LOAD modes, 15-section doc spec, privacy scan
├── setup.sh                 # idempotent symlink installer (--dry-run / --force)
├── README.md                # human-facing overview + install/uninstall
├── CLAUDE.md                # repo guide for agents working in this repo
├── SPEC.md                  # this file
├── LICENSE                  # MIT
└── .gitignore
```

## Conventions
- **Model-invocation is on by default.** No `disable-model-invocation` or `user-invocable` frontmatter — both the user and Claude can invoke. The `description` is the sole trigger surface; combined `description` + `when_to_use` must stay ≤ 1536 chars or the listing truncates (currently ~1014).
- **Portable content.** No hardcoded home directory (`~/.claude/...`, never `/Users/<name>/...`), no personal / employer / locale data in examples, no dependence on private config files beyond the conventional `~/.claude/USER.md` (read only if present). Project detection degrades gracefully: git remote / toplevel → pwd analysis (skipping `_`-prefixed container and dotted segments) → ask the user.
- **Single-file skill.** All skill content lives in one SKILL.md (no split reference files) — proportionate to its size.
- Conventional Commits; MIT license.

## Verification
- `setup.sh` self-verifies after install: confirms the skill path is a symlink to the repo and that `SKILL.md` frontmatter declares `name: handoff`. Re-runnable; reports all-green or pinpoints the failure.
- Manifests are plain JSON — validate with `jq empty <file>`.
- `setup.sh` syntax: `bash -n setup.sh`.
- Portability scan: `grep -RInE '/Users/[^/]+/|/home/[^/]+/' skills/` (hunt for a hardcoded home directory) should return only the generic `/Users/you/...` path-format example in SKILL.md, nothing else.

## Deploy
- **Publish:** push to `github.com/howar31/handoff` (public). The repo is consumed live by the plugin manager — no build step.
- **Install (recommended, symlink):** `./setup.sh` symlinks the skill into `~/.claude/skills/` → `/handoff`. Idempotent; `--dry-run` / `--force`.
- **Install (plugin):** `claude plugin marketplace add howar31/handoff` then `claude plugin install handoff@handoff`; or via the central marketplace, `…add howar31/howar31-marketplace` then `install handoff@howar31`. → `/handoff:handoff`.
- Run `/reload-plugins` if the skill does not appear immediately.

## Key Decisions
- **Genericized from a private original.** The skill began as a personal copy with a hardcoded home directory, employer-specific container names in the project-detection rules, and project-specific example slugs. Those were removed: paths became `~/.claude/...`, a personal project-root-specific detection rule was dropped (git + pwd-analysis + ask cover the same ground generically), and examples were neutralized.
- **Dual-channel, single source.** Shipping `plugin.json` + a self `marketplace.json` in the same repo, and also listing the repo in the central marketplace, lets one source serve both install paths without copying skill content.
- **No model-invocation gating.** The skill's only side effect is writing a handoff file under `~/.claude/cache/handoff/` (and prompting before deletion on load), so it is left fully model- and user-invocable.
- **setup.sh is the recommended install.** It is a single, model-invoked skill, so the plugin namespace (`/handoff:handoff`) only adds length without benefit; the symlink install keeps the short `/handoff` for manual invocation. The plugin path stays available for users who want marketplace discoverability and auto-update.
- **Handoffs are not repo content.** The documents the skill produces are runtime artifacts under the user's `~/.claude/cache/`, never committed here; they are deliberately ephemeral and deletable to bound private-context leakage.
