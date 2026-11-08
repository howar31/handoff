# Handoff document template

The document SAVE mode writes. Read by SKILL.md Save Mode Step 4. Produce all 15 sections (§0 to §14) in order. **Empty sections retain the header with `(none)` as the body**: this tells the receiving LLM the topic was considered, not forgotten.

**Lean mode:** keep every section header, but replace any body that would duplicate the project's memory with a one-line pointer to the canonical entry (e.g. "see `editor-invariants.md`"). Always spell out the TRANSIENT sections (§1 METADATA, §3b current slice, §3d recent exchange, §4 STATE including its watchers and collaborating sessions, §5 PRIORITIES, §6 this-session DECISIONS, §8 this-session DEAD ENDS, §9 OPEN QUESTIONS, §14 NEXT ACTIONS); compress the DURABLE sections (§2 ORIENTATION except its LANGUAGE line, §7 CONSTRAINTS except its PROCEDURE lines, §10/§11/§12 where they restate memory) to pointers. §13 READ FIRST is always the pointer list to the canonical memory entries, plus its WORKING SET spelled out.

---

## §0 PROTOCOL — embed verbatim

Insert exactly this text as section §0:

```
# Handoff Protocol — Read This First

You are an AI agent receiving a session handoff. Before taking any action:

1. Read this entire document end-to-end.
2. Open and read every file listed under §13 READ FIRST in the order given.
3. Check for drift since this handoff was written: compare the current git branch,
   HEAD, upstream ahead/behind, stash and working-tree status against §4 STATE,
   re-run the re-check command of every §4 External state item, and compare
   §1 METADATA `written_at` with the current time. Note every difference; do not
   try to reconcile it yet.
4. Mentally confirm you can answer:
   - What is the user's current objective?
   - What is the immediate top priority (§5 PRIORITY 1)?
   - What constraints and procedures must you honour (§7)?
   - What dead ends must you not retry (§8)?
   - Which watchers and collaborating sessions are yours now (§4)?
5. Pickup report. If this handoff reached you in a message from the source
   session and you can message other agent sessions, reply to that sender now,
   before asking the user anything, with one line in the agent-to-agent language
   (§2 LANGUAGE):
   PICKUP <file name> | P1: <§5 PRIORITY 1 in your own words> | lang: <user-facing language from §2> | drift: <none | summary>
   The keywords PICKUP, MATCH, MISMATCH, DEFERRED, CONFIRMED and the field labels stay
   literal in every language; only the free text is translated. Wait for the
   source's answer before step 7. MATCH needs no reply. MISMATCH carries the
   correct values: use them. If no answer comes (the source is unreachable, or
   the user writes first), continue with step 7 and say the check is pending; if
   a MISMATCH arrives after you already asked the user, send the corrected
   summary and ask again.
6. If this document is unclear, incomplete, or silent on something you need, find
   out before guessing, in this order:
   a. Ask the source session if it is still running and you can message it (the
      sender of the message that delivered this handoff, or §1 `session_name`).
      It still holds the full context; its answer reflects its current state.
   b. Read the source transcript: §1 METADATA `transcript_path` (JSON Lines; the
      user's own messages are entries with "type":"user" whose message content is
      a string or text blocks; §12 has a ready-made extraction command). It is the
      authority for the user's exact words. Entries after §1 `transcript_anchor`
      were written after this document. In Claude Code the source session can
      also be reopened with `claude --resume <session_id>` from §1 `cwd`. The
      transcript is deleted after the tool's retention period.
   c. Ask the user.
   Use these to look things up, not as a replacement for this document.
7. Write every message to the user in the user-facing language from §2 LANGUAGE,
   including one-line progress notes and replies that follow English tool or agent
   output. Your first message summarizes, in your own words: the objective, §5
   PRIORITY 1, the drift found in step 3, the watchers you would take over, and
   asks the user two things together, before you proceed:
   a. Take over? (options: take over, not yet; the free-text answer carries any
      change.)
   b. When to delete this handoff file (§1 METADATA `file_path`) and its
      `assets_dir`, if that is not "none"? (options: when this work is done, now,
      keep.) Recommend "when this work is done": until then the file is what you
      re-read after your own context is compacted (step 12). If §1 METADATA
      `sensitive_items` is non-empty, mention the sensitive items count and
      recommend against keep, so the user understands the leakage motivation.
   If you have the `AskUserQuestion` tool, ask both in one call and repeat that
   summary, shortened, in the first question, since the user may see only the
   questions. Otherwise ask in plain text. After "not yet", the answer to b does
   not apply: ask both again when the user is ready. If this handoff was
   delivered by message, also send the source one line: DEFERRED <file name>.
   The source keeps the work, its watchers and its collaborating sessions until
   you send CONFIRMED.
8. Do NOT take any non-readonly action until the user confirms. Do not start a §4
   watcher the source session may still be running until the source confirms it
   has stopped it, or the source is unreachable and the user agrees. The source's
   stop message carries each watcher's final cursor (resume from it, not from §4)
   and the watcher events it handled after writing this document: treat those as
   part of this handoff. After starting the watchers, record in `MONITORS.md` that
   this session now runs them and from which cursor. If §1 `delivered_to` names a session other
   than you, that session may already own this work: ask the user before taking
   over its watchers or collaborating sessions.
9. After the user confirms, if this handoff was delivered by message, send the
   source one line: CONFIRMED <file name>. The source then redirects the sessions
   in §4 COLLABORATING SESSIONS to you and stops its watchers. If this handoff was
   not delivered by message, or the source is unreachable, tell those sessions
   yourself, one line each: what you now own and what to send you, including any
   messages they queued while the source was handing off (§4 OPEN); if you cannot
   message other sessions, list them for the user instead.
10. If the user took over and chose "now" in step 7: once the source has reported
    its watchers stopped (or is unreachable, or there were none), delete the file
    and its `assets_dir`. With "when this work is done", delete them at the time
    step 12 names. Before deleting, move anything in `assets_dir` that is
    still needed (scripts a watcher runs, reusable probes) to a durable location
    and update any reference to it.
11. If the user took over and you can message other agent sessions, end your
    report to the user with this session's own name, as those tools report it,
    in a command the user can copy (in Claude Code: /rename <name>). Only the
    user can run it; a message from another session cannot rename this one.
12. Compaction anchor. If the user took over and did not choose "now" in step 7,
    and your tool reloads a persistent store into your context after it compacts
    the conversation (in Claude Code: the project's auto memory index,
    MEMORY.md), add one entry there before you end your report to the user:
    Active handoff for session <your session ID, else your session name>:
    <§1 file_path>. After a context compaction in that session, re-read its
    §5, §7 and §14 before acting. Other sessions ignore this entry.
    In Claude Code, write it as a memory entry named active-handoff-<§1 topic>
    in the memory format your instructions give, and make its MEMORY.md index
    line carry the whole instruction on its own (your session ID, the file
    path, re-read §5, §7 and §14 after compaction): after a compaction only the
    index is sure to be reloaded. The work
    is done when §14 is complete, when the user says so, or when a new handoff
    you write supersedes this one: then remove the entry, and with "when this
    work is done" delete the file and its `assets_dir` (step 10). Without such a
    store, skip this step.
```

