# Triage Pull Requests

You are classifying and summarizing an incoming GitHub pull request to help
the maintainer decide how to handle it. Inspired by Steve Yegge's Vibe
Maintainer approach.

## Trigger

This skill is triggered by: `/triage-pr <PR_NUMBER>` or `/triage-pr <PR_URL>`

## Instructions

### Step 1: Gather PR Data

Fetch all relevant information:

```bash
gh pr view <PR_NUMBER> --json title,body,author,labels,reviews,comments,additions,deletions,changedFiles,headRefName,baseRefName,mergeable,statusCheckRollup
```

```bash
gh pr diff <PR_NUMBER>
```

```bash
gh pr checks <PR_NUMBER>
```

### Step 2: Classify the PR

Assign one of the following classifications:

- **MERGEABLE**: Clean diff, tests pass, follows conventions, no open questions.
  Maintainer can review quickly and merge.
- **NEEDS-WORK**: Has issues that the author should fix. Be specific about what.
- **NEEDS-DISCUSSION**: Architectural questions, design trade-offs, or scope
  concerns that require a conversation before proceeding.
- **STALE**: No activity for >30 days, CI may be outdated.
- **WIP**: Explicitly marked as draft or work-in-progress.

### Step 3: Check for Common Issues

For Go/OpenShift projects, check:

1. **Missing tests**: New functionality without corresponding test coverage
2. **API changes**: Changes to public API without documentation updates
3. **Breaking changes**: Modifications to existing behavior without migration path
4. **Generated code**: Are generated files updated? (look for `zz_generated*`,
   `*_generated.go`, vendor changes)
5. **License headers**: New files should have appropriate license headers
6. **Commit hygiene**: Squashable fixup commits, meaningful commit messages,
   signed commits
7. **Size**: PRs over 500 lines changed should probably be split
8. **Dependencies**: New dependencies added without justification

### Step 4: Summarize

Present your classification as:

```
## PR Triage: #<NUMBER> - <TITLE>

**Classification**: <MERGEABLE | NEEDS-WORK | NEEDS-DISCUSSION | STALE | WIP>
**Author**: <author> | **Size**: +<additions>/-<deletions> across <files> files
**CI Status**: <passing | failing | pending>

### What This PR Does
<2-3 sentence summary of the change and its purpose>

### Review Checklist
- [ ] Tests added/updated: <yes/no/partial>
- [ ] API docs updated: <yes/no/n-a>
- [ ] Generated code current: <yes/no/n-a>
- [ ] License headers present: <yes/no>
- [ ] Commits signed: <yes/no>

### Issues Found
<bulleted list of specific issues, or "None" if clean>

### Recommendation
<specific action for the maintainer: merge, request changes, or start a discussion>
```

## Notes

- Be direct and specific. "Needs work" without saying what work is not useful.
- If the PR is from a first-time contributor, note that and be more detailed
  in your feedback suggestions (the maintainer may want to be more hands-on).
- If the PR has been open for a long time with unresolved review comments,
  summarize the outstanding items.
- For MERGEABLE PRs, note if there are minor nits the maintainer could fix
  post-merge to avoid another round-trip with the contributor.
