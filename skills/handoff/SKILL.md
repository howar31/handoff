---
name: handoff
description: >-
  Save or load an LLM-facing session handoff document so a fresh agent (any model, cold context) can resume work from one file. SAVE bundles the session's decisions, state, dead ends, constraints, open questions and next steps into a file under ~/.claude/cache/handoff/, and records the source session ID so the next agent can look up the original conversation when the document is unclear. LOAD finds the current project's handoffs, confirms the choice with the user, reads the file, and follows the protocol embedded in its §0.
when_to_use: >-
  SAVE: the user types `/handoff` (without `load`) or asks "做交接", "session 交接", "交接這個 session", "建立交接文件", "把 context 存起來", "create a handoff", "save context for handoff", "save session for next agent"; optional free-text focus or a `topic: slug` prefix. LOAD: the user types `/handoff load` or asks "接續交接", "讀取交接文件", "上次做到哪", "之前的進度", "之前的工作", "load handoff", "continue from previous session", "resume the previous session"; optional filename / substring filter. Ask the user when the intent is ambiguous.
argument-hint: "[load [filter]] | [topic: slug] [focus]"
---

# /handoff — Session Handoff Skill

This skill **saves** the current session as a handoff document OR **loads** a previously-written one. Documents are **purely LLM-facing**: do NOT optimize for human readability. Save mode optimizes for: a different LLM, starting cold in a fresh context window, must be able to fully understand the task's mission, state, priorities, constraints, and next steps from the one file alone. Load mode discovers, presents, and consumes such a file.

Documents live at `~/.claude/cache/handoff/{project}-{topic}-{timestamp}.md` (a dedicated subdirectory under `cache/` to keep handoffs isolated from other transient cache content), with an optional companion `{same-basename}.assets/` directory. They are not auto-loaded: load mode is triggered explicitly by the user.

**Invocation arguments** (the only place they are expanded; the rest of this skill calls them "the arguments"): `$ARGUMENTS`

**This session's ID**: `${CLAUDE_SESSION_ID}` (if this still reads as a literal placeholder or is empty, the session ID is unknown).

**Asking the user**: whenever this skill says to ask or confirm, ask in whatever way fits the environment: a plain question in the conversation, or a structured question tool if one is available and suits the choice. Then wait for the reply.

**User profile hints**: the user's profile may already be in your context (e.g. imported by their CLAUDE.md); otherwise read `~/.claude/USER.md` if it exists. Use only what it actually states; where it states nothing relevant (or there is no profile), skip the hint and use the default. This skill uses: a common project root and its container directories (Rule P2), a timezone (Step 6 and every timestamp), organization / employer names (Step 5 privacy scan), and the §2 ORIENTATION fields.

---

## Information routing model

Cross-session knowledge has three homes. Route each fact to ONE home; duplicating across homes causes drift (two copies diverge):

- **Durable project knowledge** (recurring constraints, build/run/test/git workflow, architecture invariants, roadmap/backlog, conventions) → the project's **memory directory** (see "Resolving the project"). Its index is auto-loaded and entries are relevance-injected every session, so it is available WITHOUT a handoff.
- **Transient resume-state** (current HEAD, what was just committed, the in-flight task and exactly where it stopped, this-session-only decisions / dead-ends not yet promoted) → **this handoff**. Loaded on demand only when resuming, so it never pollutes unrelated sessions.
- **Cross-project agent behavior** (how handoffs are written / routed) → this skill.

### Two SAVE modes

- **Lean**: use when the project HAS an established memory store (`MEMORY.md` exists in its memory directory) and/or a handoff-convention memory. Durable knowledge stays in memory; the handoff records ONLY transient state + POINTERS to the canonical memory entries. Any section whose body would duplicate memory is compressed to a one-line pointer. Before writing, PROMOTE any durable fact surfaced this session into memory (create/update the entry) instead of leaving it only in the handoff.
- **Self-contained**: the default when there is NO memory store. The handoff spells everything out and stands alone (the original behavior).

A handoff-convention memory in the project MAY override these defaults (e.g. force lean, or specify the canonical memory list / a keep-vs-delete policy). Honour it.

---

## Resolving the project (shared by SAVE and LOAD)

### Repo root and memory directory

```bash
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ]; then
  REPO_ROOT=$(dirname "$common")   # main worktree; identical for every worktree and subdirectory
else
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi
```

