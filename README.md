# handoff

[![License](https://img.shields.io/github/license/howar31/handoff?style=flat-square)](LICENSE)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D77655?style=flat-square)](https://claude.com/claude-code)
[![Last Commit](https://img.shields.io/github/last-commit/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/commits/main)
[![Stars](https://img.shields.io/github/stars/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/stargazers)
[![Sponsor](https://img.shields.io/badge/Sponsor-donate.howar31.com-b4532c?style=flat-square&logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTIwLjg0IDQuNjFhNS41IDUuNSAwIDAgMC03Ljc4IDBMMTIgNS42N2wtMS4wNi0xLjA2YTUuNSA1LjUgMCAwIDAtNy43OCA3Ljc4bDEuMDYgMS4wNkwxMiAyMS4yM2w3Ljc4LTcuNzggMS4wNi0xLjA2YTUuNSA1LjUgMCAwIDAgMC03Ljc4eiIvPjwvc3ZnPg==)](https://donate.howar31.com/)

A [Claude Code](https://claude.com/claude-code) skill that **saves a session as a handoff document** and **loads one back** so a fresh agent — even a different model, starting cold in an empty context window — can pick up exactly where the last one stopped.

The handoff is one self-contained, LLM-facing Markdown file. It captures the mission, current state, decisions (with rationale and rejected alternatives), dead ends, hard constraints, open questions, and ordered next actions — everything the next agent needs to act safely without the original conversation.

## How it works

| Mode | Trigger | What it does |
|---|---|---|
| **Save** | `/handoff` (+ optional focus or `topic: <slug>`) | Gathers the session's context, runs a privacy scan, and writes `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md` |
| **Load** | `/handoff load` (+ optional filename filter) | Autodiscovers handoffs for the current project, confirms which one with you, reads it, then follows the protocol the document embeds in its own §0 |

The skill is **model-invoked** — once installed, Claude can trigger it from the `description` (and it responds to natural-language phrases like "做交接" / "create a handoff" / "接續交接" / "load handoff"); the slash names below matter when you invoke it by hand.

### What's in a handoff

A 15-section document built for machine extraction, not human reading: `§0 PROTOCOL` (read-this-first instructions for the receiving agent), `§1 METADATA`, `§2 ORIENTATION`, `§3 MISSION`, `§4 STATE`, `§5 PRIORITIES`, `§6 DECISIONS`, `§7 CONSTRAINTS`, `§8 DEAD ENDS`, `§9 OPEN QUESTIONS`, `§10 VERIFICATION`, `§11 LOCATIONS`, `§12 QUICK COMMANDS`, `§13 POINTERS`, `§14 NEXT ACTIONS`. Empty sections are kept with a `(none)` body so the next agent knows a topic was considered, not forgotten.

### Source session and pickup checks

The handoff records the ID and transcript path of the session that wrote it. When the document leaves something unclear, the receiving agent looks it up in that transcript, or reopens the session with `claude --resume <id>`, until Claude Code's transcript retention period removes it. If the session was compacted before saving, the save step reads the earlier messages back from the transcript first.

On load, before its first message, the receiving agent compares the current git branch, HEAD, upstream and working tree with the recorded state, and reports any drift. Files that lived only in the session's temporary scratch space are copied next to the handoff, and background tasks that end with the session are listed so they can be restarted.

### Privacy by design

Handoffs often *need* sensitive context (project names, hostnames) to be useful, so the save step **warns rather than blocks**: it lists detected sensitive strings, lets you keep / redact / abort, and records what was kept. On load, after you confirm pickup, the receiving agent is prompted to **delete the file** — bounding how long any private context lives on disk. Handoff files live under your `~/.claude/cache/` and are never part of this repo.

### Pairs with project memory

The skill routes knowledge to one home to avoid drift: durable project knowledge stays in Claude Code's auto-loaded memory, transient resume-state goes in the handoff. When a project already has a memory store, save runs in **lean** mode — recording only transient state plus pointers to the canonical memory entries instead of duplicating them.

### Optional user profile

If your profile is available, either in Claude Code's context (for example imported by your `CLAUDE.md`) or as `~/.claude/USER.md`, save uses what it states: a common project root and container directories for project naming, a timezone for timestamps, and organization names for the privacy scan. Without a profile, save uses the git remote name, the system time zone and what appears in the session.

## Install

The skill is **model-invoked**: once installed, Claude triggers it from the `description`; the slash name below only matters when you invoke it by hand. Three ways to install. **Use only one**: `setup.sh` and `npx skills` both write `~/.claude/skills/handoff`, and the plugin manager exposes the same skill under a second name.

### setup.sh — symlink (recommended; shortest slash name)

```bash
git clone https://github.com/howar31/handoff
cd handoff && ./setup.sh
```

Symlinks `skills/handoff` into `~/.claude/skills/`, so the skill is invoked as **`/handoff`** (no namespace prefix) and the repo stays the single source of truth. Idempotent; backs up before any destructive action:

```bash
./setup.sh --dry-run   # preview without applying
./setup.sh --force     # replace an existing real directory at the skill path (backed up first)
```

### Plugin manager — marketplace (discoverable, auto-updating)

Installs the same skill, namespaced as **`/handoff:handoff`**. Two registration paths — pick one:

```bash
# Self-hosted marketplace (this repo is its own marketplace)
claude plugin marketplace add howar31/handoff
claude plugin install handoff@handoff

# Or the central marketplace (all of howar31's plugins; register once)
claude plugin marketplace add howar31/howar31-marketplace
claude plugin install handoff@howar31
```

### npx skills

Installs the skill with the cross-agent [`npx skills`](https://github.com/vercel-labs/skills) CLI, invoked as **`/handoff`**:

```bash
npx skills add howar31/handoff -g -a claude-code
npx skills update handoff -g          # update later
```

Pass `-a claude-code`: without it the CLI offers every agent it detects, and the skill does not limit where it can be installed. It is written for Claude Code. In other agents, saving and loading are expected to work in self-contained mode only: project memory (lean mode) and the source-session lookup rely on Claude Code, and this has not been tested in other agents.

### Which method?

| | setup.sh (symlink) | npx skills | plugin manager |
|---|---|---|---|
| Slash name | `/handoff` (shortest) | `/handoff` | `/handoff:handoff` |
| Install / update | clone + re-run `setup.sh` | `npx skills add` / `update` | `claude plugin install` / `update` |
| Discoverable via marketplace | no | no | yes |

Either way, skills are picked up dynamically — run `/reload-plugins` in an active session if `handoff` does not appear immediately.

## Usage

```bash
/handoff                                   # save: infer topic + focus from the session
/handoff topic: rollback-safety            # save: explicit topic slug
/handoff finish the migration debugging    # save: free-text focus weights the emphasis

/handoff load                              # load: pick from this project's handoffs
/handoff load api                          # load: filter candidates by substring
```

Natural language works too — "做交接" / "save context for handoff" to save, "接續交接" / "continue from previous session" to load.

## Uninstall

```bash
# setup.sh install (the replaced real dir, if any, is in ~/.claude/skills/.bak/<timestamp>/)
rm ~/.claude/skills/handoff

# npx skills install
npx skills remove handoff -g

# Plugin install
claude plugin uninstall handoff@handoff   # or handoff@howar31
```

## License

MIT — see [LICENSE](LICENSE).
