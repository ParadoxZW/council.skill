# Council Quick Start · for humans

← back to [README](../README.md)

For users who want to install by hand. Four steps: get it → install the skill → configure the backend
library → pick the council roster.
(Don't want to do it manually? Let Claude Code install it for you — see "Install & configure" in the README.)

## 0. Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed;
- at least one councilor backend API key (GLM / DeepSeek / Kimi / an OpenAI-compatible relay, etc. —
  see step 3; configure only the ones you'll actually use);
- to use a **Codex backend** councilor, also install the Codex CLI: `npm i -g @openai/codex`.

## 1. Get the project

```shell
git clone https://github.com/ParadoxZW/council.skill
cd council.skill
```

## 2. Install the skill

Put the skill body where Claude Code can discover it — pick one:

- **User level** (available in every project):
  ```shell
  cp -r skills/council ~/.claude/skills/council
  ```
- **Project level** (this project only):
  ```shell
  cp -r skills/council /your/project/.claude/skills/council
  ```

## 3. Configure the councilor backend library (council-def.sh)

How each councilor backend is invoked lives in one library file. Copy the template to the default location:

```shell
cp council-def.example.sh ~/.local/bin/council-def.sh
```

> [!note] Want a different path?
> The default is `~/.local/bin/council-def.sh`. If you put it elsewhere, update this line at the top
> of the skill's `skills/council/scripts/council.sh` to point at your path (or set the env var
> `COUNCILOR_LIB=<your path>` at runtime):
> ```shell
> COUNCILOR_LIB="${COUNCILOR_LIB:-$HOME/.local/bin/council-def.sh}"
> ```

Edit `~/.local/bin/council-def.sh` and replace the `<your-...-key-here>` placeholders for the backends
you'll use. Four backends ship as examples:

| function | backend | harness |
|---|---|---|
| `council-cc-glm` | GLM (Zhipu, Anthropic-compatible endpoint) | Claude Code |
| `council-cc-ds` | DeepSeek | Claude Code |
| `council-cc-kimi` | Kimi (Moonshot) | Claude Code |
| `council-codex-gpt` | gpt-5.5 (via a relay) | **Codex CLI** |

- **Claude Code backends** (`council-cc-*`): set `ANTHROPIC_BASE_URL` / `COUNCIL_*_AUTH_TOKEN` /
  `COUNCIL_*_MODEL` as needed; any Anthropic-compatible endpoint works.
- **Codex backend** (`council-codex-gpt`): put the key in `COUNCIL_CODEX_AUTH_TOKEN` and the model in
  `COUNCIL_CODEX_MODEL`. A key alone isn't enough — `codex`'s provider/auth comes from a `config.toml`
  under `CODEX_HOME` (see below). Make sure `codex` is installed (`npm i -g @openai/codex`).
- Leave unused backends as they are; they don't interfere.

> [!note] Using the Codex backend? Also set up `CODEX_HOME`
> - **Official OpenAI subscription**: if you've run `codex login`, just point `CODEX_HOME` in
>   `council-def.sh` at that config dir (default `~/.codex`); no extra file needed.
> - **Relay / OpenAI-compatible proxy**: create an isolated `CODEX_HOME` (e.g. `~/.codex-relay`),
>   point `council-def.sh`'s `CODEX_HOME` at it, and write `<CODEX_HOME>/config.toml`:
>   ```toml
>   model = "gpt-5.5"
>   model_provider = "proxy"
>   [model_providers.proxy]
>   base_url = "<relay base url, e.g. https://.../v1>"
>   env_key  = "OPENAI_API_KEY"   # council-def.sh passes COUNCIL_CODEX_AUTH_TOKEN as OPENAI_API_KEY
>   wire_api = "responses"
>   ```

## 4. Pick the council roster (config.json)

Edit the `config.json` inside the **installed** skill (user level: `~/.claude/skills/council/config.json`):

```json
{
  "chief_model": "Opus",
  "councilors": ["council-cc-glm", "council-codex-gpt", "council-cc-kimi"]
}
```

- `councilors`: the councilor function names to enable (each must be defined in `council-def.sh` **and
  actually configured**). **Pick models different from your main agent** for complementary
  perspectives, and **remove any backend you didn't set up** (the template lists `council-codex-gpt` by
  default — drop it if you're not using Codex, or it will fail every round).
- `chief_model`: the model chief uses to synthesize the opinions.

## 5. Use it

Reload Claude Code and it's live. The skill auto-triggers at key decision points (before settling on a
plan, before declaring done, when stuck or changing approach); you can also explicitly ask the agent
to "consult the council", or send `/council`.

---

**Dependency cheat sheet**: Claude Code backend councilors need the `claude` CLI (ships with Claude
Code); Codex backend councilors need the `codex` CLI.
