---
name: push
description: Use to add a new task to an existing swarm queue. Triggers on "add a task to the swarm", "push to the queue", "queue another task", or /swarm:push.
argument-hint: <task description>
allowed-tools: ["Read", "Write"]
---

# Push Task to Queue

Add a new task to the existing `.swarm/state.json` queue.

## Steps

1. Read `.swarm/state.json`. If missing, tell the user to run `/swarm:run` first.
2. Determine the next task ID: highest existing ID + 1.
3. Create a new task entry:
   - `id`: next sequential string
   - `title`: short summary extracted from user input
   - `description`: full description from user input
   - `status`: `"PENDING"`
   - `dependencies`: infer from context or ask the user
   - All other fields: `null` / `0` defaults
4. Append to the `tasks` array. Update the `updated` timestamp.
5. If the machine state is `DONE` or `FAILED`, set it back to `RUNNING`.
6. Write the updated state file.
7. Confirm: `"Task #N added: <title>"`