The **memory directory** is per repository, shared across its worktrees and subdirectories (not per cwd). Determine it in this order:

1. The memory directory path the harness states for this session (Claude Code names it in the system prompt). Use it verbatim.
2. Else the `autoMemoryDirectory` setting, if set in the user's Claude Code settings.
3. Else the observed default convention: `~/.claude/projects/$(printf '%s' "$REPO_ROOT" | sed 's/[^A-Za-z0-9]/-/g')/memory/`.

### Project slug

Apply in order. First rule that yields a non-empty, non-sentinel project name wins. Sentinels that always trigger fall-through: project name starts with `_` (a container / grouping prefix), OR equals your home-directory basename (i.e. `$(basename "$HOME")`, usually your username), OR equals `/` or `.claude` (the Claude config directory itself).

#### Rule P1: Git repository

If `git rev-parse --is-inside-work-tree` succeeds:

1. Extract from remote URL (prefer `origin`, else first remote):
   ```bash
   remote=$(git config --get remote.origin.url 2>/dev/null)
   if [ -z "$remote" ]; then
     first_remote=$(git remote | head -n1)
     [ -n "$first_remote" ] && remote=$(git config --get "remote.${first_remote}.url" 2>/dev/null)
   fi
   ```
2. If a remote URL exists: `project=$(basename "$remote" .git)`.
3. If no remote at all: `project=$(basename "$REPO_ROOT")` (the main worktree, so a linked worktree resolves to the same project).
4. Sanity-check `project` against sentinels. If it hits a sentinel, fall through to Rule P2.

#### Rule P2: Known project root (user profile)

Only if the user profile names a common project root (e.g. `~/code/`) and `pwd` is inside it:

1. Take the segments of `pwd` below that root.
2. If the first segment is a container (starts with `_`, or the profile lists it as a grouping / employer directory): use the next segment if one exists; if `pwd` is the container itself, fall through to Rule P3.
3. Else `project` = the first segment.
4. Sanity-check against sentinels; on a hit, fall through to Rule P3.

No profile, no stated root, or `pwd` outside it: fall through to Rule P3.

#### Rule P3: pwd analysis + cache cross-check

1. Extract candidate segments from `pwd`, skipping common non-project directory names:
   `src`, `lib`, `dist`, `build`, `node_modules`, `tests`, `test`, `docs`, `bin`, `worktrees`, `Downloads`, `Desktop`, `Documents`, `Library`, `Applications`, and any segment starting with `.` or `_` (the latter skips container / grouping directories, so the meaningful project segment beneath them wins).
2. For each candidate `c`, check:
   ```bash
   ls ~/.claude/cache/handoff/${c}-*.md 2>/dev/null
   ```
3. **95% confidence rule (this exact condition only)**: exactly one candidate has at least one match in `cache/handoff/`. Use that candidate.
4. Any other outcome (zero matches, multiple candidates with matches, multiple candidates with no clear winner): fall through to Rule P4.

#### Rule P4: Ask the user (SAVE only)

Ask the user to choose the project name, offering:

- Each meaningful pwd segment from Rule P3 (annotate with "(matches existing handoff)" if `cache/handoff/` has any `{segment}-*.md`).
- `general` (default bucket).
- A custom name of their choosing.

Do not proceed until a project name is chosen. LOAD mode never asks here; it falls back to path matching (Load Step 1).

---

## Step 0: Detect mode

Inspect the arguments and the triggering input to decide between SAVE and LOAD mode.

| Signal | Mode |
|---|---|
| Arguments start with `load`, `resume`, or `read` (case-insensitive) | LOAD |
| Triggering natural-language phrase matches the LOAD trigger list | LOAD |
| Bare `/handoff` with no load keyword AND no LOAD-list phrase | SAVE |
| Triggering phrase matches the SAVE trigger list | SAVE |
| Truly ambiguous (e.g. user said only "handoff", "處理交接") | Ask the user before proceeding |

After determining mode:
- **SAVE** → proceed to **Save Mode** section below.
- **LOAD** → strip the `load` / `resume` / `read` keyword from the arguments; any remaining non-empty text is an optional filename / substring filter. Proceed to **Load Mode** section.

**95% confidence rule**: at any point during mode detection, if you are not at least 95% confident of user intent, ask the user. Default to asking rather than guessing.

---

# Save Mode

## Step 1: Parse the arguments

