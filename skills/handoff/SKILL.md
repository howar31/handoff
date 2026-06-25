---
name: handoff
description: >-
  Save OR load a session handoff document at `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md`. SAVE mode bundles the session's decisions, technical context, dead ends, and open questions into an LLM-facing English doc for the next agent — trigger when user types `/handoff` (without `load`) or asks "做交接", "session 交接", "交接這個 session", "建立交接文件", "把 context 存起來", "create a handoff", "save context for handoff", "save session for next agent"; accepts optional free-text focus or `topic: <slug>` prefix. LOAD mode autodiscovers cwd-matching handoffs, presents candidates via AskUserQuestion, then reads the chosen file and follows its embedded §0 PROTOCOL — trigger when user types `/handoff load` or asks "接續交接", "讀取交接文件", "上次做到哪", "之前的進度", "之前的工作", "load handoff", "continue from previous session", "resume the previous session"; accepts optional filename / substring filter. Ask user when intent is ambiguous.
---

# /handoff — Session Handoff Skill

This skill **saves** the current session as a handoff document OR **loads** a previously-written one. Documents are **purely LLM-facing** — do NOT optimize for human readability. Save mode optimizes for: a different LLM, starting cold in a fresh context window, must be able to fully understand the task's mission, state, priorities, constraints, and next steps from the one file alone. Load mode discovers, presents, and consumes such a file.

Documents live at `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md` (a dedicated subdirectory under `cache/` to keep handoffs isolated from other transient cache content). They are not auto-loaded — load mode is triggered explicitly by the user.

---

## Information routing model

Cross-session knowledge has three homes. Route each fact to ONE home; duplicating across homes causes drift (two copies diverge):

- **Durable project knowledge** (recurring constraints, build/run/test/git workflow, architecture invariants, roadmap/backlog, conventions) → the project's **memory** (`~/.claude/projects/<encoded-cwd>/memory/`). Auto-loaded (index) / relevance-injected every session, so it is available WITHOUT a handoff.
- **Transient resume-state** (current HEAD, what was just committed, the in-flight task and exactly where it stopped, this-session-only decisions / dead-ends not yet promoted) → **this handoff**. Loaded on demand only when resuming, so it never pollutes unrelated sessions.
- **Cross-project agent behavior** (how handoffs are written / routed) → this skill.

### Two SAVE modes

- **Lean** — use when the cwd HAS an established memory store (`~/.claude/projects/<encoded-cwd>/memory/MEMORY.md` exists) and/or a handoff-convention memory. Durable knowledge stays in memory; the handoff records ONLY transient state + POINTERS to the canonical memory entries. Any section whose body would duplicate memory is compressed to a one-line pointer. Before writing, PROMOTE any durable fact surfaced this session into memory (create/update the entry) instead of leaving it only in the handoff.
- **Self-contained** — the default when there is NO memory store. The handoff spells everything out and stands alone (the original behavior).

A handoff-convention memory in the cwd MAY override these defaults (e.g. force lean, or specify the canonical memory list / a keep-vs-delete policy). Honour it.

---

## Step 0: Detect mode

Inspect `$ARGUMENTS` and the triggering input to decide between SAVE and LOAD mode.

| Signal | Mode |
|---|---|
| `$ARGUMENTS` starts with `load`, `resume`, or `read` (case-insensitive) | LOAD |
| Triggering natural-language phrase matches LOAD trigger list (in description) | LOAD |
| Bare `/handoff` with no load keyword AND no LOAD-list phrase | SAVE |
| Triggering phrase matches SAVE trigger list (in description) | SAVE |
| Truly ambiguous (e.g. user said only "handoff", "處理交接") | Use `AskUserQuestion` to disambiguate before proceeding |

After determining mode:
- **SAVE** → proceed to **Save Mode** section below.
- **LOAD** → strip the `load` / `resume` / `read` keyword from `$ARGUMENTS`; any remaining non-empty text is an optional filename / substring filter. Proceed to **Load Mode** section.

**95% confidence rule**: at any point during mode detection, if you are not at least 95% confident of user intent, use `AskUserQuestion`. Default to asking rather than guessing.

---

# Save Mode

## Step 1: Parse `$ARGUMENTS`

