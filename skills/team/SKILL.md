---
name: team
description: Use to create, list, or manage swarm teams/workflows through conversation. Triggers on "create a swarm team", "new team", "new workflow", "custom pipeline", "set up a team for", "swarm team for", "list teams", "show teams", or /swarm:team.
argument-hint: "[--local] [--list] [team name or description of what you're building]"
allowed-tools: ["Read", "Write", "Glob", "Bash"]
---

# Create a Swarm Team

Build a custom team pipeline by understanding what the user is trying to accomplish. Ask questions, then generate the team config.

## Team Storage

Teams are resolved from three locations, checked in order:

1. **Project-local**: `.swarm/teams/<name>.json` — specific to this repo
2. **User-global**: `~/.claude/swarm/teams/<name>.json` — available in all projects, survives plugin reinstalls
3. **Built-in**: `${CLAUDE_PLUGIN_ROOT}/teams/<name>.json` — shipped defaults (dev, fullstack, research)

By default, new teams are saved to **user-global** so they're reusable everywhere.
Use `--local` to save to the current project instead.

## If `--list` or user asks to see teams

List all available teams from all three locations. For each, show name, description, pipeline, and where it's stored. Use Glob to find `*.json` in all three paths.

```
Built-in teams:
  dev         — code → review
  fullstack   — implement → test → review
  research    — investigate → synthesize

Global teams (~/.claude/swarm/teams/):
  docs        — draft → edit
  secure-dev  — code → security → review

Project teams (.swarm/teams/):
  (none)
```

## Process

### 1. Understand the Work

If the user gave a clear description, extract what you need. Otherwise, ask ONE question at a time from this list until you have enough to build the pipeline:

- **"What kind of work will this team handle?"** — coding, research, writing, data processing, design, devops, etc.
- **"Walk me through how you'd do this manually — what steps, in what order?"** — this reveals the natural pipeline stages
- **"Which steps need isolation (their own git branch)?"** — determines `isolation: "worktree"` stages
- **"Are there quality gates — steps where work gets approved or sent back?"** — determines `pass_pattern` and `fail_returns_to`
- **"How many retries before giving up on a task?"** — sets `max_attempts`

Stop asking as soon as you can construct the pipeline. Most teams need 2-4 questions max.

### 2. Design the Pipeline

Map the user's workflow to pipeline stages. For each stage, determine:

- **`name`** — short lowercase identifier (e.g., `draft`, `code`, `review`, `test`, `research`)
- **`agent`** — which agent runs this stage:
  - `"swarm:coder"` — for implementation work (has Write/Edit tools)
  - `"swarm:reviewer"` — for review/validation (read-only)
  - `"general-purpose"` — for anything else (research, writing, analysis, testing)
- **`isolation`** — set to `"worktree"` if the stage modifies files and needs branch isolation
- **`pass_pattern`** — regex for quality gates (e.g., `"^PASS"`, `"^APPROVED"`, `"^LGTM"`). Omit if the stage always passes.
- **`fail_returns_to`** — stage name to return to on failure. Omit if failures retry the same stage.
- **`description`** — one-line description injected into the agent's prompt. Make this specific to what the agent should do.

### 3. Show the Design

Present the pipeline visually before saving:

```
Team: <name>
<description>

Pipeline: <stage1> → <stage2> → ... → DONE
                ↑          │
                └──────────┘ (on failure)

Stages:
  1. <name> — <description> [agent: <agent>, isolation: <yes/no>]
  2. <name> — <description> [agent: <agent>, gate: <pattern>]
  ...

Max attempts: <N>
Save to: ~/.claude/swarm/teams/<name>.json (global)
```

Ask: "Does this look right? Want to change anything?"

### 4. Save the Team

Once confirmed, determine a team name (lowercase, hyphenated).

Check for name conflicts across all three locations using Glob.

**Save location:**
- If `--local` flag: write to `.swarm/teams/<name>.json` (create dir if needed)
- Otherwise: write to `~/.claude/swarm/teams/<name>.json`

```json
{
  "name": "<name>",
  "description": "<one-line description>",
  "stages": [
    {
      "name": "<stage>",
      "agent": "<agent-type>",
      "isolation": "worktree",
      "description": "<what the agent should do>"
    }
  ],
  "max_attempts": <N>
}
```

### 5. Confirm

Tell the user:
- Team saved as `<name>` at `<path>`
- How to use it: `/swarm:run --team <name> <plan>`
- Available in: all projects (global) or this project only (local)
- They can edit the JSON directly to tweak later

## Guidelines

- **Keep pipelines short.** 2-4 stages is ideal. More stages = more overhead, not more quality.
- **Every stage needs a clear purpose.** If you can't explain what the agent does in one sentence, the stage is too vague.
- **Quality gates go on review/validation stages**, not implementation stages.
- **Use `general-purpose` agent** for stages that don't need specialized tools. Only use `swarm:coder` when the stage writes code and `swarm:reviewer` when it's a read-only review.
- **Worktree isolation** is for stages that modify files. Research, analysis, and review stages don't need it.
- **Stage descriptions matter** — they're injected into the agent's prompt and determine what it actually does. Be specific: "Write unit tests covering all edge cases" is better than "Test the code".

## Examples

**User says "I need a team for writing documentation":**
```json
{
  "name": "docs",
  "description": "Documentation team: draft then editorial review",
  "stages": [
    { "name": "draft", "agent": "general-purpose", "isolation": "worktree", "description": "Write clear, comprehensive documentation for the specified topic" },
    { "name": "edit", "agent": "general-purpose", "pass_pattern": "^APPROVED", "fail_returns_to": "draft", "description": "Review documentation for accuracy, clarity, completeness, and style. Respond with APPROVED or REJECTED with specific feedback." }
  ],
  "max_attempts": 3
}
```

**User says "I want to prototype fast — no review, just build":**
```json
{
  "name": "rapid",
  "description": "Rapid prototyping: implement only, no review gate",
  "stages": [
    { "name": "build", "agent": "swarm:coder", "isolation": "worktree", "description": "Implement the task quickly, favoring working code over perfection" }
  ],
  "max_attempts": 2
}
```

**User says "We need security review before anything merges":**
```json
{
  "name": "secure-dev",
  "description": "Security-focused development: code, security audit, then standard review",
  "stages": [
    { "name": "code", "agent": "swarm:coder", "isolation": "worktree", "description": "Implement the task following secure coding practices" },
    { "name": "security", "agent": "general-purpose", "pass_pattern": "^PASS", "fail_returns_to": "code", "description": "Audit the implementation for security vulnerabilities: injection, auth bypass, data exposure, OWASP Top 10. Respond PASS or FAIL with specific findings." },
    { "name": "review", "agent": "swarm:reviewer", "pass_pattern": "^PASS", "fail_returns_to": "code", "description": "Review for correctness, code quality, and completeness" }
  ],
  "max_attempts": 3
}
```