| Input form | Behavior |
|---|---|
| Empty | topic + focus both inferred from session |
| Starts with `topic: <slug>` | topic = `<slug>`, focus = remainder of the arguments |
| Other free text | focus = full text, topic inferred from focus + session |

The `<slug>` must be kebab-case, max ~30 chars. If user-provided slug violates this, normalize it (lowercase, replace spaces / underscores with hyphens, strip non-alphanumeric except hyphens, truncate).

**Inferring topic** when not explicit: pick a short kebab-case slug summarizing the dominant theme of the session (e.g., `migration-debug`, `auth-rewrite`, `rate-limit-fix`). If session is too varied to summarize, use `general`.

---

## Step 2: Determine `<project>`, repo root and memory directory

Follow "Resolving the project" above (Rules P1 → P2 → P3 → P4).

---

## Step 3: Gather session context

**Locate the source transcript** (recorded in §1 so the next agent can look things up):

```bash
SESSION_ID="${CLAUDE_SESSION_ID}"
TRANSCRIPT=$( [ -n "$SESSION_ID" ] && ls ~/.claude/projects/*/"${SESSION_ID}".jsonl 2>/dev/null | head -n1 )
```

If the session ID is unknown or no file matches, record both as `unknown`.

**Recover compacted context**: if this session was compacted (the conversation starts from a summary of earlier work, or earlier turns are otherwise no longer visible), the summary has lost detail: early decisions, rejected alternatives, the user's exact wording. Before writing, read the user's own messages back from the transcript and recover what the summary dropped:

```bash
jq -r 'select(.type=="user" and (.isCompactSummary|not) and (.isMeta|not)) | .message.content | if type=="string" then . else (map(select(.type=="text") | .text) | join("\n")) end | select(length>0)' "$TRANSCRIPT"
```

Use `grep -n '<keyword>' "$TRANSCRIPT"` for anything else (tool output, agent replies). Set §1 `compacted: true` when this applies.

Then internally collect (do not show to user yet):

- **Recent conversation turns**: what the user has been asking, deciding, redirecting
- **File edits made this session**: paths, what changed, why
- **Tool calls made**: especially git operations, deploys, external API calls
- **Git state** (if not in a git repo, note as such):
  ```bash
  git status -sb                     # branch, upstream, ahead/behind
  git rev-parse HEAD; git log -1 --format='%h %s'
  git log --oneline @{upstream}..HEAD 2>/dev/null   # unpushed commits
  git stash list
  git worktree list
  git status --short; git diff --stat HEAD
  ```
- **In-flight work**: the session's task / todo list (every item not completed, with status) and the plan file if one was written (e.g. in plan mode): these feed §14 and §13
- **Session-scoped resources**: background shell commands, monitors, jobs scheduled inside the session, running sub-agents. They end with this session; the next agent must restart what is still needed
- **Session-specific files**: artifacts in the session scratchpad or other session-scoped temporary directories. The next session cannot rely on them; the ones it needs are copied in Step 8
- **Decisions reached + their rationale + rejected alternatives**: with verbatim user quotes where available
- **Dead ends**: things tried that failed, things considered and rejected
- **Open questions**: items needing user input vs items needing investigation
- **Constraints and DON'Ts**: from project memory, from user-stated rules this session, from project's CLAUDE.md / SPEC.md if read this session
- **Artifacts produced**: screenshots, generated files, probe captures, logs, with absolute paths

Apply the focus guidance from the arguments (if any) to weight emphasis: e.g. if focus says "focus on lock contention findings", expand §6 DECISIONS and §8 DEAD ENDS sections around that topic, compress others.

**Select mode + triage** (see "Information routing model"): check whether the project's memory directory has a memory store (`MEMORY.md` exists) and/or a handoff-convention memory → write **lean**; else **self-contained**. Then TRIAGE every fact gathered above into durable vs transient. In lean mode, for each DURABLE fact (recurring constraint / workflow / invariant / architecture / roadmap / backlog), PROMOTE it into memory now (create or update the entry, dedup against what exists) and reference it from §13; do NOT spell it out in the handoff; the doc keeps only transient state.

---

## Step 4: Generate the handoff document

Read `${CLAUDE_SKILL_DIR}/template.md` and produce the document exactly as it specifies: all 15 sections §0 to §14 in order, §0 PROTOCOL embedded verbatim, empty sections kept with `(none)`, the lean-mode compression rules, and the LLM-facing format rules at its end.

---

## Step 5: Privacy scan (warn, do not block)

