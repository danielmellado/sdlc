# Triage CI Failures

You are analyzing CI test failures for a GitHub pull request. Your goal is to
identify the root cause of the failure and suggest a fix.

## Trigger

This skill is triggered by: `/triage-ci <PR_NUMBER>` or `/triage-ci <PR_URL>`

## Instructions

### Step 1: Download Artifacts

Run the following command to download CI artifacts for the failed PR:

```bash
npx gh-ci-artifacts <PR_NUMBER>
```

This creates a directory structure under `./ci-artifacts/` with:
- `catalog.json` - index of all downloaded artifacts
- `raw/` - original downloaded artifacts
- `converted/` - normalized artifacts (HTML/NDJSON/TXT converted to JSON)
- `logs/` - extracted job logs

If the command is not available, fall back to:

```bash
gh run list --commit $(gh pr view <PR_NUMBER> --json headRefOid -q .headRefOid) --json databaseId,status,conclusion,name -q '.[] | select(.conclusion == "failure")'
```

Then for each failed run:

```bash
gh run view <RUN_ID> --log-failed
```

### Step 2: Identify Failed Tests

Look through the artifacts and logs for test failures. Common patterns in
OpenShift/Go projects:

- **Go test output**: Lines starting with `--- FAIL:` or `FAIL` followed by package path
- **Ginkgo output**: `[FAIL]` markers with `Failure` blocks containing stack traces
- **JUnit XML**: `<testcase>` elements with `<failure>` children
- **Prow artifacts**: Look in `artifacts/` for `junit*.xml` files

### Step 3: Correlate with Changes

1. Get the PR diff: `gh pr diff <PR_NUMBER>`
2. Map failed tests to changed files
3. Check if failures are in code paths touched by the PR
4. Look for test infrastructure failures vs actual code bugs

### Step 4: Analyze Root Cause

For each failure, determine:

1. **Category**: Is this a flaky test, a real regression, an infrastructure issue,
   or a merge conflict?
2. **Root cause**: What specific code change or condition caused the failure?
3. **Timeline**: Correlate timestamps across log files to reconstruct the
   sequence of events

Pay special attention to:
- Pod/container crash logs in the 10 minutes before the test failure
- Resource exhaustion (OOM kills, disk full, timeout)
- Network connectivity issues between components
- Race conditions (look for timing-dependent failures)

### Step 5: Report

Present your findings as:

```
## CI Failure Analysis: PR #<NUMBER>

### Summary
<one-line description of what failed and why>

### Failed Tests
| Test | Package | Category | Likely Cause |
|------|---------|----------|-------------|
| ... | ... | ... | ... |

### Root Cause Analysis
<detailed explanation with evidence from logs>

### Suggested Fix
<specific code changes or actions to resolve>

### Flakiness Assessment
<is this a known flaky test? evidence for/against>
```

## Notes

- When the suggested root cause is uncertain, say so explicitly and provide
  alternative hypotheses ranked by likelihood.
- If the failure looks like a known flaky test, check if there are recent
  issues or PRs mentioning the same test name.
- Always include the relevant log snippets as evidence for your analysis.
