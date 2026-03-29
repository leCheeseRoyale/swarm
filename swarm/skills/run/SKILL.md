---
name: run
description: Use to start an autonomous multi-agent development swarm from a plan or task list. Triggers on "run the swarm", "execute this plan with agents", "build this autonomously", "start the swarm", or /swarm:run.
argument-hint: "[--team <name>] <plan or task list>"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent"]
---

# Start Swarm

The user has provided a development plan. Parse it into a task queue, wire up the hook-driven state machine, and hand off to the orchestrator. You do not implement anything yourself.

## Steps

### 1. Ensure Git

Worktrees require a git repository. Check if in one; if not:

```bash
git init && git add -A && git commit -m "initial commit before swarm" --allow-empty
```

### 2. Select Team

Check if the user specified a team (e.g., `--team fullstack` or `--team research`).
If not specified, default to `dev`.

Resolve the team config by checking these locations in order (first match wins):

1. **Project-local**: `.swarm/teams/<name>.json`
2. **User-global**: `~/.claude/swarm/teams/<name>.json`
3. **Built-in**: `${CLAUDE_PLUGIN_ROOT}/teams/<name>.json`

If not found in any location, tell the user and suggest `/swarm:team` to create one.

Read the team JSON to understand the pipeline stages.

### 3. Parse the Plan

Break the user's input into discrete tasks. Each task must be:

- **Isolated** — implementable without colliding with other tasks
- **Atomic** — completable in a single agent session
- **Specific** — an agent can execute it without asking questions

Identify dependencies: if task B requires output from task A, B depends on A.

### 4. Create Queue

Create the `.swarm/` directory. Write these files:

**`.swarm/team.json`** — copy the selected team config.

**`.swarm/state.json`**:

```json
{
  "id": "swarm-<unix-timestamp>",
  "state": "RUNNING",
  "team": "<team-name>",
  "created": "<ISO-8601>",
  "updated": "<ISO-8601>",
  "tasks": [
    {
      "id": "1",
      "title": "<short title>",
      "description": "<detailed spec for the agent>",
      "status": "PENDING",
      "stage": null,
      "stage_index": 0,
      "dependencies": [],
      "worktree": null,
      "branch": null,
      "result": null,
      "feedback": null,
      "attempts": 0
    }
  ]
}
```

**`.swarm/events.jsonl`** — initialize empty. Orchestrator appends events as audit trail.

### 5. Wire Up Hooks

This is what makes each team a hook-driven state machine. Generate hookify rules from the team config. These are hot-reloadable — no restart needed.

**Generate `.claude/hookify.swarm-guard.local.md`:**

```markdown
---
name: swarm-guard
enabled: true
event: stop
action: block
---

SWARM ACTIVE — Before stopping, read .swarm/state.json. If any task still has status other than DONE or FAILED, you MUST NOT stop. Continue processing the queue. Only stop when all tasks are DONE or FAILED and the machine state has been updated accordingly.
```

**Generate `.claude/hookify.swarm-safety.local.md`:**

```markdown
---
name: swarm-safety
enabled: true
event: bash
action: warn
conditions:
  - field: command
    operator: regex_match
    pattern: git\s+(push|reset\s+--hard|clean\s+-f)|rm\s+-rf
---

Destructive command detected during swarm execution. The swarm orchestrator manages git operations (branching, merging worktrees). Do not run destructive git or file commands while the swarm is active unless explicitly resolving a failure.
```

**Generate `.claude/hookify.swarm-context.local.md`:**

```markdown
---
name: swarm-context
enabled: true
event: prompt
action: warn
---

SWARM SESSION ACTIVE — Team: <team-name> (<stage1> → <stage2> → ...). Check .swarm/state.json for current queue state before responding to the user. The orchestrator manages all agent dispatch — do not manually write code or spawn agents outside the swarm pipeline.
```

The plugin's `hooks/hooks.json` provides the deterministic layer — the bash guard script reads `.swarm/state.json` and blocks Write/Edit when no task is in an active stage. The hookify rules above provide the session-awareness layer.

### 6. Display Queue

Show the parsed queue, selected team, and active hooks:

```
Team: dev (code → review)
Hooks: swarm-guard (stop gate), swarm-safety (bash guard), swarm-context (session context)

| # | Title              | Depends On | Status  |
|---|--------------------|------------|---------|
| 1 | Create user model  | —          | PENDING |
| 2 | Add auth endpoints | 1          | PENDING |

Spawning orchestrator...
```

### 7. Launch Orchestrator

Spawn the orchestrator agent:

- `subagent_type`: `swarm:orchestrator`
- `prompt`: Include all of this:
  - State file path: `.swarm/state.json`
  - Team config path: `.swarm/team.json`
  - Event log path: `.swarm/events.jsonl`
  - Project root: `<absolute path to cwd>`
  - Instruction: `"Process all tasks to completion. For each task, follow the team pipeline stages in order. Dispatch stage agents using the Agent tool — use subagent_type from the stage config and isolation: worktree where specified. Update state.json after every transition. Log every event to events.jsonl."`

Do NOT intervene while the orchestrator runs unless it returns an error.

### 8. Cleanup and Report

When the orchestrator returns:

**Disable hookify rules** — set `enabled: false` in each generated rule file, or delete them:
- `.claude/hookify.swarm-guard.local.md`
- `.claude/hookify.swarm-safety.local.md`
- `.claude/hookify.swarm-context.local.md`

**Report results:**
- Final status of each task (DONE / FAILED)
- Summary of what was accomplished
- Any failed tasks with failure reasons
- Event count from `.swarm/events.jsonl`

## State Machine

The state machine is enforced by three hook layers:

```
┌─────────────────────────────────────────────────┐
│  Layer 1: Plugin hooks (hooks/hooks.json)       │
│  ├─ PreToolUse Write|Edit → guard-write.sh      │
│  │  Reads state.json, blocks writes outside     │
│  │  active pipeline stages (deterministic)      │
│  └─ SubagentStop → prompt check                 │
│     Blocks orchestrator stop if tasks remain    │
├─────────────────────────────────────────────────┤
│  Layer 2: Hookify rules (generated per-run)     │
│  ├─ swarm-guard: stop gate for main session     │
│  ├─ swarm-safety: warns on destructive commands │
│  └─ swarm-context: injects state on user prompt │
├─────────────────────────────────────────────────┤
│  Layer 3: Orchestrator agent                    │
│  └─ Reads team.json pipeline, dispatches agents │
│     through stages, updates state.json          │
└─────────────────────────────────────────────────┘

Task flow:
  PENDING → stage[0] → stage[1] → ... → DONE
               ↑            │
               └────────────┘ (stage rejected)
               │
               └─→ FAILED (attempts exhausted)
```
