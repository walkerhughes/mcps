# Verify a job upload on the Harbor hub

An MCP server named `harbor-hub` is available to you. It exposes tools for the
Harbor hub, including `whoami`, `check_job_upload`, `get_job_overview`, and
`get_job_trials`.

The job id to check is provided in the `EVAL_JOB_ID` environment variable
(read it with `echo $EVAL_JOB_ID`).

Your task:

1. Use the `harbor-hub` MCP tools (not the raw hub API) to determine whether
   the job with id `$EVAL_JOB_ID` has been uploaded to the Harbor hub.
2. If it is uploaded, find how many trials the job contains.
3. Write your answer to `/app/answer.txt`:
   - If the job is uploaded, write exactly one line: `yes <trial_count>`
     where `<trial_count>` is the number of trials as a plain integer,
     for example `yes 12`.
   - If the job is not uploaded, write exactly one line: `no`.

The file must contain only that single line and nothing else: no extra text,
no punctuation, no code fences.