| Input form | Behavior |
|---|---|
| Empty | topic + focus both inferred from session |
| Starts with `topic: <slug>` | topic = `<slug>`, focus = remainder of `$ARGUMENTS` |
| Other free text | focus = full text, topic inferred from focus + session |

The `<slug>` must be kebab-case, max ~30 chars. If user-provided slug violates this, normalize it (lowercase, replace spaces / underscores with hyphens, strip non-alphanumeric except hyphens, truncate).

**Inferring topic** when not explicit: pick a short kebab-case slug summarizing the dominant theme of the session (e.g., `migration-debug`, `auth-rewrite`, `rate-limit-fix`). If session is too varied to summarize, use `general`.

---

## Step 2: Determine `<project>` — priority-ordered rules

Apply in order. First rule that yields a non-empty, non-sentinel project name wins. Sentinels that always trigger fall-through: project name starts with `_` (a container / grouping prefix), OR equals your home-directory basename (i.e. `$(basename "$HOME")`, usually your username), OR equals `/` or `.claude` (the Claude config directory itself).

### Rule 2.1: Git repository

If `git rev-parse --is-inside-work-tree` succeeds:

1. Extract from remote URL (prefer `origin`, else first remote):
   ```bash
   remote=$(git config --get remote.origin.url 2>/dev/null)
   if [ -z "$remote" ]; then
     first_remote=$(git remote | head -n1)
     [ -n "$first_remote" ] && remote=$(git config --get remote.${first_remote}.url 2>/dev/null)
   fi
   ```
2. If a remote URL exists: `project=$(basename "$remote" .git)`.
3. If no remote at all: `project=$(basename "$(git rev-parse --show-toplevel)")`.
4. Sanity-check `project` against sentinels. If it hits a sentinel, fall through to Rule 2.2.

### Rule 2.2: pwd analysis + cache cross-check

1. Extract candidate segments from `pwd`, skipping common non-project directory names:
   `src`, `lib`, `dist`, `build`, `node_modules`, `tests`, `test`, `docs`, `bin`, `Downloads`, `Desktop`, `Documents`, `Library`, `Applications`, and any segment starting with `.` or `_` (the latter skips container / grouping directories, so the meaningful project segment beneath them wins).
2. For each candidate `c`, check:
   ```bash
   ls ~/.claude/cache/handoff/${c}-*.md 2>/dev/null
   ```
3. **95% confidence rule (this exact condition only)**: exactly one candidate has at least one match in `cache/handoff/`. Use that candidate.
4. Any other outcome — zero matches, multiple candidates with matches, multiple candidates with no clear winner — fall through to Rule 2.3.

### Rule 2.3: Ask the user

Use `AskUserQuestion` with options:

- Each meaningful pwd segment from Rule 2.2 (annotate with "(matches existing handoff)" if `cache/handoff/` has any `<segment>-*.md`).
- `general` (default bucket).
- If pwd yields zero meaningful candidates, still offer `general` and let user type custom via "Other".

Block on user reply. Do not proceed until a project name is chosen.

---

## Step 3: Gather session context

Before writing, internally collect (do not show to user yet):

- **Recent conversation turns**: what the user has been asking, deciding, redirecting
- **File edits made this session**: paths, what changed, why
- **Tool calls made**: especially git operations, deploys, external API calls
- **Git state**: run `git rev-parse --abbrev-ref HEAD 2>/dev/null`, `git rev-parse HEAD 2>/dev/null`, `git status --short 2>/dev/null`. If not in a git repo, note as such.
- **Decisions reached + their rationale + rejected alternatives**: with verbatim user quotes where available
- **Dead ends**: things tried that failed, things considered and rejected
- **Open questions**: items needing user input vs items needing investigation
- **Constraints and DON'Ts**: from project memory, from user-stated rules this session, from project's CLAUDE.md / SPEC.md if read this session
- **Artifacts produced**: screenshots, generated files, probe captures, logs — note absolute paths

Apply `$ARGUMENTS` focus guidance (if any) to weight emphasis — e.g. if focus says "focus on lock contention findings", expand §6 DECISIONS and §8 DEAD ENDS sections around that topic, compress others.

