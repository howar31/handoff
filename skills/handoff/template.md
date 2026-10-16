# Handoff document template

The document SAVE mode writes. Read by SKILL.md Save Mode Step 4. Produce all 15 sections (§0 to §14) in order. **Empty sections retain the header with `(none)` as the body**: this tells the receiving LLM the topic was considered, not forgotten.

**Lean mode:** keep every section header, but replace any body that would duplicate the project's memory with a one-line pointer to the canonical entry (e.g. "see `editor-invariants.md`"). Always spell out the TRANSIENT sections (§1 METADATA, §3b current slice, §4 STATE, §5 PRIORITIES, §6 this-session DECISIONS, §8 this-session DEAD ENDS, §9 OPEN QUESTIONS, §14 NEXT ACTIONS); compress the DURABLE sections (§2 ORIENTATION, §7 CONSTRAINTS, §10/§11/§12 where they restate memory) to pointers. §13 READ FIRST is always the pointer list to the canonical memory entries.

---

## §0 PROTOCOL — embed verbatim

Insert exactly this text as section §0:

```
# Handoff Protocol — Read This First

You are an AI agent receiving a session handoff. Before taking any action:

1. Read this entire document end-to-end.
2. Open and read every file listed under §13 READ FIRST in the order given.
3. Check for drift since this handoff was written: compare the current git branch,
   HEAD, upstream ahead/behind, stash and working-tree status against §4 STATE, and
   compare §1 METADATA `written_at` with the current time. Note every difference;
   do not try to reconcile it yet.
4. Mentally confirm you can answer:
   - What is the user's current objective?
   - What is the immediate top priority (§5 PRIORITY 1)?
   - What constraints must you honour (§7)?
   - What dead ends must you not retry (§8)?
5. If this document is unclear, incomplete, or silent on something you need,
   consult the source session before guessing. §1 METADATA `transcript_path` is the
   full original conversation (JSON Lines; the user's own messages are entries with
   "type":"user" whose message content is a string or text blocks; §12 has a
   ready-made extraction command). In Claude Code the source session can also be
   reopened with `claude --resume <session_id>` from §1 `cwd`. The transcript is
   deleted after the tool's retention period; if it is gone, ask the user. Use the
   transcript to look things up, not as a replacement for this document.
6. If anything is still unclear, ask the user before acting.
7. If clear, your first message to the user should be:
   "Handoff consumed. Current top priority: <quote §5 PRIORITY 1>.
   Drift since handoff: <none | summary>. Confirm before I proceed?"
8. Do NOT take any non-readonly action until the user confirms.
9. After the user confirms work is picked up, ask the user whether to delete this
   handoff file (§1 METADATA `file_path`) and its `assets_dir`, if that is not
   "none". If §1 METADATA `sensitive_items` is non-empty, recommend deleting and
   mention the sensitive items count so the user understands the leakage motivation.
```

## §1 METADATA — YAML frontmatter or fenced block

```yaml
project: <project-slug>
topic: <topic-slug>
written_at: <ISO 8601 with TZ, e.g., 2026-05-11T14:30:52+08:00>
session_duration_estimate: <e.g., "~3 hours" or "unknown">
cwd: <absolute path of $(pwd) at handoff time>
repo_root: <main worktree root (shared by all worktrees), or cwd outside git>
generated_by_model: <e.g., the model id of the agent writing this>
session_id: <ID of the session that wrote this handoff, or "unknown">
transcript_path: <absolute path of that session's transcript (JSONL), or "unknown">
compacted: <true if the source session was compacted before this save, else false>
file_path: <the full absolute path this handoff is being written to>
assets_dir: <absolute path of the companion assets directory, or "none">
sensitive_items:        # empty list [] if scan was clean
  - "<item> (N occurrences)"
  - "<item> (N occurrences)"
```

## §2 ORIENTATION

User identity, language preference, environment. The receiving LLM may be told nothing else about who the user is. Include:

- User name, role, location, timezone
- Conversation language preference
- OS, shell, common project root
- Assumed cwd for next session

Pull from the user profile (SKILL.md "User profile hints": what is already in your context, else `~/.claude/USER.md` if it exists). Do not assume any particular identity file exists; omit fields you cannot determine.

## §3 MISSION — three subsections

**(a) Long-term mission**: what the larger project is for, why it exists, who it serves.

**(b) Current session slice + recent intent**: what this session focused on, what user has been actively pushing on in the most recent hours / turns, success criteria for the immediate slice.

**(c) Intentionally deferred from scope**: work explicitly excluded from this session, with reason. Distinct from "pending" or "dead end": this is "we know about it, we chose not to do it now."

## §4 STATE

**Code state**:
- Git branch, and its upstream with ahead/behind counts (or "no upstream")
- Latest commit hash + one-line subject
- Unpushed commits (hash + subject), or "none"
- Stash entries, or "none"
- Worktrees other than the current one (path + branch), or "none"
- Modified / staged / untracked files (absolute paths) + a one-line diff summary per file
- Clean or dirty

State plainly that uncommitted, unpushed and stashed work exists only on this machine.

**System state**:
- Deployed? to where? what version?
- Processes running (relevant ones)
- Secrets / tokens rotated this session? what's the state?
- Migrations applied?

