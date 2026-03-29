---
name: status
description: Use to check the current state of a running or completed swarm. Triggers on "swarm status", "check the queue", "how is the swarm doing", "show swarm progress", or /swarm:status.
allowed-tools: ["Read"]
---

# Swarm Status

Read `.swarm/state.json` and display the current state.

## Display

1. **Machine state** — IDLE / RUNNING / DONE / FAILED
2. **Task table:**

```
| # | Title | Status    | Attempts | Branch       |
|---|-------|-----------|----------|--------------|
| 1 | ...   | DONE      | 1        | swarm/task-1 |
| 2 | ...   | REVIEWING | 1        | swarm/task-2 |
| 3 | ...   | PENDING   | 0        | —            |
```

3. **Progress** — X / Y tasks complete
4. **Failed tasks** — if any, show their feedback

If `.swarm/state.json` does not exist, report: "No active swarm. Use `/swarm:run` to start one."