## §1 METADATA — YAML frontmatter or fenced block

```yaml
project: <project-slug>
topic: <topic-slug>
written_at: <ISO 8601 with TZ, e.g., 2026-05-11T14:30:52+08:00>
cwd: <absolute path of $(pwd) at handoff time>
repo_root: <main worktree root (shared by all worktrees), or cwd outside git>
generated_by_model: <e.g., the model id of the agent writing this>
session_id: <ID of the session that wrote this handoff, or "unknown">
session_name: <the name other sessions use to message the writing session, or "unknown">
delivered_to: <name of the session this handoff was sent to, or "none">
transcript_path: <absolute path of that session's transcript (JSONL), or "unknown">
transcript_anchor: <"line <N>, uuid <uuid>": the transcript's line count and its last entry uuid when this file was written, or "unknown">
compacted: <true if the source session was compacted before this save, else false>
file_path: <the full absolute path this handoff is being written to>
assets_dir: <absolute path of the companion assets directory, or "none">
sensitive_items:        # empty list [] if scan was clean
  - "<item> (N occurrences)"
  - "<item> (N occurrences)"
```

## §2 ORIENTATION

User identity, language preference, environment. The receiving LLM may be told nothing else about who the user is. Start with this required line:

```
LANGUAGE: user-facing = <language for every message to the user, including one-line progress notes>; agent-to-agent = <language for messages to other agents, if the user's rules set one, else "same as user-facing">
```

Then include:

- User name, role, location, timezone
- OS, shell, common project root
- Assumed cwd for next session

Pull from the user profile (SKILL.md "User profile hints": what is already in your context, else `~/.claude/USER.md` if it exists) and from what the user said this session. Do not assume any particular identity file exists; omit fields you cannot determine. In lean mode, keep the LANGUAGE line plus anything that differs from the profile, and point to the profile for the rest.

## §3 MISSION — four subsections

**(a) Long-term mission**: what the larger project is for, why it exists, who it serves.

**(b) Current session slice + recent intent**: what this session focused on, what user has been actively pushing on in the most recent hours / turns, success criteria for the immediate slice.

**(c) Intentionally deferred from scope**: work explicitly excluded from this session, with reason. Distinct from "pending" or "dead end": this is "we know about it, we chose not to do it now."

**(d) Recent exchange (verbatim)**: the last part of the conversation, copied, not summarized, because the latest turns are where a summary most often drifts. The user's last 5 messages before the one that asked for this handoff, oldest first, then that request, marked `(the handoff request)`, then what you wrote to the user between the previous of those messages and the request (your replies, including turns started by peer messages or task notifications), headed by its last timestamp. Each item is a block quote headed by its ISO 8601 timestamp, its text copied unchanged: the only cuts are a user message over 2,000 characters, cut at its end, and the reply, cut at its start, each marked `[truncated: transcript line <N>]`. Answers the user gave to choice questions count as messages. Leave out tool output and system-injected text. This subsection reflects the moment of writing: §5 and §14 stay the authority for what to do next.

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

