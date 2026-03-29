---
name: run
description: Use to start an autonomous multi-agent development swarm from a plan or task list. Triggers on "run the swarm", "execute this plan with agents", "build this autonomously", "start the swarm", or /swarm:run.
argument-hint: <plan or task list>
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent"]
---

# Start Swarm

The user has provided a development plan. Parse it into a task queue and hand off to the orchestrator. You do not implement anything yourself.

## Steps

### 1. Ensure Git

Worktrees require a git repository. Check if in one; if not:

```bash
git init && git add -A && git commit -m "initial commit before swarm" --allow-empty
```

### 2. Parse the Plan

Break the user's input into discrete tasks. Each task must be:

- **Isolated** — implementable in its own worktree without touching other tasks' files
- **Atomic** — completable in a single agent session
- **Specific** — a coder can implement it without asking questions

Identify dependencies: if task B requires files or APIs created by task A, B depends on A.

### 3. Create Queue

Create the `.swarm/` directory and write `.swarm/state.json`:

```json
{
  "id": "swarm-<unix-timestamp>",
  "state": "RUNNING",
  "created": "<ISO-8601>",
  "updated": "<ISO-8601>",
  "tasks": [
    {
      "id": "1",
      "title": "<short title>",
      "description": "<detailed implementation spec for the coder>",
      "status": "PENDING",
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

Task IDs are sequential strings ("1", "2", ...). Dependencies reference these IDs.

### 4. Display Queue

Show the parsed queue to the user as a table before launching:

```
| # | Title              | Depends On | Status  |
|---|--------------------|------------|---------|
| 1 | Create user model  | —          | PENDING |
| 2 | Add auth endpoints | 1          | PENDING |
```

### 5. Launch Orchestrator

Spawn the orchestrator agent:

- `subagent_type`: `swarm:orchestrator`
- `prompt`: `"Execute the swarm queue at .swarm/state.json. Process all tasks to completion. The project root is <absolute path to cwd>."`

Do NOT intervene while the orchestrator runs unless it returns an error.

### 6. Report

When the orchestrator returns, display:

- Final status of each task (DONE / FAILED)
- Summary of what was built
- Any failed tasks with failure reasons

## State Machine Reference

```
Machine:  IDLE → RUNNING → DONE | FAILED

Task:     PENDING → CODING → REVIEWING → DONE
          REVIEWING → CODING  (review rejected, retry)
          CODING → FAILED     (attempts >= 3)
```

Only these transitions are valid. The orchestrator enforces them.
