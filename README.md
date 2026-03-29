# Swarm

Deterministic state machine for autonomous multi-agent development in Claude Code.

## How It Works

You provide a plan. Swarm breaks it into a task queue, selects a team pipeline, and processes it autonomously:

1. **You** describe what to build via `/swarm:run <plan>`
2. **Orchestrator** reads the queue and pipeline — dispatches agents per stage, never writes code
3. **Stage agents** execute their role (code, review, test, research, etc.) in isolation
4. **Orchestrator** advances tasks through the pipeline, merges approved work
5. **Event log** records every transition for audit and debugging

## State Machine

```
Machine:  IDLE ─→ RUNNING ─→ DONE
                     │
                     └──→ FAILED

Task:     PENDING ─→ stage[0] ─→ stage[1] ─→ ... ─→ DONE
                       ↑              │
                       └──────────────┘  (stage rejected, retry)
                       │
                       └─→ FAILED  (attempts exhausted)
```

The pipeline stages come from the team config — not hardcoded.

## Teams

Teams define the agent pipeline. Select with `--team <name>` or default to `dev`.

| Team | Pipeline | Use Case |
|------|----------|----------|
| **dev** | code → review | Standard feature development |
| **fullstack** | implement → test → review | Multi-layer with test stage |
| **research** | investigate → synthesize | Research and analysis tasks |

### Custom Teams

Create `teams/<name>.json` in the plugin directory:

```json
{
  "name": "my-team",
  "description": "Custom pipeline",
  "stages": [
    {
      "name": "implement",
      "agent": "swarm:coder",
      "isolation": "worktree",
      "description": "Implement the task"
    },
    {
      "name": "review",
      "agent": "swarm:reviewer",
      "pass_pattern": "^PASS",
      "fail_returns_to": "implement",
      "description": "Review the implementation"
    }
  ],
  "max_attempts": 3
}
```

**Stage fields:**
- `name` — stage identifier, becomes the task status while active
- `agent` — subagent type to dispatch (`swarm:coder`, `swarm:reviewer`, `general-purpose`, or any plugin agent)
- `isolation` — `"worktree"` for git-isolated work, omit for shared context
- `pass_pattern` — regex matched against agent's first response line; if omitted, always passes
- `fail_returns_to` — stage name to return to on failure; if omitted, retries same stage
- `description` — injected into the agent's prompt as context

## Skills

| Skill | Usage | Description |
|-------|-------|-------------|
| `/swarm:run` | `/swarm:run [--team name] <plan>` | Parse plan, select team, launch orchestrator |
| `/swarm:status` | `/swarm:status` | Show queue state, pipeline progress, recent events |
| `/swarm:push` | `/swarm:push <task>` | Add a task to an active queue |

## Built-in Agents

| Agent | Role | Writes Code? | Tools |
|-------|------|-------------|-------|
| orchestrator | Queue + pipeline + dispatch | No | Read, Write (.swarm/ only), Bash, Glob, Grep, Agent |
| coder | Implementation | Yes (worktree) | Read, Write, Edit, Bash, Glob, Grep |
| reviewer | Code review | No | Read, Bash, Glob, Grep |

## Queue

Tasks live in `.swarm/state.json`. Events are appended to `.swarm/events.jsonl`.

```json
{
  "id": "swarm-1711720000",
  "state": "RUNNING",
  "team": "dev",
  "tasks": [
    {
      "id": "1",
      "title": "Create user model",
      "description": "...",
      "status": "PENDING",
      "stage_index": 0,
      "dependencies": [],
      "attempts": 0
    }
  ]
}
```

## Hooks

- **PreToolUse (Write|Edit)** — deterministic bash guard blocks code writes unless a task is in an active pipeline stage
- **SubAgentStop** — prompt-based check prevents orchestrator from stopping with unfinished tasks

## Installation

```bash
claude --plugin-dir /path/to/swarm
```
