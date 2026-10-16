# handoff — SPEC

## Purpose
A public Claude Code plugin that ships one model-invoked skill, `handoff`. The skill writes and reads **session handoff documents** — single, self-describing, LLM-facing Markdown files that let a different agent, starting cold in a fresh context window, resume a task from one file alone. SAVE mode captures the session's mission, state, decisions (with rationale and rejected alternatives), dead ends, constraints, open questions, and ordered next actions. LOAD mode autodiscovers the relevant file, confirms with the user, reads it, and then follows the protocol the document embeds in its own §0. The skill contains no runtime code; it is pure prompt guidance.

## Architecture
- **Skill, not a service.** The deliverable is `skills/handoff/` — `SKILL.md` (YAML frontmatter `name`, `description`, `when_to_use`, `argument-hint`, plus the SAVE / LOAD procedure) and `template.md` (the 15-section document spec, §0 PROTOCOL text and format rules), which SAVE reads via `${CLAUDE_SKILL_DIR}/template.md`. Claude reads `description` + `when_to_use` to decide when to auto-invoke; the body loads on invocation.
- **Harness substitutions used:** `$ARGUMENTS` (expanded once, in one labelled line; the rest of the body says "the arguments" so an empty invocation leaves no blank placeholders), `${CLAUDE_SESSION_ID}` (recorded in the handoff), `${CLAUDE_SKILL_DIR}` (locates `template.md`).
- **Two distribution channels from one repo:**
  - *Standalone plugin* — `.claude-plugin/plugin.json` defines the plugin; `.claude-plugin/marketplace.json` (`source: "./"`) makes the repo its own single-plugin marketplace, directly installable.
  - *Central marketplace* — the sibling `howar31-marketplace` repo lists this repo by `source: { github, repo: howar31/handoff }`. Same content, zero duplication.