Sensitive context is often **necessary** for the receiving agent to continue work in progress (project names, organization / employer names, hostnames may all be required for comprehension). The scan therefore **warns** the user but does not force redaction. The post-pickup deletion prompt embedded in §0 PROTOCOL (step 9) provides the leakage safeguard.

Sources of candidates:

- Organization / employer / company names mentioned in this session, plus those the user profile lists (including container directory names that stand for an employer)
- Server hostnames referenced (SSH targets, internal URLs)
- SSH config aliases used
- GitHub owner handles for private repos
- User email if it appears in the content
- Identifiers flagged private in a project privacy/redaction memory entry (e.g. `feedback_repo_privacy.md` in the project's memory directory): read on demand if one exists for the current project

Scan the files that will be copied into `assets_dir` (Step 8) as well as the document.

**If candidates found**: present the list to the user as a warning and ask them to choose:

> "Privacy scan detected potentially sensitive strings in the handoff:
> - `<item>` (N occurrences)
> - `<item>` (N occurrences)
>
> Sensitive context is often necessary for the receiving agent. The recommended flow is to keep these intact: the receiving agent will be prompted to delete the handoff immediately after pickup is confirmed, preventing long-term leakage.
>
> Choose:
> - `continue`: keep all sensitive items, record them in §1 METADATA `sensitive_items` so deletion is prompted strongly at pickup
> - `redact: <items>`: replace specified items with placeholders (`<ORG>`, `<HOST>`, `<HANDLE>`, `<EMAIL>`)
> - `abort`: cancel write"

**If user picks `continue`**: proceed. Ensure §1 METADATA `sensitive_items` field lists each item + count. Ensure §7 CONSTRAINTS includes: `CONSTRAINT: This handoff contains sensitive context (see §1 METADATA sensitive_items). Delete this file immediately after the receiving agent confirms pickup is complete.`

**If user picks `redact`**: apply replacements, re-scan the rewritten content (rewriting may introduce new matches via context expansion). Loop until clean or user explicitly accepts remaining items. Update §1 METADATA `sensitive_items` to reflect what remains (empty list if fully clean).

**If user picks `abort`**: stop, do not write, delete any partially-written file and assets directory, report to user.

**If zero candidates found**: write directly. §1 METADATA `sensitive_items` field is set to `[]`. No prompt.

---

## Step 6: Compute filename and check collision

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
ASSETS_DIR="${FILE%.md}.assets"    # created only if Step 8 copies something

# §1 written_at, ISO 8601 with a colon in the offset (BSD and GNU date)
WRITTEN_AT=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')
```

If the user profile states a timezone, prefix both `date` calls with `TZ=<its IANA name>` (e.g. `TZ=Europe/Berlin`) and use the same zone for every timestamp in the document; otherwise use the system local time zone.

---

## Step 7: Fill in path-dependent metadata

Set §1 `file_path` to `$FILE`, `assets_dir` to `$ASSETS_DIR` (or `none` if nothing will be copied), and point §4 Recent artifacts at the copied locations.

---

## Step 8: Copy assets, write the file, and report

1. If any artifact the next agent needs lives in a session-specific temporary directory, `mkdir -p "$ASSETS_DIR"` and copy it there. Leave large or regenerable files where they are and mark them `TRANSIENT (may be gone)` in §4 instead.
2. Write the full content to `$FILE`.
3. Report to user:

```
Handoff written: <absolute file path>
Assets: <absolute assets dir path, or "none">
Topic: <topic-slug>
Project: <project-slug>
Source session: <session id, or "unknown">
Sections: <number of non-empty sections> populated, <number> marked (none)

To resume in a future session, say one of:
  接續交接
  讀取交接文件
  load handoff
```

Do not list the full handoff content back to the user: they already know what was in the session.

---

# Load Mode

You are loading a handoff written by a previous session. The doc is LLM-facing; once read, you follow the §0 PROTOCOL embedded inside it. The skill's responsibility ends after the file is read: subsequent behavior is governed by §0.

## Step 1: Collect candidates

1. Resolve `project` and `REPO_ROOT` with "Resolving the project" (Rules P1 → P2 → P3; never P4 here). Old handoffs may have been saved under a different slug, so also match by path.
2. Collect the union of, newest first:
   ```bash
   ls -t ~/.claude/cache/handoff/${project}-*.md 2>/dev/null                      # by slug (skip if no project)
   grep -lsxF -e "cwd: $REPO_ROOT" -e "repo_root: $REPO_ROOT" -e "cwd: $PWD" \
     ~/.claude/cache/handoff/*.md                                               # by recorded path
   ```
3. If the arguments carry a filter (any non-empty remainder after the `load` / `resume` / `read` keyword was stripped in Step 0), apply it as a **case-insensitive substring match** against each candidate filename. Reduce the candidate set accordingly.

## Step 2: Present candidates and confirm

For each candidate show: filename, mtime, topic slug, and a §1 METADATA preview (`written_at`, `cwd`, first ~10 lines of the file).

| Candidate count | Action |
|---|---|
| 0 | Tell the user there is no handoff matching `<project>`. Offer the cross-project fallback (Step 3). |
| 1 | Show the candidate and ask the user to confirm loading it. **Never auto-pick, even when N=1.** |
| ≥2 | List the candidates (numbered, newest first) and ask the user which one to load. Offer the cross-project fallback as an extra choice. |

**Confidence rule**: if a user-supplied filter substring-matches multiple candidates, or you are otherwise unsure which file the user means, do not guess; ask.

## Step 3: Cross-project fallback

When invoked (zero matches, OR user explicitly chose to list across projects in Step 2):

```bash
ls -t ~/.claude/cache/handoff/*.md 2>/dev/null | head -n 10
```

List the top 10 (project segment, topic, mtime, filename) and ask the user to pick one or give a custom filename / path.

## Step 4: Read the chosen file and follow §0 PROTOCOL

1. Read the chosen absolute path in full.
2. The file's §0 PROTOCOL is now in your context; follow it. Handoffs written by newer versions of this skill include a drift check, a source-transcript lookup and a deletion prompt; older handoffs may lack some of them, and their own §0 governs.

Skill responsibility ends here. Do not duplicate §0 substeps in this skill.

---

## Examples

### Save mode

**Example 1: bare invocation**

```
/handoff
```

Behavior: SAVE mode. Infer topic and focus from session. Project from "Resolving the project" (git remote name, else main worktree name, else the user profile's project root, else pwd analysis, else ask).

**Example 2: free-text focus**

```
/handoff finish the data-import migration debugging, focus on lock contention and rollback safety
```

Behavior: SAVE mode. Focus = full text. Topic inferred as `migration-debug` or `lock-contention`. Project as in Example 1.

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

Behavior: LOAD mode. Collect `cache/handoff/{project}-*.md` plus files whose §1 `cwd` / `repo_root` matches this repo, list them, ask the user to pick.

**Example 5: load with substring filter**

```
/handoff load api
```

Behavior: LOAD mode. Collect, then filter filenames containing `api` (case-insensitive). If multiple matches, ask which one; if one, still confirm before consuming.

**Example 6: natural-language resume**

```
接續交接
```

Behavior: LOAD mode, equivalent to bare `/handoff load`. No filter.

**Example 7: ambiguous input**

```
handoff
```

Behavior: ambiguous (no slash, no clear save/load phrase). Ask the user which mode before proceeding.

---

## Reminders

### Save mode
- Route by the Information routing model: durable → memory (PROMOTE it, don't just describe it here), transient → this doc. In lean mode (project has a memory store) compress memory-duplicating sections to pointers; never re-spell memory.
- The memory directory is per repository (shared by worktrees and subdirectories), not per cwd.
- If the session was compacted, recover detail from the transcript before writing.
- Record `session_id` and `transcript_path` in §1; include the transcript lookup commands in §12.
- Copy needed session-scoped files into `assets_dir`; list session-scoped resources that end with the session.
- The output document is for an LLM, not a human. Bias toward density, explicitness, and structured markers.
- Never use `~/` paths in the document. Always absolute.
- Never use natural-language dates. Always ISO 8601 with TZ.
- Empty sections stay with `(none)` body; do not omit.
- Always run the privacy scan loop before writing.
- Always check for filename collision and append `-2`, `-3`, etc.
- After writing, do not echo the whole doc back to the user.

### Load mode
- Match candidates by project slug AND by recorded `cwd` / `repo_root`.
- Never auto-pick a candidate, even when only one matches.
- After Step 4 (Read), hand off to the file's §0 PROTOCOL; do not duplicate or override its substeps in this skill.
- When the user supplies a substring filter that matches multiple candidates, ask; do not guess "they probably meant the latest".