**External state** (pull requests, reviews, deploys, tickets, anything that changes outside this machine): each item with its state as checked immediately before writing, and the command that re-checks it.

```
EXTERNAL: <item>
  STATE: <state at written_at>
  RECHECK: <command>
```

**WATCHERS AND BACKGROUND WORK** (end with this session): monitors / watchers, polls, background shell commands, jobs scheduled inside the session, running sub-agents. `(none)` if there were none.

Monitors / watchers / polls are defined in the project's `MONITORS.md` (SKILL.md Step 3 creates or updates it), so their definitions survive any number of handoffs. Each entry there carries:

```
WATCHER: <name>
  PURPOSE: <why it runs, including any document it keeps current>
  TARGET: <what it watches, with IDs (channel, thread, PR, service, ...)>
  CADENCE: <poll interval, re-arm rule>
  CURSOR STORE: <file the watcher keeps its last-seen marker in, or "none (events between stop and restart are missed)">
  RESTART: <command or procedure, with absolute paths>
  REPORTING: <what it reports, to whom, and when it stays silent>
```

This block gives the absolute path of `MONITORS.md` (also listed in §13 READ FIRST) and, per watcher, only the transient part:

```
WATCHER: <name, as in MONITORS.md>
  STATUS: <continue (receiver restarts it) | paused by user until <condition> | stopped>
  CURSOR: <last-seen marker at written_at; the source sends the final one when it stops the watcher>
```

Background shell commands, scheduled jobs and sub-agents that are not monitors are listed here directly: what each was doing, its last known result, and how to restart it if still needed.

**COLLABORATING SESSIONS**: other agent sessions this session worked with (sent messages to or received messages from). `(none)` if there were none. For each:

```
PEER: <session name, as other sessions address it>
  OWNS: <what that session is responsible for>
  AGREEMENT: <each standing agreement, with direction and trigger, e.g. "send it one line on start / finish / block and after every deploy", "it does NOT relay individual findings (user's decision)">
  OPEN: <requests pending in either direction, messages awaiting a reply, or "none">
```

Session names can change; the receiving agent re-resolves them with its session list before sending.

**Recent artifacts**: screenshots, probe captures, generated logs, scratch files, with absolute paths. Files that were in a session-specific temporary directory (e.g. the session scratchpad) are listed at their copied location under `assets_dir`. Anything not copied that lives in such a directory is marked `TRANSIENT (may be gone)`.

## §5 PRIORITIES

Top 1–3 priorities for the receiving agent, ordered. These name the goals; §14 holds the ordered steps, so do not restate the steps here. Format each as:

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
PROCEDURE: <what the receiving agent must do without being asked, and when>
```

Include: privacy rules, environment quirks, deployment safety rules, user-explicit DON'Ts, hidden invariants. `PROCEDURE:` lines carry the working mode the user set: update cadences ("update and publish the report after every result, and at the start of any work"), delegation mode, notification duties, how to iterate ("one exact edit, then one rebuild"). Write each one out in full, one line each, even in lean mode: a pointer alone is not acted on.

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
- Reusable tools (watch scripts, probes, backtests) kept in a durable git-excluded project folder rather than in `assets_dir`, which is deleted after pickup

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

When `transcript_path` is known, always include this lookup (substitute the real path; plain `grep -n` on the same file searches everything else):

```
# Source session: the user's own messages, slash commands and choice answers, in order (needs jq)
jq -c 'select(.type=="user" and (.isCompactSummary|not) and (.isMeta|not)) | {line: input_line_number, ts: .timestamp} + (if (.toolUseResult|type)=="object" and (.toolUseResult.answers|type)=="object" then {kind: "choice", text: (.toolUseResult.answers | to_entries | map("Q: \(.key[0:80]) A: \(.value)") | join("\n"))} else {kind: "message", text: (.message.content | if type=="string" then . else (map(select(.type=="text") | .text) | join("\n")) end)} end) | select(.text | length > 0) | select((.text | startswith("<") | not) or (.text | startswith("<command-"))) | if (.text | startswith("<command-")) then .text = ([(.text | capture("<command-name>(?<n>[^<]*)</command-name>").n), (.text | capture("<command-args>(?<a>[^<]*)</command-args>").a)] | map(select(. != null and . != "")) | join(" ")) else . end' <transcript_path>
```

All paths in commands must be absolute.

## §13 POINTERS — two subsections

**(a) READ FIRST** (before acting): list specific files with absolute paths. Includes:
- Project's CLAUDE.md if any
- Project's SPEC.md if any
- Relevant memory entries from the project's memory directory
- The project's `MONITORS.md`, when §4 lists any watcher
- The plan file, if this session wrote one (e.g. in plan mode), with a note on how much of it is done
- Any other docs critical to safe action

End (a) with the WORKING SET: up to 5 files this session read or edited that the §14 steps act on, most relevant to STEP 1 first (most recently modified breaks ties). List them even when §4 already lists them as modified. Format each as:

```
WORKING SET: <absolute path>[:<start>-<end> when only that range matters]
  WHY: <what the next step does with it>
```

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
