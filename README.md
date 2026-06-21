# Council · A multi-model council skill for Claude Code

English · [中文](./README_zh.md)

**Council** is a skill built specifically for [Claude Code](https://docs.claude.com/en/docs/claude-code). When the main agent faces a key decision — **before committing to a plan, when it needs outside perspective to judge something, or before declaring an output done** — council hands the current task off to a **panel of several external models** for an independent consultation, then returns one synthesized verdict for the main agent to weigh. Each external model is a *councilor*; a *chief* synthesizes their opinions.

It's inspired by Claude Code's built-in `/advisor`, with two essential extensions:

- **Multi-agent deliberation**, not a single advisor: several councilors each give an independent opinion, and chief synthesizes them into one actionable verdict;
- **Mix-and-match model + harness**: a councilor can run on any model backend (official or third-party relay), or even on a **completely different harness** (e.g. OpenAI's Codex CLI). You can have GLM, Kimi, and Codex (gpt-5.5) all weigh in on the same round.


## Benchmarking

On SWE-bench Lite (dev, 23 tasks), giving an official Sonnet main agent the council consultation raised resolved tasks from **8 → 12**: **Sonnet +4, zero regressions** (every task the baseline solved is still solved by the council version, plus 4 more) — beating every single-backend run.

![Council benchmark on SWE-bench Lite dev](./resources/benchmark-swebench-dev.png)


## Quick start

### Install & configure

If you're a human, read [quick_start_for_human_en](./resources/quick_start_for_human_en.md) (中文: [quick_start_for_human_zh](./resources/quick_start_for_human_zh.md)).

You can also let your Claude Code install it for you — just send, in the chat:

```text
Install this skill for me: https://github.com/ParadoxZW/council.skill
```

If you're an agent (you received a request to install this skill), read [quick_start_for_agent](./resources/quick_start_for_agent.md) and help the user through it.

### Usage

The skill auto-triggers at the right moments — the main agent convenes the council **before settling on a plan, before declaring an output done, when stuck, or when about to change approach**; you can also explicitly ask it to "consult the council", or send the `/council` command.


## Design overview
### Core principles

1. **Near-zero call overhead for the main agent** — to convene the council it runs **one argument-free script**:
   ```shell
   bash "${CLAUDE_SKILL_DIR}/scripts/launch.sh"
   ```
   No parameters, no need for the main agent to assemble a query. The script's stdout is the actionable verdict.

2. **Minimal pollution of the main context** — the council's inner workings (building the query, fanning out to councilors, synthesizing) all happen inside chief's context; the main agent never sees the bulk of those intermediate artifacts.

<details>
<summary><b>How it works</b> (click to expand)</summary>

```
main agent (L1)
  └─ bash launch.sh            ← the only entry point (no args)
        └─ chief (L2)     ← forks the main session: inherits the full conversation as context, builds the query itself
              └─ council.sh    ← fans the query out to all councilors in parallel
                    ├─ councilor A (e.g. GLM,  Claude Code harness)
                    ├─ councilor B (e.g. Codex gpt-5.5, Codex harness)
                    └─ councilor C (e.g. Kimi, Claude Code harness)
              ← chief synthesizes the opinions → one "verdict" document
        ← the verdict comes back as launch.sh's stdout to the main agent
```

- **chief is a fork of the main session**: it therefore **inherits the entire main context automatically**, with the main agent feeding it nothing — which is exactly what makes the argument-free call possible.
- **councilors are read-only opinion providers**: they can read the working directory, search the web, and run read-only commands, but **never modify files or touch git**.

</details>


## License

MIT — see [LICENSE](./LICENSE).