**Select mode + triage** (see "Information routing model"): check whether the cwd has a memory store (`~/.claude/projects/<encoded-cwd>/memory/MEMORY.md` exists) and/or a handoff-convention memory → write **lean**; else **self-contained**. Then TRIAGE every fact gathered above into durable vs transient. In lean mode, for each DURABLE fact (recurring constraint / workflow / invariant / architecture / roadmap / backlog), PROMOTE it into memory now (create or update the entry, dedup against what exists) and reference it from §13 — do NOT spell it out in the handoff; the doc keeps only transient state.

---

## Step 4: Generate the handoff document

Produce all 15 sections in order. **Empty sections retain the header with `(none)` as the body** — this tells the receiving LLM the topic was considered, not forgotten.

**Lean mode:** keep every section header, but replace any body that would duplicate the project's memory with a one-line pointer to the canonical entry (e.g. "see `editor-invariants.md`"). Always spell out the TRANSIENT sections (§1 METADATA, §3b current slice, §4 STATE, §5 PRIORITIES, §6 this-session DECISIONS, §8 this-session DEAD ENDS, §9 OPEN QUESTIONS, §14 NEXT ACTIONS); compress the DURABLE sections (§2 ORIENTATION, §7 CONSTRAINTS, §10/§11/§12 where they restate memory) to pointers. §13 READ FIRST is always the pointer list to the canonical memory entries.

### §0 PROTOCOL — embed verbatim

Insert exactly this text as section §0:

```
# Handoff Protocol — Read This First

You are an AI agent receiving a session handoff. Before taking any action:

1. Read this entire document end-to-end.
2. Open and read every file listed under §13 READ FIRST in the order given.
3. Mentally confirm you can answer:
   - What is the user's current objective?
   - What is the immediate top priority (§5 PRIORITY 1)?
   - What constraints must you honour (§7)?
   - What dead ends must you not retry (§8)?
4. If any of the above is unclear, ask the user before acting.
5. If clear, your first message to the user should be:
   "Handoff consumed. Current top priority: <quote §5 PRIORITY 1>. Confirm before I proceed?"
6. Do NOT take any non-readonly action until the user confirms.
7. After the user confirms work is picked up, you MUST use the AskUserQuestion tool
   (not just a text suggestion) to ask whether to delete this handoff file. Path
   appears in §1 METADATA `file_path`. If §1 METADATA `sensitive_items` is non-empty,
   mark "delete" as the recommended option and mention the sensitive items count so
   the user understands the leakage motivation.
```

### §1 METADATA — YAML frontmatter or fenced block

```yaml
project: <project-slug>
topic: <topic-slug>
written_at: <ISO 8601 with TZ, e.g., 2026-05-11T14:30:52+08:00>
session_duration_estimate: <e.g., "~3 hours" or "unknown">
cwd: <absolute path of $(pwd) at handoff time>
generated_by_model: <e.g., the model id of the agent writing this>
file_path: <the full absolute path this handoff is being written to>
sensitive_items:        # empty list [] if scan was clean
  - "<item> (N occurrences)"
  - "<item> (N occurrences)"
```

### §2 ORIENTATION

User identity, language preference, environment. The receiving LLM may be told nothing else about who the user is. Include:

- User name, role, location, timezone
- Conversation language preference
- OS, shell, common project root
- Assumed cwd for next session

Pull from `~/.claude/USER.md` if it exists and is relevant (a conventional Claude Code profile file). Do not assume any particular identity file exists; omit fields you cannot determine.

### §3 MISSION — three subsections

**(a) Long-term mission**: what the larger project is for, why it exists, who it serves.

**(b) Current session slice + recent intent**: what this session focused on, what user has been actively pushing on in the most recent hours / turns, success criteria for the immediate slice.

**(c) Intentionally deferred from scope**: work explicitly excluded from this session, with reason. Distinct from "pending" or "dead end" — this is "we know about it, we chose not to do it now."

### §4 STATE

**Code state**:
- Git branch
- Latest commit hash + one-line subject
- Modified / staged / untracked files (absolute paths)
- Clean or dirty

**System state**:
- Deployed? to where? what version?
- Processes running (relevant ones)
- Secrets / tokens rotated this session? what's the state?
- Migrations applied?

**Recent artifacts**:
- Screenshots, probe captures, generated logs, scratch files — absolute paths

### §5 PRIORITIES

Top 1–3 priorities for the receiving agent, ordered. Format each as:

```
PRIORITY 1: <action>
  RATIONALE: <why this is top>

PRIORITY 2: <action>
  RATIONALE: <why>

PRIORITY 3: <action>
  RATIONALE: <why>
```

### §6 DECISIONS — this session only

Format per entry:

```
DECISION: <decision>
  RATIONALE: <why this choice>
  REJECTED: <alternative(s) considered + why rejected>
  SOURCE: <verbatim user quote, OR "agent judgment", OR "user-confirmed agent suggestion">
```

Prior-session decisions live in memory or SPEC.md — link them from §13 READ FIRST, do not duplicate.

### §7 CONSTRAINTS

Hard rules. Use markers:

```
CONSTRAINT: <rule>
DO NOT: <action>
INVARIANT: <property that must hold>
```

Include: privacy rules, environment quirks, deployment safety rules, user-explicit DON'Ts, hidden invariants.

### §8 DEAD ENDS — two subsections

**(a) TRIED-AND-FAILED**:

```
ATTEMPTED: <what>
  OUTCOME: <result>
  ROOT CAUSE: <why it failed>
```

**(b) CONSIDERED-AND-REJECTED**:

```
CONSIDERED: <approach>
  REJECTED BECAUSE: <reason>
```

Both prevent the next agent from repeating work.

### §9 OPEN QUESTIONS — two subsections

**(a) NEEDS USER INPUT**: questions only the user can decide. Blocking on user.

**(b) NEEDS INVESTIGATION**: questions an agent can pursue autonomously.

### §10 VERIFICATION

- What was tested in this session (and how)
- What was NOT tested
- Known fragility (likely failure modes)
- Manual smoke-test steps the receiving agent should re-run before risky actions

### §11 LOCATIONS — absolute paths

- Code directories
- Config files
- Log files
- Env vars / secrets locations (`.env` paths, shell exports, secret managers, where API keys live)
- Sensitive-content paths outside the repo (e.g. probe data, sensitive scratch)
- Server paths (SSH targets, remote paths)
- Artifact / probe directories produced this session

### §12 QUICK COMMANDS

Bash one-liners the receiving agent can copy-paste. Format:

```
# <purpose>
<command>

# <purpose>
<command>
```

Examples of what to include:
- Run main check / test command
- Tail relevant logs
- Common SSH invocation
- Restart relevant service
- Reset state for re-test

All paths in commands must be absolute.

### §13 POINTERS — two subsections

**(a) READ FIRST** (before acting): list specific files with absolute paths. Includes:
- Project's CLAUDE.md if any
- Project's SPEC.md if any
- Relevant memory entries from `~/.claude/projects/<encoded-cwd>/memory/`
- Any other docs critical to safe action

**(b) REFERENCE MATERIALS** (optional context): external docs, Linear / Notion / Slack links, upstream documentation.

### §14 NEXT ACTIONS

Concrete ordered steps. Format:

```
STEP 1: <action>
  EXPECTED OUTCOME: <what success looks like>
  IF FAILS: <fallback or who to escalate to>

STEP 2: <action>
  EXPECTED OUTCOME: <...>
  IF FAILS: <...>
```

---

## Step 5: LLM-facing format rules — apply to all content

| Rule | Detail |
|---|---|
| Paths | Absolute only in the generated document. Expand `~` to the real home path (e.g. `/home/you/.claude/...` or `/Users/you/.claude/...`) — never leave a literal `~/` in the doc. |
| Timestamps | ISO 8601 with TZ. E.g. `2026-05-11T14:30:52+08:00`. Never "May 11" / "2pm" / "yesterday". |
| Empty sections | Keep section header, body = `(none)`. Don't omit the section. |
| User quotes | Verbatim where decisions came from user. No paraphrase. Mark with `SOURCE: <quote>` or block-quote. |
| Structured markers | Use `DECISION:`, `CONSTRAINT:`, `DO NOT:`, `INVARIANT:`, `PRIORITY <n>:`, `STEP <n>:`, etc., to enable easy LLM extraction. |
| Abbreviations | Expand on first use. No assumed jargon. |
| Decoration | No emoji. No nested tables. No HTML. Vanilla markdown only. |
| Tool / framework references | Generic terms. "Open the file" not "use the Read tool". Receiving LLM may not be Claude. |
| Standalone-ness | Self-contained mode: spell everything out; the doc must not rely on conversation history, auto-loaded memory, or implicit context. Lean mode: the doc MAY rely on the cwd's auto-loaded / relevance-injected memory, which it MUST list in §13 READ FIRST — but it must still stand alone for all TRANSIENT state and must never rely on conversation history. |

