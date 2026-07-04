# claude-agents

A small, global set of **cost-routing subagents** for Claude Code. The whole point is to stop paying Opus prices for work that a cheaper model does just as well: search, mechanical edits, test-writing, translation, log-mining, doc-writing. The expensive model stays for the work that actually needs judgement.

These install into `~/.claude/agents/`, so they're available in **every repo** on this machine — invoke them with the `Agent` tool (`subagent_type: "scout"`, `"mechanic"`, …) or let the orchestrator delegate to them automatically.

> Sibling of [`claude-skills`](../claude-skills). Same idea (a versioned, installable library of Claude Code tooling), different axis: skills package *know-how*, these package *who-does-it-and-on-which-model*.

## The routing ladder

Each agent is pinned to the cheapest model tier that does its job well. The `model:` alias resolves to whatever model currently occupies that tier on the account.

| Agent | Tier | Job | Never does |
|---|---|---|---|
| **scout** | `haiku` | Read-only recon — locate symbols/files/usages/config, answer "where is X" | edits; interprets architecture |
| **log-miner** | `haiku` | Extract & aggregate from JSONL / logs / CSV / JSON | edits; searches source code |
| **scribe** | `haiku` | Draft commit messages / PR bodies / changelog from a diff | commits, pushes, opens PRs |
| **dep-checker** | `haiku` | Read lockfiles/changelogs, report installed vs latest + upgrade notes | performs upgrades |
| **mechanic** | `sonnet` | Apply an *already-specified* mechanical change + verify with the repo build | design decisions; scope creep |
| **test-writer** | `sonnet` | Write/extend tests in the repo's style, auto-detecting the runner | edits product code to pass tests |
| **locale-translator** | `sonnet` | Mirror approved `en` → `fi`/`sv`/… i18n | edits the source locale; adds keys |
| **doc-scribe** | `sonnet` | READMEs / docstrings / SKILL.md / why-comments | changes logic while documenting |
| **architect** | `opus` | Read-only design/planning **and the escalation target** | edits source |

Read it as three rungs:

- **`haiku` — look and report.** No writes. Search, extraction, drafting text about a diff. The highest-frequency, lowest-risk work; this is where most of the token savings live.
- **`sonnet` — make the change.** Real edits whose *shape is already known* — apply a spec, write a test in an existing pattern, mirror a locale, write docs. Sonnet is entirely capable here; Opus is waste.
- **`opus` — decide the shape.** Architecture, trade-offs, and correctness-critical reasoning. `architect` is deliberately the one expensive agent — it also documents **what must not be routed down**.

### Do not route these down

The cost-cutting is principled, not blanket. Keep on a strong model (main session or `architect`):

- **correctness-critical logic** — auth / crypto, RAG containment & grounding-validation, LLM-concurrency, numerical / tensor code (e.g. TTS model internals).
- **novel design** — new algorithms, module boundaries, anything where picking the approach *is* the work.

The cheap agents are wired to **stop and hand back** when a task turns out to need judgement, rather than guessing on a weak model.

## Install

```bash
# every repo, for this user  ->  ~/.claude/agents/
./install.sh

# just one
./install.sh scout

# into a specific repo instead of user-global
./install.sh --target project --repo /d/koodaamista/some-repo

./install.sh --list          # what's available
./install.sh --uninstall all # remove the ones this repo owns
```

The installer prefers a **symlink** (so `git pull` here propagates with no re-install); where symlinks aren't available (Windows/MSYS) it copies and tells you to re-run after pulling.

## How they behave (shared contract)

Every agent, cheap or not:

1. Reads the repo's `CLAUDE.md` / `AGENTS.md` first and obeys its hard rules.
2. **Never** runs `git push`, `gh pr merge`, or creates commits/branches/PRs unless the user explicitly asked in that session — it hands finished work back to the orchestrator.
3. Auto-detects the stack (test runner, build, lint, i18n layout) instead of hardcoding one project's commands — that's what lets a single global set cover JS, C#, and Python repos.
4. Stays strictly in scope and adds no Anthropic/Claude attribution to anything it writes.

## Adding an agent

Drop a `agents/<name>.md` with the standard frontmatter (`name`, `description`, `tools`, `model`) and a body following the existing shape (`Use when` / `Do not use — escalate instead` / `How I work` / `What I return`). Pick the **cheapest** tier that does the job, then `./install.sh <name>`.
