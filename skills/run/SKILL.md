---
name: run
description: Use to start an autonomous multi-agent development swarm from a plan or task list. Triggers on "run the swarm", "execute this plan with agents", "build this autonomously", "start the swarm", or /swarm:run.
argument-hint: "[--team <name>] <plan or task list>"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent"]
---

# Start Swarm

The user has provided a development plan. Parse it into a task queue, select a team pipeline, and hand off to the orchestrator. You do not implement anything yourself.

## Steps

### 1. Ensure Git

Worktrees require a git repository. Check if in one; if not:

```bash
git init && git add -A && git commit -m "initial commit before swarm" --allow-empty
```

### 2. Select Team

Check if the user specified a team (e.g., `--team fullstack` or `--team research`).

- If specified: read the team config from `${CLAUDE_PLUGIN_ROOT}/teams/<name>.json`
- If not specified: default to `${CLAUDE_PLUGIN_ROOT}/teams/dev.json`

Available built-in teams:
- **dev** — code → review (default)
- **fullstack** — implement → test → review
- **research** — investigate → synthesize

Read the team JSON to understand the pipeline stages.

### 3. Parse the Plan

Break the user's input into discrete tasks. Each task must be:

- **Isolated** — implementable without colliding with other tasks
- **Atomic** — completable in a single agent session
- **Specific** — an agent can execute it without asking questions

Identify dependencies: if task B requires output from task A, B depends on A.

### 4. Create Queue

Create the `.swarm/` directory. Write two files:

**`.swarm/team.json`** — copy the selected team config here so the orchestrator can read it.

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

Task IDs are sequential strings. Dependencies reference these IDs.

**`.swarm/events.jsonl`** — initialize as empty file. The orchestrator appends events here as an audit trail.

### 5. Display Queue

Show the parsed queue and selected team to the user before launching:

```
Team: dev (code → review)

| # | Title              | Depends On | Status  |
|---|--------------------|------------|---------|
| 1 | Create user model  | —          | PENDING |
| 2 | Add auth endpoints | 1          | PENDING |
```

### 6. Launch Orchestrator

Spawn the orchestrator agent:

- `subagent_type`: `swarm:orchestrator`
- `prompt`: `"Execute the swarm queue. State: .swarm/state.json, Team: .swarm/team.json, Events: .swarm/events.jsonl. Project root: <absolute path to cwd>. Process all tasks to completion."`

Do NOT intervene while the orchestrator runs unless it returns an error.

### 7. Report

When the orchestrator returns, display:

- Final status of each task (DONE / FAILED)
- Summary of what was accomplished
- Any failed tasks with failure reasons

## State Machine

```
Machine:  IDLE → RUNNING → DONE | FAILED

Task:     PENDING → stage[0] → stage[1] → ... → stage[N] → DONE
          Any stage failure → returns to fail_returns_to stage
          Attempts exhausted → FAILED
```

The pipeline stages come from the team config. The orchestrator follows them in order.
