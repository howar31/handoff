# handoff

[![License](https://img.shields.io/github/license/howar31/handoff?style=flat-square)](LICENSE)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D77655?style=flat-square)](https://claude.com/claude-code)
[![Conventional Commits](https://img.shields.io/badge/conventional%20commits-1.0.0-yellow?style=flat-square)](https://www.conventionalcommits.org)
[![Last Commit](https://img.shields.io/github/last-commit/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/commits/main)
[![Stars](https://img.shields.io/github/stars/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/stargazers)
[![Open Issues](https://img.shields.io/github/issues/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/issues)
[![Sponsor](https://img.shields.io/badge/Sponsor-donate.howar31.com-b4532c?style=flat-square&logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTIwLjg0IDQuNjFhNS41IDUuNSAwIDAgMC03Ljc4IDBMMTIgNS42N2wtMS4wNi0xLjA2YTUuNSA1LjUgMCAwIDAtNy43OCA3Ljc4bDEuMDYgMS4wNkwxMiAyMS4yM2w3Ljc4LTcuNzggMS4wNi0xLjA2YTUuNSA1LjUgMCAwIDAgMC03Ljc4eiIvPjwvc3ZnPg==)](https://donate.howar31.com/)

English | [正體中文](README.zh-Hant.md)

A [Claude Code](https://claude.com/claude-code) skill that **saves a session as a handoff document** and **loads one back**, so a fresh agent, even a different model starting in an empty context window, can continue where the last one stopped. The handoff is one LLM-facing Markdown file. No hook, no MCP server, no external service.

## What you get

### Save: `/handoff`

Gathers the session's mission, current state, decisions (with rationale and rejected alternatives), dead ends, hard constraints, open questions and ordered next actions, runs a privacy scan, and writes `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md`.

```text
/handoff                    → infer topic and focus from the session
/handoff <focus>            → weight the document toward the focus
/handoff topic: <slug>      → set the topic slug explicitly
```

### Load: `/handoff load`

Finds the handoffs for the current project (by project name, and by the directory each handoff recorded), shows them, and asks which one to load. It never picks one on its own, even when there is only one. After reading the file, the receiving agent follows the protocol embedded in the document's own §0.

```text
/handoff load               → pick from this project's handoffs
/handoff load <filter>      → narrow the candidates by filename substring
```

Both modes are model-invocable: natural-language requests such as "create a handoff" / 「做交接」 or "load handoff" / 「接續交接」 trigger them too.

### What's in a handoff

A 15-section document built for machine extraction, not human reading: `§0 PROTOCOL` (read-this-first instructions for the receiving agent), `§1 METADATA`, `§2 ORIENTATION`, `§3 MISSION`, `§4 STATE`, `§5 PRIORITIES`, `§6 DECISIONS`, `§7 CONSTRAINTS`, `§8 DEAD ENDS`, `§9 OPEN QUESTIONS`, `§10 VERIFICATION`, `§11 LOCATIONS`, `§12 QUICK COMMANDS`, `§13 POINTERS`, `§14 NEXT ACTIONS`. Empty sections keep a `(none)` body, so the next agent knows a topic was considered, not forgotten.

### Source session and pickup checks

The handoff records the ID and transcript path of the session that wrote it. When the document leaves something unclear, the receiving agent looks it up in that transcript, or reopens the session with `claude --resume <id>`, until Claude Code's transcript retention period removes it. If the session was compacted before saving, the save step reads the earlier messages back from the transcript first.

On load, before its first message, the receiving agent compares the current git branch, HEAD, upstream and working tree with the recorded state, and reports any drift. Files that lived only in the session's temporary scratch space are copied next to the handoff, and background tasks that end with the session are listed so they can be restarted.

### Privacy

Handoffs often need sensitive context (project names, hostnames) to be useful, so the save step warns instead of blocking: it lists detected sensitive strings and lets you keep, redact or abort, and records what was kept. On load, after you confirm pickup, the receiving agent asks whether to delete the file, and recommends deleting when sensitive items were kept. Handoff files live under your `~/.claude/cache/` and are never part of this repo.

### Pairs with project memory

Each fact goes to one place: durable project knowledge stays in Claude Code's auto-loaded project memory, transient resume-state goes into the handoff. When the project already has a memory store, save runs in **lean** mode: it moves durable facts from the session into memory and records only transient state plus pointers to the memory entries. Without a memory store, the handoff spells everything out (**self-contained** mode).

### Optional user profile

If your profile is available, either in Claude Code's context (for example imported by your `CLAUDE.md`) or as `~/.claude/USER.md`, save uses what it states: a common project root and container directories for project naming, a timezone for timestamps, and organization names for the privacy scan. Without a profile, save uses the git remote name, the system time zone and what appears in the session.

## Architecture

```
/handoff        -->  gather session state; triage durable vs transient
                     (lean mode promotes durable facts into memory);
                     privacy scan; write the document

/handoff load   -->  find this project's handoffs; confirm the choice;
                     read it; follow its §0 protocol (drift check,
                     source-session lookup, deletion prompt)
```

Files involved:

```
~/.claude/skills/handoff/                       the skill (symlink → repo)
~/.claude/cache/handoff/<name>.md               handoff documents
~/.claude/cache/handoff/<name>.assets/          copied session files (only when needed)
```

No hook is installed and `settings.json` is not modified.

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/howar31/handoff
```

The location is up to you; the installer resolves its own path and works from anywhere.

### 2. Install

```bash
cd handoff && ./setup.sh
```

The installer symlinks `skills/handoff` into `~/.claude/skills/`, so the skill is invoked as **`/handoff`** (no namespace prefix) and the repo stays the single source of truth. It is idempotent and safe to re-run. If a real directory already exists at the skill path, it stops with a message; `--force` backs that directory up to `~/.claude/skills/.bak/<timestamp>/` and replaces it.

### 3. Verify

```bash
./setup.sh             # re-run any time; reports all checks or what is wrong
./setup.sh --dry-run   # preview without applying
./setup.sh --force     # replace an existing real directory at the skill path (backed up first)
```

### 4. Use it

Skills are picked up dynamically; run `/reload-plugins` in an active session if `/handoff` does not appear immediately. No restart is required.

## Other install methods

### Plugin manager

Installs the same skill through Claude Code's plugin manager. Plugin-managed skills are **namespaced**, so it appears as **`/handoff:handoff`**. Two registration paths install the same plugin; pick one.

**Self-hosted marketplace** (this repo is its own marketplace):

```bash
claude plugin marketplace add howar31/handoff
claude plugin install handoff@handoff
```

**Central marketplace** (all of howar31's plugins; register once, future plugins appear automatically):

```bash
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

### Which install method?

| | `setup.sh` (symlink) | npx skills | plugin manager |
|---|---|---|---|
| Slash name | `/handoff` (shortest) | `/handoff` | `/handoff:handoff` |
| Install / update | clone + re-run `setup.sh` | `npx skills add` / `update` | `claude plugin install` / `update` |
| Discoverable | no | no | yes (via marketplace) |

Install only one method: `setup.sh` and `npx skills` both write `~/.claude/skills/handoff`, and the plugin manager exposes the same skill under a second name.

## What you'll see

After `/handoff`, Claude reports the written file path, the assets directory (or `none`), the topic, the project, the source session ID, and how many sections were filled. It does not print the document back.

After `/handoff load` and your choice, the receiving agent reads the file and the files it lists under §13, then opens with `Handoff consumed. Current top priority: …`, any drift since the handoff, and a request to confirm. It takes no write action until you confirm, and then asks whether to delete the handoff.

## Backup

The skill directory in `~/.claude/skills/` is a symlink back into the repo, so the repo is the single source of truth and any backup that includes the clone covers it. Handoff documents under `~/.claude/cache/handoff/` are meant to be short-lived and are deleted after pickup when you agree; do not rely on them as a record.

## Uninstall

```bash
# setup.sh install (the replaced real dir, if any, is in ~/.claude/skills/.bak/<timestamp>/)
rm ~/.claude/skills/handoff

# npx skills install
npx skills remove handoff -g

# Plugin install
claude plugin uninstall handoff@handoff   # or handoff@howar31
```

There is nothing to undo in `settings.json`. Existing handoff documents stay in `~/.claude/cache/handoff/` until you delete them.

## Reference

- [SPEC.md](SPEC.md): architecture, data model, conventions, verification, design decisions
- [CLAUDE.md](CLAUDE.md): agent index for working in this repo

## License

MIT. See [LICENSE](LICENSE).
