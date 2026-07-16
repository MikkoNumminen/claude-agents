# claude-agents

A small, global set of **cost-routing subagents** for Claude Code. The whole point is to stop paying Opus prices for work that a cheaper model does just as well: search, mechanical edits, test-writing, translation, log-mining, doc-writing. The expensive model stays for the work that actually needs judgement.

Install them as a **Claude Code plugin** (see [Install](#install)) or copy them into `~/.claude/agents/` with the bundled script — either way they're available in **every repo** on this machine. Invoke them with the `Agent` tool (`subagent_type: "scout"`, `"mechanic"`, …) or let the orchestrator delegate to them automatically.

> Sibling of [`claude-skills`](../claude-skills). Same idea (a versioned, installable library of Claude Code tooling), different axis: skills package *know-how*, these package *who-does-it-and-on-which-model*.

## The routing ladder

Each worker agent is pinned to the cheapest model tier that does its job well — the `model:` alias resolves to whatever model currently occupies that tier on the account. `architect` alone carries no pin: it inherits the session model.

| Agent | Tier | Job | Never does |
|---|---|---|---|
| **scout** | `haiku` | Read-only recon — locate symbols/files/usages/config, answer "where is X" | edits; interprets architecture |
| **log-miner** | `haiku` | Extract & aggregate from JSONL / logs / CSV / JSON | edits; searches source code |
| **scribe** | `haiku` | Draft commit messages / PR bodies / changelog from a diff | commits, pushes, opens PRs |
| **dep-checker** | `haiku` | Read lockfiles/changelogs, report installed vs latest + upgrade notes | performs upgrades |
| **tidy** | `haiku` | Run the repo's own formatter + lint auto-fixers, report what's left | judgement fixes; logic changes |
| **mechanic** | `sonnet` | Apply an *already-specified* mechanical change + verify with the repo build | design decisions; scope creep |
| **test-writer** | `sonnet` | Write/extend tests in the repo's style, auto-detecting the runner | edits product code to pass tests |
| **locale-translator** | `sonnet` | Mirror approved `en` → `fi`/`sv`/… i18n | edits the source locale; adds keys |
| **doc-scribe** | `sonnet` | READMEs / docstrings / SKILL.md / why-comments | changes logic while documenting |
| **migrator** | `sonnet` | Generate/apply Prisma or EF Core migrations (auto-detected) | destructive migrations; prod DBs |
| **bisect** | `sonnet` | `git bisect` to the commit that introduced a regression | fixes the bug it finds |
| **architect** | *session model* | Read-only design/planning **and the escalation target** | edits source |

Read it as three rungs:

- **`haiku` — look and report.** No writes. Search, extraction, drafting text about a diff. The highest-frequency, lowest-risk work; this is where most of the token savings live.
- **`sonnet` — make the change.** Real edits whose *shape is already known* — apply a spec, write a test in an existing pattern, mirror a locale, write docs. Sonnet is entirely capable here; a bigger model is waste.
- **session model — decide the shape.** Architecture, trade-offs, and correctness-critical reasoning. `architect` is deliberately the one expensive agent — it carries no `model:` pin, so it inherits whatever the orchestrator session runs (`/model`: Opus, Fable, …). It also documents **what must not be routed down**. Note the flip side: inheritance means the escalation target is only as strong as your `/model` choice — run the session on a cheap model and architect runs cheap too.

### Two knobs, not one: model *and* effort

Each worker agent also pins a reasoning-**`effort`** in its frontmatter, so effort no longer inherits the orchestrator's session setting. This decouples the two costs: you can run the main session at `high`/`max` for hard reasoning without a delegated `scout` or `tidy` burning max-effort tokens on grep-and-report work. (The `Agent` tool has no per-launch effort parameter, so the frontmatter is the only per-agent knob: pin `effort:` to fix it, or omit the key to follow the session's `/effort`.)

- **`low`** — the `haiku` doers (scout, tidy, log-miner, dep-checker, scribe): look, run a tool, report. Nothing to reason about.
- **`medium`** — the `sonnet` doers (mechanic, test-writer, locale-translator, doc-scribe, migrator, bisect): apply a known shape and verify.
- **session `/effort`** — `architect` only. Unpinned like its model, so escalation mirrors the session exactly; to push architect harder on a hard problem, raise the session `/effort`.

### Do not route these down

The cost-cutting is principled, not blanket. Keep on a strong model — the main session, or `architect` when the session `/model` is a strong one (architect inherits it, so it is no stronger than the session):

- **correctness-critical logic** — auth / crypto, RAG containment & grounding-validation, LLM-concurrency, numerical / tensor code (e.g. TTS model internals).
- **novel design** — new algorithms, module boundaries, anything where picking the approach *is* the work.

The cheap agents are wired to **stop and hand back** when a task turns out to need judgement, rather than guessing on a weak model.

## Install

### As a plugin (recommended — no clone needed)

The repo is a Claude Code plugin and its own marketplace. Inside any Claude Code session:

```
/plugin marketplace add MikkoNumminen/claude-agents
/plugin install claude-agents
```

Update later with `/plugin update claude-agents@claude-agents` (or `/plugin marketplace update claude-agents` to refresh from git first — the plugin needs the `@claude-agents` marketplace qualifier, the marketplace doesn't). Plugin-installed agents are **namespaced** — invoke them as `claude-agents:scout`, `claude-agents:mechanic`, etc.

The same marketplace also serves the sibling [`claude-skills`](https://github.com/MikkoNumminen/claude-skills) library — once the marketplace is added, `/plugin install claude-skills` gets you the audit/maintenance skills too.

### With install.sh (raw copies, bare names)

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

The installer prefers a **symlink** (so `git pull` here propagates with no re-install); where symlinks aren't available (Windows/MSYS) it copies and tells you to re-run after pulling. Script-installed agents keep their bare names (`scout`, not `claude-agents:scout`), and a `~/.claude/agents/` or `.claude/agents/` copy **overrides** the plugin's agent of the same name — so having both installed is harmless, the copies just win.

## How they behave (shared contract)

Every agent, cheap or not:

1. Reads the repo's `CLAUDE.md` / `AGENTS.md` first and obeys its hard rules.
2. **Never** runs `git push`, `gh pr merge`, or creates commits/branches/PRs unless the user explicitly asked in that session — it hands finished work back to the orchestrator.
3. Auto-detects the stack (test runner, build, lint, i18n layout) instead of hardcoding one project's commands — that's what lets a single global set cover JS, C#, and Python repos.
4. Stays strictly in scope and adds no Anthropic/Claude attribution to anything it writes.

## Adding an agent

Drop a `agents/<name>.md` with the standard frontmatter (`name`, `description`, `tools`, `model`, `effort`) and a body following the existing shape (`Use when` / `Do not use — escalate instead` / `How I work` / `What I return`). Pick the **cheapest** model tier and effort that do the job; omit `model:`/`effort:` only for an agent that should deliberately inherit the session's `/model` and `/effort` (the `architect` pattern). Then `./install.sh <name>` for script installs; plugin installs pick the new agent up automatically from `agents/` — just commit, push, and have users run `/plugin marketplace update claude-agents` + `/plugin update claude-agents@claude-agents`.

## License

MIT — see [LICENSE](LICENSE).