---

## Step 6: Privacy scan — warn, do not block

Sensitive context is often **necessary** for the receiving agent to continue work in progress (project names, organization / employer names, hostnames may all be required for comprehension). The scan therefore **warns** the user but does not force redaction. The post-pickup deletion prompt embedded in §0 PROTOCOL (step 7) provides the leakage safeguard.

Sources of candidates:

- Organization / employer / company names mentioned in this session
- Server hostnames referenced (SSH targets, internal URLs)
- SSH config aliases used
- GitHub owner handles for private repos
- User email if it appears in the content
- Identifiers flagged private in a project privacy/redaction memory entry (e.g. `~/.claude/projects/<encoded-cwd>/memory/feedback_repo_privacy.md`) — read on demand if one exists for the current project

**If candidates found**: present the list to the user as a warning:

> "Privacy scan detected potentially sensitive strings in the handoff:
> - `<item>` (N occurrences)
> - `<item>` (N occurrences)
>
> Sensitive context is often necessary for the receiving agent. The recommended flow is to keep these intact — the receiving agent will be prompted to delete the handoff immediately after pickup is confirmed, preventing long-term leakage.
>
> Choose:
> - `continue` — keep all sensitive items, record them in §1 METADATA `sensitive_items` so deletion is prompted strongly at pickup
> - `redact: <items>` — replace specified items with placeholders (`<ORG>`, `<HOST>`, `<HANDLE>`, `<EMAIL>`)
> - `abort` — cancel write"

**If user picks `continue`**: proceed. Ensure §1 METADATA `sensitive_items` field lists each item + count. Ensure §7 CONSTRAINTS includes: `CONSTRAINT: This handoff contains sensitive context (see §1 METADATA sensitive_items). Delete this file immediately after the receiving agent confirms pickup is complete.`

**If user picks `redact`**: apply replacements, re-scan the rewritten content (rewriting may introduce new matches via context expansion). Loop until clean or user explicitly accepts remaining items. Update §1 METADATA `sensitive_items` to reflect what remains (empty list if fully clean).

**If user picks `abort`**: stop, do not write, delete any partially-written file, report to user.

**If zero candidates found**: write directly. §1 METADATA `sensitive_items` field is set to `[]`. No prompt.

---

## Step 7: Compute filename and check collision

```bash
# Ensure the dedicated handoff subdirectory exists
mkdir -p ~/.claude/cache/handoff

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
FILE=~/.claude/cache/handoff/${PROJECT}-${TOPIC}-${TIMESTAMP}.md

# Collision check
N=1
TRY_FILE="$FILE"
while [ -e "$TRY_FILE" ]; do
  N=$((N + 1))
  TRY_FILE="${FILE%.md}-${N}.md"
done
FILE="$TRY_FILE"
```

If your environment has a fixed timezone preference, set it explicitly (e.g. prefix the `date` call with `TZ=...`) so timestamps are stable across machines.

---

## Step 8: Write the file and report

Write the full content to `$FILE`. After write, report to user:

```
Handoff written: <absolute file path>
Topic: <topic-slug>
Project: <project-slug>
Sections: <number of non-empty sections> populated, <number> marked (none)

To resume in a future session, say one of:
  接續交接
  讀取交接文件
  load handoff
```

Do not list the full handoff content back to the user — they already know what was in the session.

---

# Load Mode

You are loading a handoff written by a previous session. The doc is LLM-facing; once read, you follow the §0 PROTOCOL embedded inside it. The skill's responsibility ends after the file is read — subsequent behavior is governed by §0.

## Step 1: Collect candidates

1. Compute project slug:
   ```bash
   project=$(basename "$(pwd)")
   ```
2. Primary glob (newest first):
   ```bash
   ls -t ~/.claude/cache/handoff/${project}-*.md 2>/dev/null
   ```
3. If `$ARGUMENTS` carries a filter (any non-empty remainder after the `load` / `resume` / `read` keyword was stripped in Step 0), apply it as a **case-insensitive substring match** against each candidate filename. Reduce the candidate set accordingly.

