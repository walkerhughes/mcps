# Check whether a task package is published on the Harbor hub

An MCP server named `harbor-hub` is available to you. It exposes tools for the
Harbor hub, including `whoami`, `check_task_published`, and `resolve_dataset`.

The task reference to check is provided in the `EVAL_TASK_REF` environment
variable (read it with `echo $EVAL_TASK_REF`). It has the form
`org/name@ref`, for example `harbor/hello-world@1.0.0`.

Your task:

1. Use the `harbor-hub` MCP tools (not the raw hub API) to determine whether
   the task package `$EVAL_TASK_REF` exists on the Harbor hub.
2. If it exists, find its content hash (a 64-character lowercase hexadecimal
   SHA-256 digest).
3. Write your answer to `/app/answer.txt`:
   - If the package exists, write exactly one line: `yes <content_hash>`
     where `<content_hash>` is the 64-character lowercase hex hash,
     for example `yes 3f2c...a1b0` (with the full 64 characters).
   - If the package does not exist, write exactly one line: `no`.

The file must contain only that single line and nothing else: no extra text,
no punctuation, no code fences.