**Session-scoped resources (end with this session)**: background shell commands, monitors / watchers, jobs scheduled inside the session, running sub-agents. For each: what it was doing, its last known result, and how to restart it if still needed. `(none)` if there were none.

**Recent artifacts**: screenshots, probe captures, generated logs, scratch files, with absolute paths. Files that were in a session-specific temporary directory (e.g. the session scratchpad) are listed at their copied location under `assets_dir`. Anything not copied that lives in such a directory is marked `TRANSIENT (may be gone)`.

## §5 PRIORITIES

Top 1–3 priorities for the receiving agent, ordered. Format each as:

```
PRIORITY 1: <action>
  RATIONALE: <why this is top>

PRIORITY 2: <action>
  RATIONALE: <why>

PRIORITY 3: <action>
  RATIONALE: <why>
```

## §6 DECISIONS — this session only

Format per entry:

```
DECISION: <decision>
  RATIONALE: <why this choice>
  REJECTED: <alternative(s) considered + why rejected>
  SOURCE: <verbatim user quote, OR "agent judgment", OR "user-confirmed agent suggestion">
```

Prior-session decisions live in memory or SPEC.md: link them from §13 READ FIRST, do not duplicate.

## §7 CONSTRAINTS

Hard rules. Use markers:

```
CONSTRAINT: <rule>
DO NOT: <action>
INVARIANT: <property that must hold>
```

Include: privacy rules, environment quirks, deployment safety rules, user-explicit DON'Ts, hidden invariants.

## §8 DEAD ENDS — two subsections

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

## §9 OPEN QUESTIONS — two subsections

**(a) NEEDS USER INPUT**: questions only the user can decide. Blocking on user.

**(b) NEEDS INVESTIGATION**: questions an agent can pursue autonomously.

## §10 VERIFICATION

- What was tested in this session (and how)
- What was NOT tested
- Known fragility (likely failure modes)
- Manual smoke-test steps the receiving agent should re-run before risky actions

## §11 LOCATIONS — absolute paths

- Code directories
- Config files
- Log files
- Env vars / secrets locations (`.env` paths, shell exports, secret managers, where API keys live)
- Sensitive-content paths outside the repo (e.g. probe data, sensitive scratch)
- Server paths (SSH targets, remote paths)
- Artifact / probe directories produced this session

## §12 QUICK COMMANDS

Bash one-liners the receiving agent can copy-paste, inside one fenced code block. Format:

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

When `transcript_path` is known, always include this lookup (substitute the real path):

```
# Source session: the user's own messages, in order (needs jq)
jq -r 'select(.type=="user" and (.isCompactSummary|not) and (.isMeta|not)) | .message.content | if type=="string" then . else (map(select(.type=="text") | .text) | join("\n")) end | select(length>0)' <transcript_path>

# Source session: search everything for a keyword
grep -n '<keyword>' <transcript_path>
```

All paths in commands must be absolute.

## §13 POINTERS — two subsections

**(a) READ FIRST** (before acting): list specific files with absolute paths. Includes:
- Project's CLAUDE.md if any
- Project's SPEC.md if any
- Relevant memory entries from the project's memory directory
- The plan file, if this session wrote one (e.g. in plan mode), with a note on how much of it is done
- Any other docs critical to safe action

**(b) REFERENCE MATERIALS** (optional context): external docs, issue tracker / wiki / chat links, upstream documentation.

## §14 NEXT ACTIONS

Concrete ordered steps. Include every task-list item from this session that is not completed (pending or in progress), merged into the order, with its status. Format:

```
STEP 1: <action>
  STATUS: <not started | in progress: what is already done>
  EXPECTED OUTCOME: <what success looks like>
  IF FAILS: <fallback or who to escalate to>

STEP 2: <action>
  STATUS: <...>
  EXPECTED OUTCOME: <...>
  IF FAILS: <...>
```

---

## LLM-facing format rules — apply to all content

| Rule | Detail |
|---|---|
| Paths | Absolute only in the generated document. Expand `~` to the real home path (e.g. `/home/you/.claude/...` or `/Users/you/.claude/...`); never leave a literal `~/` in the doc. |
| Timestamps | ISO 8601 with TZ. E.g. `2026-05-11T14:30:52+08:00`. Never "May 11" / "2pm" / "yesterday". |
| Empty sections | Keep section header, body = `(none)`. Don't omit the section. |
| User quotes | Verbatim where decisions came from user. No paraphrase. Mark with `SOURCE: <quote>` or block-quote. |
| Structured markers | Use `DECISION:`, `CONSTRAINT:`, `DO NOT:`, `INVARIANT:`, `PRIORITY <n>:`, `STEP <n>:`, etc., to enable easy LLM extraction. |
| Abbreviations | Expand on first use. No assumed jargon. |
| Decoration | No emoji. No nested tables. No HTML. Vanilla markdown only. |
| Tool / framework references | Generic terms. "Open the file" not "use the Read tool". Receiving LLM may not be Claude. |
| Standalone-ness | Self-contained mode: spell everything out; the doc must not rely on conversation history, auto-loaded memory, or implicit context. Lean mode: the doc MAY rely on the project's auto-loaded / relevance-injected memory, which it MUST list in §13 READ FIRST, but it must still stand alone for all TRANSIENT state. In both modes the source transcript is a fallback for lookups, never a substitute for writing the state down. |
