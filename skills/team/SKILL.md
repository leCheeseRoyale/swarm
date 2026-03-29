---
name: team
description: Use to create, list, or manage swarm teams/workflows through conversation. Triggers on "create a swarm team", "new team", "new workflow", "custom pipeline", "set up a team for", "swarm team for", "list teams", "show teams", or /swarm:team.
argument-hint: "[--local] [--list] [team name or description of what you're building]"
allowed-tools: ["Read", "Write", "Glob", "Bash"]
---

# Create a Swarm Team

Design the minimal, elegant agent pipeline for the user's work by thinking from first principles — not by copying conventional workflows.

Every team becomes a **hook-driven state machine** when it runs. You design the pipeline; `/swarm:run` wires up the hooks:

- **Plugin hooks** (deterministic) — bash guard script blocks writes outside active stages by reading state.json
- **Hookify rules** (hot-reloadable) — generated per-session: stop gate, bash safety, context injection
- **Orchestrator** — reads the pipeline, dispatches agents through stages

You only design the pipeline. The hooks are automatic.

## Team Storage

Teams resolve from three locations (first match wins):

1. **Project-local**: `.swarm/teams/<name>.json` — this repo only
2. **User-global**: `~/.claude/swarm/teams/<name>.json` — all projects, survives reinstalls
3. **Built-in**: `${CLAUDE_PLUGIN_ROOT}/teams/<name>.json` — shipped defaults

New teams save to **user-global** by default. Use `--local` for project-specific.

## If `--list` or user asks to see teams

Glob all three locations for `*.json`. Show name, description, pipeline, and location.

## Design Process

### 1. Understand the Work

Ask the user ONE question: **"Walk me through how you'd do this work yourself, start to finish."**

Their answer reveals the real workflow — not the org chart or the roles they think they need, but the actual sequence of cognitive acts. Listen for:

- Where the **nature of the work changes** (thinking → building → judging)
- Where **bad work moving forward would be costly** (these are real gates)
- Where **files change and could collide** (these need isolation)

One question is usually enough. Ask a second only if the answer was too vague to identify transitions.

### 2. Deconstruct to First Principles

Before designing anything, strip away assumptions. Apply these tests silently:

**The Merge Test**: If two steps are always done by the same type of mind (both analytical, both creative, both judgmental), they're probably one stage. "Analyze the code" and "design the fix" are one cognitive act — you can't see the problem without seeing the solution shape.

**The Gate Test**: A quality gate only earns its cost if catching a failure HERE is cheaper than catching it LATER. Don't add a review stage just because "review is good practice." Ask: what breaks downstream if this stage produces bad output?

**The Isolation Test**: A stage needs worktree isolation only if it modifies files AND could run in parallel with other tasks touching the same files. Research, analysis, and review never need isolation.

**The Stage Justification Test**: Every stage must produce output that is *qualitatively different* from the previous stage's output. If two stages both produce "better code," they're one stage with a retry loop, not two stages.

**The Cost Test**: Every stage boundary costs tokens, context loss, and a potential failure point. The burden of proof is on ADDING a stage, not on removing one.

### 3. Build the Pipeline

The irreducible pattern for any work is:

```
THINK → MAKE → JUDGE
```

Most pipelines are exactly three stages. Some are two (no judgment needed) or one (just do it). Very few legitimately need four or more. If you're designing more than four stages, you're probably fragmenting a single cognitive act across multiple agents.

Map the user's workflow to the minimal stages:

- **Thinker stages** use `general-purpose` — analysis, design, research, planning
- **Maker stages** use `swarm:coder` with `isolation: "worktree"` — building, writing, implementing
- **Judge stages** use `swarm:reviewer` with `pass_pattern` — verification, review, validation

For each stage, write a `description` that tells the agent exactly what "done" looks like. Vague descriptions like "review the code" produce vague results. "Check for correctness against the task spec, security vulnerabilities, and missing edge cases" produces real judgment.

### 4. Present the Design

Show the pipeline with reasoning:

```
Team: <name>
<description>

Why this shape:
  <1-2 sentences on what was stripped away and why>

Pipeline: <stage1> → <stage2> → ... → DONE

Stages:
  1. <name> — <description> [<agent>, isolation: <yes/no>]
  ...

On failure: <which stage retries to where>
Max attempts: <N>
Save to: <path>
```

Ask: "Does this capture your workflow? Want to adjust anything?"

### 5. Save

Determine team name (lowercase, hyphenated). Check for conflicts across all three locations.

- Default: `~/.claude/swarm/teams/<name>.json`
- With `--local`: `.swarm/teams/<name>.json`

```json
{
  "name": "<name>",
  "description": "<one-line description>",
  "stages": [
    {
      "name": "<stage>",
      "agent": "<agent-type>",
      "isolation": "worktree",
      "description": "<what done looks like for this stage>"
    }
  ],
  "max_attempts": <N>
}
```

Confirm: team name, save path, usage command (`/swarm:run --team <name> <plan>`).

## Design Principles

These are non-negotiable:

1. **Fewer stages is better.** Every boundary has a cost. Three is the sweet spot. Two is fine. One is brave. Five is suspicious.
2. **Stages are cognitive acts, not job titles.** Don't create a "tester" stage and a "reviewer" stage — if they both answer "is this good?", they're one stage.
3. **Gates earn their place.** A `pass_pattern` stage must catch failures that would be MORE expensive to catch later. If failure at stage N just means redoing stage N anyway, skip the gate.
4. **Descriptions are instructions, not labels.** "Review the code" is a label. "Verify all task requirements are met, check for injection vulnerabilities and unhandled edge cases, run existing tests if present" is an instruction.
5. **When in doubt, simplify.** A clean two-stage pipeline that works is better than an elegant five-stage pipeline that fragments the work.

## Anti-Patterns

Reject these if the user (or your instincts) suggest them:

- **"We should add a testing stage AND a review stage"** — If both check quality, merge them. One judge is enough.
- **"Let's add an analysis stage before the design stage"** — You can't analyze without forming a view. That's one stage.
- **"We need separate stages for frontend and backend"** — Those are different TASKS in the queue, not different stages in the pipeline. The orchestrator parallelizes tasks, not stages.
- **"Add a documentation stage at the end"** — Documentation is part of the maker's job, not a separate stage. Put it in the maker's description.
- **"Let's add a planning stage"** — The orchestrator plans. That's its job. Don't make an agent plan for the planner.