- **Three install mechanisms, one source:** `setup.sh` (recommended) symlinks the skill directory into `~/.claude/skills/`, giving the short un-namespaced name `/handoff`; `npx skills add … -a claude-code` copies or links the same directory to the same path; the Claude Code plugin manager (`claude plugin …`) installs the same skill namespaced as `/handoff:handoff`, in exchange for marketplace discoverability and `claude plugin update` (Claude Code auto-updates only official marketplaces by default; <https://code.claude.com/docs/en/discover-plugins>). Use only one (`setup.sh` and `npx skills` collide on the path; the plugin adds a second name).

## Data model
- **Handoff documents** live at `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md`, OUTSIDE this repo. They are transient resume-state, may carry user-private context, and are explicitly deletable after pickup (the document's §0 PROTOCOL has the receiving agent ask the user whether to delete it and its assets directory, recommending deletion when `sensitive_items` is non-empty).
- **LOAD discovery** matches by project slug (`<project>-*.md`) AND by the `cwd:` / `repo_root:` lines recorded in each document's §1, so handoffs saved from a subdirectory, a worktree, or under an older slug rule are still found. Older documents keep their own §0; LOAD follows whatever §0 the chosen file carries.
- **Companion assets** live at `<same-basename>.assets/` beside a handoff, created only when SAVE copies files the next agent needs out of a session-specific temporary directory (e.g. the session scratchpad).
- **Source-session reference.** §1 METADATA records `session_id` and `transcript_path`. Transcripts are `~/.claude/projects/<launch-cwd-encoded>/<session-id>.jsonl` (keyed by the launch cwd, so SAVE locates the file with a `~/.claude/projects/*/<id>.jsonl` glob). The receiving agent uses it to look up anything the document leaves unclear, or reopens it with `claude --resume <id>`; SAVE also uses it to recover detail lost to compaction. Transcripts expire with Claude Code's `cleanupPeriodDays`.
- **Information routing** is three-homed and drift-avoiding: durable project knowledge → the project's auto-loaded memory; transient resume-state → the handoff; cross-project handoff behavior → the skill itself. SAVE mode runs in **lean** (memory exists → record only transient state + pointers) or **self-contained** (no memory → spell everything out) form.
- **Memory directory** is per repository (shared by all worktrees and subdirectories), resolved as: the path the harness states in the session's system prompt → `autoMemoryDirectory` setting → `~/.claude/projects/<repo-root-encoded>/memory/` (repo root = main worktree; encoding replaces every non-alphanumeric character with `-`, an observed convention).

## Layout
```
.
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (name, version, author, keywords)
│   └── marketplace.json     # self-marketplace: source "./" → repo installable directly
├── skills/
│   └── handoff/
│       ├── SKILL.md         # the skill: SAVE/LOAD procedure, project resolution, privacy scan
│       └── template.md      # handoff document spec: §0 PROTOCOL text, §1–§14, format rules
├── setup.sh                 # idempotent symlink installer (--dry-run / --force)
├── README.md                # human-facing overview + install/uninstall (English)
├── README.zh-Hant.md        # same content in Traditional Chinese (正體中文)
├── CLAUDE.md                # repo guide for agents working in this repo
├── SPEC.md                  # this file
├── LICENSE                  # MIT
├── .gitattributes           # LF line endings for text, shell, Markdown, JSON
└── .gitignore
```

## Conventions
- **`compatibility` frontmatter** (Agent Skills spec, ≤ 500 chars) states that the skill is designed for Claude Code and what still works elsewhere. Informational only: neither Claude Code nor `npx skills` acts on it.
- **Model-invocation is on by default.** No `disable-model-invocation` or `user-invocable` frontmatter — both the user and Claude can invoke. `description` + `when_to_use` are the sole trigger surface; combined `description` + `when_to_use` must stay ≤ 1536 chars or the listing truncates (currently ~1030). Avoid `<` / `>` in them: the listing HTML-escapes them.
- **Portable content.** No hardcoded home directory (`~/.claude/...`, never `/Users/<name>/...`), no personal / employer / locale data in examples, no dependence on private config files beyond the conventional `~/.claude/USER.md` (read only if present). Project detection degrades gracefully: git remote / main worktree → the user profile's project root (if stated) → pwd analysis (skipping `_`-prefixed container and dotted segments) → ask the user.
- **User profile hints are optional.** The user profile (already in context, e.g. imported by the user's CLAUDE.md, else `~/.claude/USER.md` if present) may supply a common project root and container directories, a timezone, and organization names for the privacy scan. Each hint applies only when the profile states it; otherwise the default (git remote, system time zone, session content) is used. The profile is not a Claude Code built-in; nothing breaks without it.
- **Procedure / template split.** `SKILL.md` holds the procedure; `template.md` holds the document spec. Keeps `SKILL.md` under the 500-line guideline in the Claude Code skills docs.
- **Tool-neutral questions.** Every "ask" / "confirm" (mode, project name, candidate pick, privacy choice, post-pickup deletion) is phrased generically; the agent picks a plain question or a structured question tool. No step names a specific tool.
- **Bilingual README.** `README.md` (English) and `README.zh-Hant.md` (Traditional Chinese, 正體中文) carry the same sections and link each other in a switcher line under the badges; they change together. Neither uses em dashes.
- Line endings are LF for all text files (`.gitattributes`).
- Conventional Commits; MIT license.

## Verification
- `setup.sh` self-verifies after install: confirms the skill path is a symlink to the repo and that `SKILL.md` frontmatter declares `name: handoff`. Re-runnable; reports all-green or pinpoints the failure.
- Manifests are plain JSON — validate with `jq empty <file>`.
- `setup.sh` syntax: `bash -n setup.sh`.
- Portability scan: `grep -RInE '/Users/[^/]+/|/home/[^/]+/' skills/` (hunt for a hardcoded home directory) should return only the generic `/Users/you/...` path-format example in template.md, nothing else.
- Placeholder hygiene: `grep -nE '\$[0-9]|(^|\s)!`' skills/handoff/SKILL.md` returns nothing (no accidental positional-argument or shell-injection syntax); `$ARGUMENTS` appears exactly once.
- Frontmatter: `description` + `when_to_use` length ≤ 1536, e.g. `ruby -ryaml -e 'd=YAML.load(File.read("skills/handoff/SKILL.md").split(/^---$/)[1]); p d["description"].size+d["when_to_use"].size'`.
- Render check: `claude -p --plugin-dir . --allowedTools=Skill` with a prompt that invokes `handoff:handoff` and prints the arguments / session-ID / template lines; all three substitutions must show real values.
- Project resolution: run the "Resolving the project" snippet from the repo root, a subdirectory and a linked worktree; all three must yield the same `REPO_ROOT`, project and memory directory.

## Deploy
- **Publish:** push to `github.com/howar31/handoff` (public). The repo is consumed live by the plugin manager — no build step.
- **Install (recommended, symlink):** `./setup.sh` symlinks the skill into `~/.claude/skills/` → `/handoff`. Idempotent; `--dry-run` / `--force`.
- **Install (npx skills):** `npx skills add howar31/handoff -g -a claude-code` → `/handoff` (writes the same `~/.claude/skills/handoff` path as `setup.sh`; use one). Update with `npx skills update handoff -g`, remove with `npx skills remove handoff -g`.
- **Install (plugin):** `claude plugin marketplace add howar31/handoff` then `claude plugin install handoff@handoff`; or via the central marketplace, `…add howar31/howar31-marketplace` then `install handoff@howar31`. → `/handoff:handoff`.
- Run `/reload-plugins` if the skill does not appear immediately.

## Known Limitations
- The source transcript is machine-local and expires after Claude Code's retention period; a handoff loaded on another machine or later than that falls back to the document alone.
- Uncommitted, unpushed and stashed work, and copied assets, exist only on the machine that saved the handoff; the document records them but does not transfer them.
- The transcript-extraction command embedded in §12 needs `jq`; `grep` on the transcript is the fallback.
- The memory-directory encoding (non-alphanumeric → `-`) is an observed convention, not documented by Claude Code; the skill prefers the path the harness states.

## Key Decisions
- **Genericized from a private original.** The skill began as a personal copy with a hardcoded home directory, employer-specific container names in the project-detection rules, and project-specific example slugs. Those were removed: paths became `~/.claude/...`, the hardcoded project-root rule was dropped, and examples were neutralized.
- **One version, personal data in the profile (2026-10-16).** Keeping a private copy alongside the public one let the two drift apart. The private copy's user-specific behavior (project root and container directories, a fixed timezone, organization names to scan for) became conditional rules fed by the user profile, so the public skill is the only version and personal data stays in the user's own files.
- **Dual-channel, single source.** Shipping `plugin.json` + a self `marketplace.json` in the same repo, and also listing the repo in the central marketplace, lets one source serve both install paths without copying skill content.
- **No model-invocation gating.** The skill's side effects are writing a handoff file (plus optional assets directory) under `~/.claude/cache/handoff/`, promoting durable facts into project memory in lean mode, and prompting before deletion on load, so it is left fully model- and user-invocable.
- **setup.sh is the recommended install.** It is a single, model-invoked skill, so the plugin namespace (`/handoff:handoff`) only adds length without benefit; the symlink install keeps the short `/handoff` for manual invocation. The plugin path stays available for users who want marketplace discoverability and auto-update.
- **`npx skills` channel, Claude Code first (2026-10-16).** Earlier the repo deliberately did not offer `npx skills`. The reasons that remain are Claude Code-only features: lean mode reads Claude Code's per-repository auto-memory store, and the source-session lookup relies on `${CLAUDE_SESSION_ID}` and Claude Code's transcript layout. After the questions became tool-neutral and every Claude Code-specific step gained a fallback (unexpanded session ID → `unknown`; unexpanded `${CLAUDE_SKILL_DIR}` → the directory containing SKILL.md; no memory store → self-contained mode), other agents degrade to plain SAVE / LOAD instead of breaking, so `npx skills` is offered. `npx skills` has no author-side way to restrict target agents (its CLI picks agents by detection or `-a`, and does not act on the Agent Skills `compatibility` field), so the README install command passes `-a claude-code`, and `compatibility` in SKILL.md states the scope for readers. Behavior in non-Claude agents is untested. Verified: `npx skills add <repo> -a claude-code` copies `SKILL.md` and `template.md` unchanged.
- **Handoffs are not repo content.** The documents the skill produces are runtime artifacts under the user's `~/.claude/cache/`, never committed here; they are deliberately ephemeral and deletable to bound private-context leakage.
- **Session ID over a richer document (2026-10-16).** A handoff is lossy by design; recording the source session ID lets the receiving agent consult the full transcript for anything unclear instead of the document trying to capture everything. The transcript is a lookup source, never a substitute for writing state down (it expires, and a non-Claude receiver may not be able to resume it).
- **Drift check at pickup (2026-10-16).** §0 makes the receiving agent compare current git state and elapsed time with §4 / `written_at` before its first message, because work may have moved on between save and load.
