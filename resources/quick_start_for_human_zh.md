# Council 快速上手 · 人类版

← 返回 [README_zh](../README_zh.md)

面向想手动安装的用户。四步:获取 → 安装 skill → 配置后端库 → 选 council 名单。
(懒得手动?让 Claude Code 帮你装即可,见 README 的「安装与配置」。)

## 0. 前置

- 已安装 [Claude Code](https://docs.claude.com/en/docs/claude-code);
- 至少一个 councilor 后端的 API key(GLM / DeepSeek / Kimi / OpenAI 兼容中转站等,见第 3 步——只需配置你实际要用的);
- 若要用 **Codex 后端**的 councilor,需另装 Codex CLI:`npm i -g @openai/codex`。

## 1. 获取项目

```shell
git clone https://github.com/ParadoxZW/council.skill
cd council.skill
```

## 2. 安装 skill

把 skill 本体放到 Claude Code 能发现的位置,二选一:

- **用户级**(所有项目可用):
  ```shell
  cp -r skills/council ~/.claude/skills/council
  ```
- **项目级**(仅当前项目):
  ```shell
  cp -r skills/council /你的项目/.claude/skills/council
  ```

## 3. 配置 councilor 后端库(council-def.sh)

每个 councilor 的「后端如何调用」集中在一个库文件里。复制模板到默认位置:

```shell
cp council-def.example.sh ~/.local/bin/council-def.sh
```

> [!note] 想放别的路径?
> 默认位置是 `~/.local/bin/council-def.sh`。若放到其它路径,需把 skill 里 `skills/council/scripts/council.sh` 顶部这行的默认值改成你的路径(或运行时设环境变量 `COUNCILOR_LIB=<你的路径>`):
> ```shell
> COUNCILOR_LIB="${COUNCILOR_LIB:-$HOME/.local/bin/council-def.sh}"
> ```

编辑 `~/.local/bin/council-def.sh`,把要用的后端的 `<your-...-key-here>` 换成真实 key。内置四个后端示例:

| 函数 | 后端 | harness |
|---|---|---|
| `council-cc-glm` | GLM(智谱,Anthropic 兼容端点) | Claude Code |
| `council-cc-ds` | DeepSeek | Claude Code |
| `council-cc-kimi` | Kimi(Moonshot) | Claude Code |
| `council-codex-gpt` | gpt-5.5(经中转站) | **Codex CLI** |

- **Claude Code 后端**(`council-cc-*`):按需改函数里的 `ANTHROPIC_BASE_URL` / `COUNCIL_*_AUTH_TOKEN` / `COUNCIL_*_MODEL`;支持任意 Anthropic 兼容端点。
- **Codex 后端**(`council-codex-gpt`):key 填 `COUNCIL_CODEX_AUTH_TOKEN`,模型填 `COUNCIL_CODEX_MODEL`。光填 key 还不够——`codex` 的 provider/鉴权来自 `CODEX_HOME` 下的 `config.toml`(见下)。先确认已装 `codex`(`npm i -g @openai/codex`)。
- 没用到的后端原样留着即可,不影响。

> [!note] 用 Codex 后端时还要配 `CODEX_HOME`
> - **官方 OpenAI 订阅**:已 `codex login` 的话,把 `council-def.sh` 里的 `CODEX_HOME` 指向那个配置目录(默认 `~/.codex`)即可,无需额外文件。
> - **中转站 / OpenAI 兼容代理**:建一个隔离的 `CODEX_HOME`(如 `~/.codex-relay`),让 `council-def.sh` 的 `CODEX_HOME` 指向它,并在 `<CODEX_HOME>/config.toml` 写:
>   ```toml
>   model = "gpt-5.5"
>   model_provider = "proxy"
>   [model_providers.proxy]
>   base_url = "<中转站 base url,如 https://.../v1>"
>   env_key  = "OPENAI_API_KEY"   # council-def.sh 会把 COUNCIL_CODEX_AUTH_TOKEN 作为 OPENAI_API_KEY 传入
>   wire_api = "responses"
>   ```

## 4. 选择本轮 council 名单(config.json)

编辑**已安装**的 skill 里的 `config.json`(用户级即 `~/.claude/skills/council/config.json`):

```json
{
  "chief_model": "Opus",
  "councilors": ["council-cc-glm", "council-codex-gpt", "council-cc-kimi"]
}
```

- `councilors`:本轮启用的 councilor 函数名(须在 `council-def.sh` 里有定义);**挑与主线 agent 不同源的模型,视角更互补**。
- `chief_model`:chief 综合各家意见时用的模型。

## 5. 开始使用

重载 Claude Code 后即生效。skill 会在关键决策点(开工定方案前、产出完成前、卡住或改方向时)自动触发;你也可显式让 agent "consult the council",或发送 `/council`。

---

**依赖速查**:Claude Code 后端的 councilor 需要 `claude` CLI(随 Claude Code 自带);Codex 后端的 councilor 需要 `codex` CLI。
