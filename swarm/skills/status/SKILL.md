---
name: status
description: Use to check the current state of a running or completed swarm. Triggers on "swarm status", "check the queue", "how is the swarm doing", "show swarm progress", or /swarm:status.
allowed-tools: ["Read"]
---

# Swarm Status

Read `.swarm/state.json` and `.swarm/team.json` and display the current state.

## Display

1. **Machine state** — IDLE / RUNNING / DONE / FAILED
2. **Team** — name and pipeline stages (e.g., `dev: code → review`)
3. **Task table:**

```
| # | Title | Status  | Stage    | Attempts | Branch       |
|---|-------|---------|----------|----------|--------------|
| 1 | ...   | DONE    | —        | 1        | swarm/task-1 |
| 2 | ...   | review  | 2/2      | 1        | swarm/task-2 |
| 3 | ...   | PENDING | —        | 0        | —            |
```

4. **Progress** — X / Y tasks complete
5. **Failed tasks** — if any, show their feedback
6. **Recent events** — show last 5 lines from `.swarm/events.jsonl` if it exists

If `.swarm/state.json` does not exist, report: "No active swarm. Use `/swarm:run` to start one."
