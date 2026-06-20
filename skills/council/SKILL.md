---
name: council
description: >-
  You have access to a `council` tool backed by a stronger reviewer team. The tool is defined in the main body of this skill (the council skill). So invoke this skill when you need it, 

  Call council tool BEFORE substantive work -- before writing, before committing to an interpretation, before building on an assumption. If the task requires orientation first (finding files, fetching a source, seeing what's there), do that, then call council. Orientation is not substantive work. Writing, editing, and declaring an answer are.

  Also call council:
  - When you believe the task is complete. BEFORE this call, make your deliverable durable: write the file, save the result, commit the change. The council call takes time; if the session ends during it, a durable result persists and an unwritten one doesn't.
  - When stuck -- errors recurring, approach not converging, results that don't fit.
  - When considering a change of approach.

  On tasks longer than a few steps, call council at least once before committing to an approach and once before declaring done. On short reactive tasks where the next action is dictated by tool output you just read, you don't need to keep calling -- the council adds most of its value on the first call, before the approach crystallizes.
---

# Council · External-model consultation

The `council` tool takes NO parameters -- when you call council, your entire conversation history is automatically forwarded. They see the task, every tool call you've made, every result you've seen. You just launch it and wait for what comes back.

## How to consult

When you need advice, call the council tool. Run the following command **with no other arguments**:

```shell
bash "${CLAUDE_SKILL_DIR}/scripts/launch.sh"
```

The command's stdout contains the council's advise. Follow this advise and take the next step.

If you retrieved data pointing one way and the council points another: don't silently switch. Surface the conflict in one more council call -- "I found X, you suggest Y, which constraint breaks the tie?" The council saw your evidence but may have underweighted it; a reconcile call is cheaper than committing to the wrong branch.