## Step 2: Present candidates and confirm

| Candidate count | Action |
|---|---|
| 0 | Tell the user there is no handoff matching `<project>`. Offer the cross-project fallback (Step 3). |
| 1 | Show the candidate's metadata (filename, mtime, topic slug, §1 METADATA preview — first ~10 lines of the file). Use `AskUserQuestion` to confirm. **Never auto-pick, even when N=1.** |
| ≥2 | Use `AskUserQuestion` with each candidate as an option. Annotate each with filename, mtime, topic slug, and §1 METADATA preview. |

**Confidence rule**: if a user-supplied filter substring-matches multiple candidates, or you are otherwise unsure which file the user means, do not guess — escalate to `AskUserQuestion`.

## Step 3: Cross-project fallback

When invoked (zero cwd matches, OR user explicitly chose "list across projects" in Step 2):

```bash
ls -t ~/.claude/cache/handoff/*.md 2>/dev/null | head -n 10
```

Present the top 10 via `AskUserQuestion`. Each option should display: project segment, topic, mtime, filename. Add an `Other` slot so the user can enter a custom filename / path.

## Step 4: Read the chosen file and follow §0 PROTOCOL

1. Use the Read tool on the chosen absolute path.
2. The file's §0 PROTOCOL is now in your context — follow it. In particular:
   - §0 step 5 prescribes your first user-facing message after consumption.
   - §0 step 7 prescribes the post-pickup `AskUserQuestion` deletion prompt (mark `delete` as recommended when §1 METADATA `sensitive_items` is non-empty).

Skill responsibility ends here. Do not duplicate §0 substeps in this skill.

---

## Examples

### Save mode

**Example 1: bare invocation**

```
/handoff
```

Behavior: SAVE mode. Infer topic and focus from session. Project = `basename "$(pwd)"`.

**Example 2: free-text focus**

```
/handoff finish the data-import migration debugging, focus on lock contention and rollback safety
```

Behavior: SAVE mode. Focus = full text. Topic inferred as `migration-debug` or `lock-contention`. Project from cwd.

**Example 3: explicit topic override**

```
/handoff topic: rollback-safety highlight the three deferred test cases and the verification gap
```

Behavior: SAVE mode. Topic = `rollback-safety`. Focus = "highlight the three deferred test cases and the verification gap".

### Load mode

**Example 4: bare load**

```
/handoff load
```

Behavior: LOAD mode. Glob `cache/handoff/${basename_pwd}-*.md`, present candidates via `AskUserQuestion`, await user pick.

**Example 5: load with substring filter**

```
/handoff load api
```

Behavior: LOAD mode. Glob then filter filenames containing `api` (case-insensitive). If multiple matches, present via `AskUserQuestion`; if one, still confirm before consuming.

**Example 6: natural-language resume**

```
接續交接
```

Behavior: LOAD mode, equivalent to bare `/handoff load`. No filter.

**Example 7: ambiguous input**

```
handoff
```

Behavior: ambiguous (no slash, no clear save/load phrase). Use `AskUserQuestion` to disambiguate before proceeding.

---

## Reminders

### Save mode
- Route by the Information routing model: durable → memory (PROMOTE it, don't just describe it here), transient → this doc. In lean mode (cwd has a memory store) compress memory-duplicating sections to pointers; never re-spell memory.
- The output document is for an LLM, not a human. Bias toward density, explicitness, and structured markers.
- Never use `~/` paths in the document. Always absolute.
- Never use natural-language dates. Always ISO 8601 with TZ.
- Empty sections stay with `(none)` body — do not omit.
- Always run the privacy scan loop before writing.
- Always check for filename collision and append `-2`, `-3`, etc.
- After writing, do not echo the whole doc back to the user.

### Load mode
- Never auto-pick a candidate, even when only one matches the cwd glob.
- Both candidate selection and post-pickup deletion must use `AskUserQuestion`, never text suggestions.
- After Step 4 (Read), hand off to the file's §0 PROTOCOL — do not duplicate or override its substeps in this skill.
- When the user supplies a substring filter that matches multiple candidates, escalate to `AskUserQuestion`; do not guess "they probably meant the latest".
