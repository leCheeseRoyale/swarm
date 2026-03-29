# Swarm

Deterministic state machine for autonomous multi-agent development in Claude Code.

## How It Works

You provide a plan. Swarm breaks it into a task queue and processes it autonomously:

1. **You** describe what to build via `/swarm:run <plan>`
2. **Orchestrator** reads the queue and dispatches agents — never writes code itself
3. **Coder** agents implement tasks in isolated git worktrees
4. **Reviewer** agents validate each implementation
5. **Orchestrator** merges approved work and advances to the next task

Hooks enforce the state machine: code writes are physically blocked unless a task is in CODING state.

## State Machine

```
Machine:  IDLE ─→ RUNNING ─→ DONE
                     │
                     └──→ FAILED

Task:     PENDING ─→ CODING ─→ REVIEWING ─→ DONE
                       ↑            │
                       └────────────┘  (rejected, retry)
                       │
                       └─→ FAILED  (after 3 attempts)
```

## Skills

| Skill | Usage | Description |
|-------|-------|-------------|
| `/swarm:run` | `/swarm:run <plan>` | Parse plan into queue, launch orchestrator |
| `/swarm:status` | `/swarm:status` | Show current queue state |
| `/swarm:push` | `/swarm:push <task>` | Add a task to an active queue |

## Agents

| Agent | Role | Writes Code? | Tools |
|-------|------|-------------|-------|
| orchestrator | Queue + dispatch | No | Read, Write (.swarm/ only), Bash, Glob, Grep, Agent |
| coder | Implementation | Yes (worktree) | Read, Write, Edit, Bash, Glob, Grep |
| reviewer | Code review | No | Read, Bash, Glob, Grep |

## Queue

Tasks live in `.swarm/state.json`:

```json
{
  "id": "swarm-1711720000",
  "state": "RUNNING",
  "tasks": [
    {
      "id": "1",
      "title": "Create user model",
      "description": "...",
      "status": "PENDING",
      "dependencies": [],
      "attempts": 0
    }
  ]
}
```

## Installation

```bash
claude --plugin-dir /path/to/swarm
```
