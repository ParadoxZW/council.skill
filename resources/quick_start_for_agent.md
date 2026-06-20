# Quick Start · for an AI agent

You are an AI coding agent (typically **Claude Code**) and the user has asked you to install the
**council** skill (https://github.com/ParadoxZW/council.skill). Follow this procedure to install and
configure it for them. Work through the steps in order; each one is a real action you perform.

## Operating principles

- **Match the user's language.** Detect the language of the user's request and use it for every
  question you ask and for your final report — Chinese request → interact in Chinese; English →
  English; otherwise mirror their language.
- **Ask, don't assume.** Use your interactive question tool (e.g. `AskUserQuestion`) for each choice:
  install level, custom paths, which backends, models, keys. Offer sensible defaults.
- **Protect secrets.** Prefer NOT to handle API keys yourself. When the user would rather paste a key
  themselves, use the pause/resume pattern below so the key never passes through this conversation.
  If you do edit a key in, use file-edit tools — never echo a key into the chat, a log, or a command line.
- **Always give absolute paths.** Whenever you tell the user where something is, resolve `~` and show
  the full absolute path.
- **Be idempotent.** Before overwriting anything, check whether it already exists.

### Pause/resume pattern

Some steps are best done by the user outside this conversation — pasting an API key (so you never see
it), or installing a CLI. When that happens, tell the user (in their language) to:

1. exit this conversation (`Ctrl-D`, or `/exit`);
2. do the manual step (edit the file / install the tool);
3. come back with **`claude --continue`**, which resumes THIS conversation with full context.

Then pick up exactly where you left off. Note that `claude --continue` also **reloads skills**, so it
doubles as the "make the newly-installed skill discoverable" step (see step 7).

## Steps

### 0. Preflight checks

Confirm the environment before touching anything; fix or report gaps:
- `git` is available (needed to clone);
- `claude` is on `PATH` (needed by every Claude Code councilor);
- create parent dirs if missing: `mkdir -p ~/.claude/skills ~/.local/bin`;
- `jq` OR `python3` is available (the scripts read `config.json` with either; not fatal but worth noting).

### 1. Clone the repository

Clone to a scratch location (you'll copy the skill body out of it):

```shell
git clone https://github.com/ParadoxZW/council.skill /tmp/council.skill
```

### 2. Ask install level, then install the skill body

Ask whether to install at:
- **User level** — `~/.claude/skills/council` (available in every project), or
- **Project level** — `<current-project>/.claude/skills/council` (this project only).

If the target already exists, ask whether to overwrite or back it up first. Then copy the skill body
to the chosen target and remember its absolute path as `<INSTALL>`:

```shell
cp -r /tmp/council.skill/skills/council <INSTALL>
```

### 3. Install the councilor backend library (council-def.sh)

If `~/.local/bin/council-def.sh` already exists, it may hold the user's keys — ask before
overwriting (offer to back it up). Otherwise copy the template:

```shell
cp /tmp/council.skill/council-def.example.sh ~/.local/bin/council-def.sh
```

Ask whether the user wants a **custom path** instead. If yes:
- copy it there instead, AND
- edit `<INSTALL>/scripts/council.sh` — change the `COUNCILOR_LIB` default to the chosen path:
  ```shell
  COUNCILOR_LIB="${COUNCILOR_LIB:-$HOME/.local/bin/council-def.sh}"   # ← update the default here
  ```

### 4. Configure backends + keys in council-def.sh

Ask which backends the user wants — any subset of GLM / DeepSeek / Kimi / Codex-gpt, or a custom
Anthropic-compatible endpoint. **None is mandatory** (the Codex one in particular is optional — it
needs a separate CLI; see 4b). For each chosen backend, the variables to fill:

| function | fill these | harness |
|---|---|---|
| `council-cc-glm`  | `COUNCIL_GLM_AUTH_TOKEN` (+ `_MODEL`, `ANTHROPIC_BASE_URL`)  | Claude Code |
| `council-cc-ds`   | `COUNCIL_DS_AUTH_TOKEN`  (+ `_MODEL`, `ANTHROPIC_BASE_URL`)  | Claude Code |
| `council-cc-kimi` | `COUNCIL_KIMI_AUTH_TOKEN`(+ `_MODEL`, `ANTHROPIC_BASE_URL`)  | Claude Code |
| `council-codex-gpt` | `COUNCIL_CODEX_AUTH_TOKEN`, `COUNCIL_CODEX_MODEL`, `CODEX_HOME` | Codex CLI |

Then choose how the keys get in:
- **User pastes them (preferred for secrecy)** — tell them the absolute path of `council-def.sh` and
  which `<your-...-key-here>` placeholders to replace, then use the **pause/resume pattern**: they
  exit, edit the file, and return with `claude --continue`.
- **You edit it** — only if the user explicitly hands you the keys; fill the chosen backends'
  placeholders with file-edit tools, leaving unused backends untouched.

Track which backends end up actually configured — you need that exact set in step 5.

### 4b. (Only if the user chose the Codex backend in step 4 — otherwise SKIP this step)

A Codex councilor needs more than a key — `codex` reads its provider/auth from a `config.toml` under
`CODEX_HOME`. First confirm `codex` is installed (`command -v codex`; if not, `npm i -g @openai/codex`
— a good moment for the pause/resume pattern if the user installs it themselves). Then ask which case:

- **Official OpenAI subscription** — the user has already run `codex login`. Point `CODEX_HOME` at
  that config dir (default `~/.codex`); no extra file needed.
- **Relay / OpenAI-compatible proxy** — create an isolated CODEX_HOME (e.g. `~/.codex-relay`), set
  `CODEX_HOME` to it in `council-def.sh`, and write `<CODEX_HOME>/config.toml`:
  ```toml
  model = "gpt-5.5"
  model_provider = "proxy"
  [model_providers.proxy]
  base_url = "<relay base url, e.g. https://.../v1>"
  env_key  = "OPENAI_API_KEY"   # council-def.sh passes COUNCIL_CODEX_AUTH_TOKEN as OPENAI_API_KEY
  wire_api = "responses"
  ```
  Ask the user for the relay's base_url; the key goes in `COUNCIL_CODEX_AUTH_TOKEN` (step 4), not here.

### 5. Configure the round (config.json)

Edit `<INSTALL>/config.json`. Its `councilors` list must contain **only the backends the user
actually configured in step 4** — each name must be a function in `council-def.sh` AND have a working
key (and, for Codex, a working `CODEX_HOME`). **The template ships with `council-codex-gpt` in the
default list; remove it (and any other unconfigured backend) if the user didn't set it up** — an
unconfigured councilor just fails every round.

```json
{ "chief_model": "Opus", "councilors": ["council-cc-glm", "council-cc-kimi"] }
```

`chief_model` is the model chief uses to synthesize. You may edit this file for the user, or (to keep
it in their hands) tell them the absolute path and use the pause/resume pattern.

### 6. Verify (smoke check)

Confirm it actually works, not just that files are in place:
- `source <council-def path>` succeeds with no error;
- every councilor in `config.json` resolves to a defined function (e.g. `type council-cc-glm`);
- the matching CLI is on `PATH` for each enabled backend — `claude` for `council-cc-*`, `codex` for `council-codex-*`;
- (optional, costs a real API call — ask first) run one minimal round:
  ```shell
  printf 'Reply with exactly: COUNCIL_OK' > /tmp/council_probe.md
  bash "<INSTALL>/scripts/council.sh" /tmp/council_probe.md
  ```
  expect `RESULT <name> ok ...` for the enabled councilors.

### 7. Report + make the skill live

In the user's language, summarize: what was installed and where (absolute paths), which backends are
configured, which councilors are enabled, the verification result, and how to use it — the skill
auto-triggers at decision points, or they can say "consult the council" / send `/council`.

Then tell them the skill becomes discoverable only after Claude Code reloads. The cleanest way: **exit
and come back with `claude --continue`** (reloads skills while keeping this conversation's context).
If any earlier step already sent them away with `claude --continue`, the reload has already happened.

Also note: `chief_model` (e.g. `Opus`) assumes the **main session runs on an official Anthropic
account** — chief is a fork of the main session and inherits its backend; on a non-official backend
the model name is remapped or ignored accordingly.
