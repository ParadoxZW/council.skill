# council-def.sh — backend call-definition library for council reviewers (template)
#
# Single responsibility: define ONLY how each reviewer backend is invoked —
# base_url / auth / model / launch command. No prompts or behavioral rules here.
#
# This is a LIBRARY file meant to be `source`d, not an executable command:
#   · council.sh sources it at runtime, so each function can be called via the "$name"
#     variable (an alias can't do that);
#   · you can also `source` it from ~/.zshenv to use the functions directly in your shell.
#
# Usage: copy to ~/.local/bin/council-def.sh and replace each <...> placeholder with your
# real key (this file is a template).

# ── Settings ──────────────────────
COUNCIL_GLM_MODEL="glm-5.2[1m]"
COUNCIL_GLM_AUTH_TOKEN="<your-glm-api-key-here>"
COUNCIL_DS_MODEL="deepseek-v4-pro[1m]"
COUNCIL_DS_AUTH_TOKEN="<your-deepseek-api-key-here>"
COUNCIL_KIMI_MODEL="k2.7[1m]"
COUNCIL_KIMI_AUTH_TOKEN="<your-kimi-api-key-here>"
COUNCIL_CODEX_MODEL="gpt-5.5"
COUNCIL_CODEX_AUTH_TOKEN="<your-openai-api-key-here>"
# CODEX_HOME="$HOME/.codex-api"  # an isolated codex config — handy for a relay/proxy setup kept separate from your subscription account
CODEX_HOME="$HOME/.codex"

# ── Claude Code backends (council-cc-*) ──
council-cc-glm() {
  env \
    ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic" \
    ANTHROPIC_AUTH_TOKEN="$COUNCIL_GLM_AUTH_TOKEN" \
    ANTHROPIC_MODEL="$COUNCIL_GLM_MODEL" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$COUNCIL_GLM_MODEL" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$COUNCIL_GLM_MODEL" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$COUNCIL_GLM_MODEL" \
    CLAUDE_CODE_SUBAGENT_MODEL="$COUNCIL_GLM_MODEL" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude --effort max "$@"
}

council-cc-ds() {
  env \
    ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic" \
    ANTHROPIC_AUTH_TOKEN="$COUNCIL_DS_AUTH_TOKEN" \
    ANTHROPIC_MODEL="$COUNCIL_DS_MODEL" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$COUNCIL_DS_MODEL" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$COUNCIL_DS_MODEL" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$COUNCIL_DS_MODEL" \
    CLAUDE_CODE_SUBAGENT_MODEL="$COUNCIL_DS_MODEL" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude --effort max "$@"
}

council-cc-kimi() {
  env \
    ANTHROPIC_BASE_URL="https://api.kimi.com/coding/" \
    ANTHROPIC_AUTH_TOKEN="$COUNCIL_KIMI_AUTH_TOKEN" \
    ANTHROPIC_MODEL="$COUNCIL_KIMI_MODEL" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$COUNCIL_KIMI_MODEL" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$COUNCIL_KIMI_MODEL" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$COUNCIL_KIMI_MODEL" \
    CLAUDE_CODE_SUBAGENT_MODEL="$COUNCIL_KIMI_MODEL" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude --effort max "$@"
}

# ── Codex backend ──
council-codex-gpt() {
  env \
    OPENAI_API_KEY="$COUNCIL_CODEX_AUTH_TOKEN" \
    CODEX_HOME="$CODEX_HOME" \
    codex exec --model "$COUNCIL_CODEX_MODEL" --sandbox read-only -
}
